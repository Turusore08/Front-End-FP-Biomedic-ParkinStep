import 'package:flutter/services.dart';

import '../../application/ports/voice_guide_port.dart';

/// Spoken Indonesian instruction adapter delegating to Android TextToSpeech via
/// MethodChannel, gracefully degrading to no-op in tests or unsupported hosts.
class PlatformVoiceGuideAdapter implements VoiceGuidePort {
  const PlatformVoiceGuideAdapter([this._channel]);

  static const MethodChannel _defaultChannel =
      MethodChannel('id.parkinstep.parkinstep/tts');

  final MethodChannel? _channel;

  MethodChannel get _resolvedChannel => _channel ?? _defaultChannel;

  @override
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _resolvedChannel.invokeMethod<void>(
        'speak',
        <String, Object?>{'text': trimmed},
      );
    } on MissingPluginException {
      // Unit/widget tests and hosts without native TTS safely ignore voice output.
    } on PlatformException {
      // Never block clinical recording flow if OS TTS engine is unavailable.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _resolvedChannel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No-op when plugin is not registered.
    } on PlatformException {
      // Ignore transient OS TTS errors on stop.
    }
  }
}
