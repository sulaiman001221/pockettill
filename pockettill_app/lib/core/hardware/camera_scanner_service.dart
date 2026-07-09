import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_service.dart';

/// [ScannerService] backed by the device camera, for Android phones that
/// have no integrated hardware scanner.
class CameraScannerService implements ScannerService {
  final MobileScannerController _controller = MobileScannerController();
  StreamSubscription<BarcodeCapture>? _subscription;
  final StreamController<String> _barcodeController =
      StreamController<String>.broadcast();

  /// The controller driving the camera preview, exposed so a feature screen
  /// can attach a [MobileScanner] widget to it.
  MobileScannerController get controller => _controller;

  @override
  Stream<String> get onBarcodeScanned => _barcodeController.stream;

  @override
  Future<void> init() async {
    _subscription = _controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value != null) {
          _barcodeController.add(value);
        }
      }
    });
    await _controller.start();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.dispose();
    await _barcodeController.close();
  }
}
