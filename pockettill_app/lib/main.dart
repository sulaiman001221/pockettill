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

  reachabilityService.isReachable.listen((reachable) {
    if (reachable) {
      // Push this device's own pending changes first, then open the
      // Realtime channel (which itself starts with a catch-up pull of
      // whatever other devices recorded while this one was offline) -
      // pushing first means other devices' next catch-up already sees this
      // device's latest, even though the ordering doesn't affect this
      // device's own correctness (catch-up always excludes its own
      // device_id regardless of push timing).
      unawaited(
        syncService.sync().then((_) => realtimeStockSync.start()),
      );
    } else {
      // A dead channel doesn't deliver anything useful anyway - closing it
      // here means the next reconnect always starts from a clean
      // catch-up-then-subscribe, not a stale channel silently doing nothing.
      unawaited(realtimeStockSync.stop());
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PocketTillApp(),
    ),
  );
}
