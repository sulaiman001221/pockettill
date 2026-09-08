import 'package:device_info_plus/device_info_plus.dart';

/// Detects whether the app is running on Sunmi POS hardware.
///
/// Must be initialized once at app start via [init]; the result is cached
/// so repeated calls to [isSunmiDevice] never re-query the platform.
class HardwareDetector {
  HardwareDetector._();

  static bool _isSunmi = false;
  static String _deviceName = 'Android Device';
  static bool _initialized = false;

  /// Queries device info and caches whether this device is a Sunmi terminal.
  static Future<void> init() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    _isSunmi = androidInfo.manufacturer.toUpperCase() == 'SUNMI';
    // Best available human-readable label without a paid device-name lookup
    // service - "model" alone is often a bare model number (e.g.
    // "SM-A225F"), so pairing it with the manufacturer at least says which
    // brand it is. Used for Settings > Active Devices.
    _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
    _initialized = true;
  }

  /// Returns the cached Sunmi detection result.
  ///
  /// [init] must be called before this is used.
  static bool isSunmiDevice() {
    assert(_initialized, 'HardwareDetector.init() must be called first.');
    return _isSunmi;
  }

  /// A best-effort human-readable device label ("samsung SM-A225F") for
  /// Settings > Active Devices - [init] must be called before this is used.
  static String deviceName() {
    assert(_initialized, 'HardwareDetector.init() must be called first.');
    return _deviceName;
  }
}
