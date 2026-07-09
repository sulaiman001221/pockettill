/// Abstraction over barcode scanning hardware.
///
/// Implementations exist for Sunmi's integrated hardware scanner
/// ([SunmiScannerService]) and for camera-based scanning on regular
/// Android phones ([CameraScannerService]).
abstract class ScannerService {
  /// Emits a barcode value each time one is scanned.
  Stream<String> get onBarcodeScanned;

  /// Prepares the underlying scanner hardware/service for use.
  Future<void> init();

  /// Releases any resources held by the scanner.
  Future<void> dispose();
}
