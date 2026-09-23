import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// What, if anything, the Sales screen's update banner should show right
/// now.
enum AppUpdateBannerState {
  /// No update in progress - either none is available, the check hasn't run
  /// yet, or it failed (offline, not installed via Play, etc).
  none,

  /// A newer version is downloading in the background - nothing to show the
  /// owner yet, there's no action for them to take until it's ready.
  downloading,

  /// Downloaded and waiting for the owner to restart the app to finish
  /// installing it - this is the one state the banner actually surfaces.
  readyToInstall,
}

/// Wraps Google Play's In App Updates API so a newer version already live on
/// the Store gets surfaced *inside* PocketTill instead of depending on the
/// owner noticing Play Store's own update badge - added 2026-09-23 after a
/// real store updated via Play Store with no idea a fix had shipped, since
/// nothing in the app itself had ever pointed at it.
///
/// Always a flexible update (downloads in the background, installs on the
/// owner's own schedule via [completeUpdate]) - never the blocking
/// full-screen immediate flow, so a mid-sale checkout is never interrupted.
/// Every call here is best-effort: this API only actually works on a build
/// installed through Google Play (the package's own docs: "cannot be tested
/// locally"), so on a sideloaded debug/test-build APK every call below just
/// fails quietly and the banner never appears - expected, not a bug.
class AppUpdateService {
  final StreamController<AppUpdateBannerState> _controller =
      StreamController<AppUpdateBannerState>.broadcast();

  Stream<AppUpdateBannerState> get bannerState => _controller.stream;

  /// Checks Play Store once (call on app start) and, if a newer version is
  /// available and a flexible update is allowed, starts downloading it in
  /// the background. Never throws.
  Future<void> checkAndStart() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (!info.flexibleUpdateAllowed) return;

      _controller.add(AppUpdateBannerState.downloading);
      await InAppUpdate.startFlexibleUpdate();
      _controller.add(AppUpdateBannerState.readyToInstall);
    } catch (e) {
      debugPrint('AppUpdateService.checkAndStart() failed: $e');
    }
  }

  /// Finishes the download and restarts the app into the new version - Play
  /// Core drives this with its own native prompt. Call from the banner's
  /// action button once [bannerState] has emitted [AppUpdateBannerState.
  /// readyToInstall].
  Future<void> completeUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('AppUpdateService.completeUpdate() failed: $e');
    }
  }

  void dispose() {
    _controller.close();
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final service = AppUpdateService();
  ref.onDispose(service.dispose);
  return service;
});

/// Watched by the Sales screen to show/hide the "Update ready" banner.
final appUpdateBannerProvider = StreamProvider<AppUpdateBannerState>((ref) {
  return ref.watch(appUpdateServiceProvider).bannerState;
});
