import 'dart:async';

import 'package:sunmi_scanner/sunmi_scanner.dart';

import 'scanner_service.dart';

/// [ScannerService] backed by Sunmi's integrated hardware barcode scanner.
class SunmiScannerService implements ScannerService {
  StreamSubscription<String>? _subscription;
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onBarcodeScanned => _controller.stream;

  @override
  Future<void> init() async {
    await SunmiScanner.bindService(showToast: false);
    _subscription = SunmiScanner.onBarcodeScanned().listen((barcode) {
      _controller.add(barcode);
    });
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await SunmiScanner.unbindService();
    await _controller.close();
  }
}
