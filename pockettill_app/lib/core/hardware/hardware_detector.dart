import 'package:device_info_plus/device_info_plus.dart';

/// Detects whether the app is running on Sunmi POS hardware.
///
/// Must be initialized once at app start via [init]; the result is cached
/// so repeated calls to [isSunmiDevice] never re-query the platform.
class HardwareDetector {
  HardwareDetector._();

  static bool _isSunmi = false;
  static bool _initialized = false;

  /// Queries device info and caches whether this device is a Sunmi terminal.
  static Future<void> init() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    _isSunmi = androidInfo.manufacturer.toUpperCase() == 'SUNMI';
    _initialized = true;
  }

  /// Returns the cached Sunmi detection result.
  ///
  /// [init] must be called before this is used.
  static bool isSunmiDevice() {
    assert(_initialized, 'HardwareDetector.init() must be called first.');
    return _isSunmi;
  }
}
