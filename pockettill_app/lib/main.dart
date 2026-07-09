import 'dart:async';

import 'package:flutter/material.dart';
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
import 'core/sync/sync_service.dart';

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

  await HardwareDetector.init();
  await IsarService.init();
  await SupabaseService.init();

  final isSunmi = HardwareDetector.isSunmiDevice();

  final container = ProviderContainer(
    overrides: [
      scannerServiceProvider.overrideWithValue(
        isSunmi ? SunmiScannerService() : CameraScannerService(),
      ),
      printerServiceProvider.overrideWithValue(
        isSunmi ? SunmiPrinterService() : NoopPrinterService(),
      ),
    ],
  );

  final syncService = container.read(syncServiceProvider);

  final reachabilityService = ReachabilityService(
    supabaseUrl: SupabaseService.url,
    supabaseAnonKey: SupabaseService.anonKey,
  );
  await reachabilityService.init();
  reachabilityService.isReachable.listen((reachable) {
    if (reachable) {
      unawaited(syncService.sync());
    }
    // When unreachable, do nothing - the next confirmed-reachable ping
    // triggers the next sync attempt.
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PocketTillApp(),
    ),
  );
}
