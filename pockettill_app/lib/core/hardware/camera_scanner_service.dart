import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_service.dart';

/// [ScannerService] backed by the device camera, for Android phones that
/// have no integrated hardware scanner.
class CameraScannerService implements ScannerService {
  final MobileScannerController _controller = MobileScannerController(
    // Every barcode this app ever needs to read is a retail product code -
    // restricting ML Kit to just these formats (the default scans every
    // supported symbology, including ones like PDF417/Aztec/DataMatrix that
    // never appear on a grocery item) cuts the per-frame decode work, which
    // is most of what "barcode scanner feels slow" comes down to. Asked
    // 2026-09-28.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    // The default (.normal) waits out a fixed 250ms cooldown before
    // accepting *any* detection, purely so it can compare it against the
    // previous one for de-duplication - this app already has its own
    // settle/de-dupe logic (_handled, the 600ms just-opened grace period in
    // barcode_scanner_screen.dart), so that cooldown is pure added latency
    // on the very first, successful scan. .noDuplicates still skips repeats
    // of the same code but doesn't hold back a genuinely new one.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
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
    // Don't start() here: the controller isn't attached to a MobileScanner
    // widget yet (that only happens once one is actually built), and
    // starting an unattached controller throws MobileScannerException
    // (controllerNotAttached). The MobileScanner widget starts/stops the
    // controller itself via its own autoStart lifecycle once it's built.
    _subscription = _controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value != null) {
          _barcodeController.add(value);
        }
      }
    });
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.dispose();
    await _barcodeController.close();
  }
}
