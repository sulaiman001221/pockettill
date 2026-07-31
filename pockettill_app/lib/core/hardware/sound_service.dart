import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays a short success chime plus medium haptic feedback when a payment
/// is confirmed and the success screen appears.
///
/// Fire-and-forget and never throws - a silenced device, a missing audio
/// backend, or any other playback failure is swallowed so it can never
/// crash or block the success screen it accompanies. A fresh [AudioPlayer]
/// is created per call (and disposed once playback finishes) instead of
/// reusing one static instance - reusing the same player after it reaches
/// "completed" doesn't reliably replay on every device, so every payment
/// gets a clean player rather than depending on the previous call's state.
class SoundService {
  SoundService._();

  /// A payment was confirmed and the success screen is showing.
  static Future<void> paymentSuccess() async {
    await _haptic(HapticFeedback.mediumImpact);
    await _play('sounds/payment_success.mp3');
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
      // interrupt the payment flow it's meant to accompany.
    }
  }
}
