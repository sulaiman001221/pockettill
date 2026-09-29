import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// Where the background update download is at. Nothing in the app surfaces
/// this to the owner any more (see the class doc comment) - it exists purely
/// so [readyToInstall]'s auto-install trigger has something to watch for.
enum AppUpdateBannerState {
  /// No update in progress - either none is available, the check hasn't run
  /// yet, or it failed (offline, not installed via Play, etc).
  none,

  /// A newer version is downloading in the background - nothing to do yet.
  downloading,

  /// Downloaded and ready to install - [main] auto-installs it itself the
  /// next moment the cart is empty, with no prompt.
  readyToInstall,
}

/// Wraps Google Play's In App Updates API so a newer version already live on
/// the Store gets applied automatically instead of depending on the owner
/// noticing Play Store's own update badge - added 2026-09-23 after a real
/// store updated via Play Store with no idea a fix had shipped.
///
/// Always a flexible update (downloads in the background) so the download
/// itself is never disruptive. Installing it, though, restarts the whole app
/// process outright - Play Core has no "finish on next launch" option for a
/// flexible update, so there's no way to apply it without a restart at some
/// point. Two rounds of owner feedback (2026-09-24, 2026-09-29) settled on:
/// no prompt of any kind, either Play's own or one of ours - [main] just
/// restarts and installs it itself, the next moment the cart is empty, so it
/// never interrupts a sale but never asks for permission either.
///
/// Every call here is best-effort: this API only actually works on a build
/// installed through Google Play (the package's own docs: "cannot be tested
/// locally"), so on a sideloaded debug/test-build APK every call below just
/// fails quietly - expected, not a bug.
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

  /// Finishes the download and restarts the app into the new version,
  /// immediately and with no confirmation of any kind - see the class doc
  /// comment for why. Called by [main] once [bannerState] has emitted
  /// [AppUpdateBannerState.readyToInstall] and the cart is empty.
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
