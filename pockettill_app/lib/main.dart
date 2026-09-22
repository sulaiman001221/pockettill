import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/hardware/camera_scanner_service.dart';
import 'core/hardware/hardware_detector.dart';
import 'core/hardware/noop_printer_service.dart';
import 'core/hardware/printer_service.dart';
import 'core/hardware/scanner_service.dart';
import 'core/hardware/sunmi_printer_service.dart';
import 'core/hardware/sunmi_scanner_service.dart';
import 'core/supabase/supabase_service.dart';
import 'core/sync/reachability_service.dart';
import 'core/sync/realtime_data_sync_service.dart';
import 'core/sync/sync_service.dart';
import 'shared/models/sync_event.dart';
import 'shared/theme/system_ui.dart';

/// The [ScannerService] appropriate for this device, chosen once at app
/// start based on [HardwareDetector] and injected via [ProviderScope]
/// overrides in [main].
final scannerServiceProvider = Provider<ScannerService>((ref) {
  throw UnimplementedError('scannerServiceProvider must be overridden.');
});

/// The [PrinterService] appropriate for this device, chosen once at app
/// start based on [HardwareDetector] and injected via [ProviderScope]
/// overrides in [main].
final printerServiceProvider = Provider<PrinterService>((ref) {
  throw UnimplementedError('printerServiceProvider must be overridden.');
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every screen except SplashScreen (which overrides this itself for its
  // blue background - see its own init/dispose) sits on CustomAppBar's white
  // top bar - matching the status bar to it makes the two blend into one
  // continuous area instead of Android's default (dark) status bar cutting
  // across the top of the screen.
  SystemChrome.setSystemUIOverlayStyle(lightScreenStatusBar);

  await HardwareDetector.init();
  await IsarService.init();
  await SupabaseService.init();

  final isSunmi = HardwareDetector.isSunmiDevice();

  // Constructed before the container so its ready instance can be injected
  // via an override below, the same way as the hardware services.
  final reachabilityService = ReachabilityService(
    supabaseUrl: SupabaseService.url,
    supabaseAnonKey: SupabaseService.anonKey,
  );
  await reachabilityService.init();

  final container = ProviderContainer(
    overrides: [
      scannerServiceProvider.overrideWithValue(
        isSunmi ? SunmiScannerService() : CameraScannerService(),
      ),
      printerServiceProvider.overrideWithValue(
        isSunmi ? SunmiPrinterService() : NoopPrinterService(),
      ),
      reachabilityServiceProvider.overrideWithValue(reachabilityService),
    ],
  );

  final syncService = container.read(syncServiceProvider);
  final realtimeDataSync = container.read(realtimeDataSyncServiceProvider);

  Future<void> syncAndGoLive() async {
    // Push this device's own pending changes first, then open the realtime
    // channels, which pull everything other devices recorded meanwhile.
    // Pushing first means the pull that follows already reflects this
    // device's own latest changes.
    await syncService.sync();
    await realtimeDataSync.start();
    await realtimeDataSync.pullNow();
  }

  Future<void> goOffline() async {
    // A dead channel doesn't deliver anything useful anyway - closing it
    // here means the next reconnect always starts from a clean
    // subscribe-then-pull, not a stale channel silently doing nothing.
    await realtimeDataSync.stop();
  }

  reachabilityService.isReachable.listen((reachable) {
    if (reachable) {
      unawaited(syncAndGoLive());
    } else {
      unawaited(goOffline());
    }
  });

  // `isReachable` is a plain broadcast stream - it only replays to whoever
  // is *already* listening the moment reachability first resolves, it
  // doesn't remember and replay that value to a listener attaching a
  // moment later. `ReachabilityService.init()` above already kicks off its
  // own first health-check ping (fire-and-forget, before this point), so
  // there's a real race: if that ping resolves before the `.listen()` call
  // above finishes attaching, this app never gets its first
  // syncAndGoLive() call at all - stuck with no Realtime channels ever
  // started until some *later* genuine connectivity change happens to
  // occur. Found 2026-09-13 explaining "product updates don't sync until
  // the app's storage is cleared" - a fresh process restart just gave the
  // race another, differently-timed chance to go the other way, which
  // read as "clearing fixed it" without anything about the fix being
  // about cache at all. Calling this once, unconditionally, closes the
  // gap regardless of which way that race goes - sync()/start() are both
  // safe no-ops if genuinely offline (the next real reachable event
  // retries them), and start() itself no-ops if channels are already up.
  unawaited(syncAndGoLive());

  // Realtime channels only ever got (re)started above, on a network
  // reachability *change* - a phone that's simply backgrounded and later
  // resumed (screen locked, home button, switching to another app) never
  // fires that listener at all, even though Android routinely lets a
  // background app's sockets go stale or gets suspended outright. Found
  // 2026-09-09 testing with two real devices: neither ever saw the other's
  // activity, because whichever device wasn't actively in the foreground
  // had a dead Realtime connection with nothing to notice and revive it.
  // Forcing a full stop-then-restart on every resume - not just "resume if
  // not already running" - guarantees a fresh, healthy channel plus a
  // proper catch-up pull for anything missed while backgrounded, rather
  // than trusting a connection that's been sitting unused.
  WidgetsBinding.instance.addObserver(
    _RealtimeLifecycleReactor(onResumed: () async {
      await goOffline();
      await syncAndGoLive();
    }),
  );

  // Every trigger above is edge-based (a reachability *change*, an app
  // *resume*) - a device that's simply been sitting online and in the
  // foreground the whole time never hits any of them again after the first
  // one. This timer is also the safety net for realtime: a dropped socket or
  // a missed message costs at most one tick, because every tick both pushes
  // what this device has and pulls what it missed. sync() and pullNow() are
  // both safe no-ops if one's already running or there's nothing to do.
  Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(() async {
      await syncService.sync();
      await realtimeDataSync.pullNow();
    }());
  });

  // Don't make a change wait for the next tick: as soon as something new is
  // queued, push it (and pull what came back) a moment later. Marking events
  // as pushed also touches this collection, hence the pending check - it
  // stops that from triggering another round.
  Timer? syncSoon;
  IsarService.db.syncEvents.watchLazy().listen((_) {
    syncSoon?.cancel();
    syncSoon = Timer(const Duration(milliseconds: 1500), () {
      unawaited(() async {
        final pending = await IsarService.db.syncEvents
            .filter()
            .pushedEqualTo(false)
            .count();
        if (pending == 0) return;
        await syncService.sync();
        await realtimeDataSync.pullNow();
      }());
    });
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PocketTillApp(),
    ),
  );
}

/// Registered once for the app's lifetime (never removed - there's no
/// natural "dispose" point at this level, and the process dying takes it
/// with it) - see the comment where it's constructed in [main] for why
/// this exists.
class _RealtimeLifecycleReactor extends WidgetsBindingObserver {
  _RealtimeLifecycleReactor({required this.onResumed});

  final Future<void> Function() onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResumed());
    }
  }
}
