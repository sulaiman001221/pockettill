import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../shared/models/store_config.dart';
import '../database/isar_service.dart';
import 'hardware_detector.dart';

/// Plays short sound + haptic feedback for two events: a payment being
/// confirmed (all devices) and a barcode being scanned successfully (phone
/// cameras only - Sunmi's hardware scanner already beeps on its own, so
/// adding our own here would double up). Both are gated by their own
/// Settings > Sound toggle (on by default), read fresh from [StoreConfig]
/// on every call rather than cached, since Settings can change it at any
/// time during the session.
///
/// Fire-and-forget and never throws - a silenced device, a missing audio
/// backend, or any other playback failure is swallowed so it can never
/// crash or block the screen it accompanies. A fresh [AudioPlayer] is
/// created per call (and disposed once playback finishes) instead of
/// reusing one static instance - reusing the same player after it reaches
/// "completed" doesn't reliably replay on every device, so every event gets
/// a clean player rather than depending on the previous call's state.
class SoundService {
  SoundService._();

  /// A payment was confirmed and the success screen is showing.
  static Future<void> paymentSuccess() async {
    final config = await IsarService.db.storeConfigs.get(1);
    if (config != null && !config.paymentSoundEnabled) return;

    await _haptic(HapticFeedback.mediumImpact);
    await _play('sounds/payment_success.mp3');
  }

  /// A barcode was successfully scanned (phone camera only, not Sunmi's own
  /// hardware scanner, and not a manually-typed barcode).
  static Future<void> scanSuccess() async {
    if (HardwareDetector.isSunmiDevice()) return;

    final config = await IsarService.db.storeConfigs.get(1);
    if (config != null && !config.scanSoundEnabled) return;

    await _haptic(HapticFeedback.selectionClick);
    await _play('sounds/scan_beep.wav');
  }

  static Future<void> _play(String assetPath) async {
    try {
      final player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await player.play(AssetSource(assetPath));
      unawaited(
        player.onPlayerComplete.first
            .then((_) => player.dispose())
            .catchError((_) {}),
      );
    } catch (_) {
      // Silenced device, no audio output, or any other playback failure -
      // the haptic feedback (already fired) is enough on its own.
    }
  }

  static Future<void> _haptic(Future<void> Function() feedback) async {
    try {
      await feedback();
    } catch (_) {
      // Some devices/emulators don't support haptics - never let that
      // interrupt the flow it's meant to accompany.
    }
  }
}
