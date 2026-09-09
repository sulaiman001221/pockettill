import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'core/sync/realtime_stock_sync_service.dart';
import 'core/sync/sync_service.dart';
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
  final realtimeStockSync = container.read(realtimeStockSyncServiceProvider);
  final realtimeDataSync = container.read(realtimeDataSyncServiceProvider);

  Future<void> syncAndGoLive() async {
    // Push this device's own pending changes first, then open the Realtime
    // channels (each starts with its own catch-up pull of whatever other
    // devices recorded while this one was offline/backgrounded) - pushing
    // first means other devices' next catch-up already sees this device's
    // latest, even though the ordering doesn't affect this device's own
    // correctness (catch-up always excludes its own device_id/uuids
    // regardless of push timing).
    await syncService.sync();
    await Future.wait([realtimeStockSync.start(), realtimeDataSync.start()]);
  }

  Future<void> goOffline() async {
    // A dead channel doesn't deliver anything useful anyway - closing it
    // here means the next reconnect always starts from a clean
    // catch-up-then-subscribe, not a stale channel silently doing nothing.
    await Future.wait([realtimeStockSync.stop(), realtimeDataSync.stop()]);
  }

  reachabilityService.isReachable.listen((reachable) {
    if (reachable) {
      unawaited(syncAndGoLive());
    } else {
      unawaited(goOffline());
    }
  });

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
