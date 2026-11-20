import '../../application/ports/voice_guide_port.dart';

/// Safe default voice-guide adapter before native TTS plugin wiring in Cueing milestone.
class NoopVoiceGuideAdapter implements VoiceGuidePort {
  const NoopVoiceGuideAdapter();

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
