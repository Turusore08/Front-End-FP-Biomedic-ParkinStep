/// Port for playing spoken Indonesian onboarding & safety instructions.
abstract interface class VoiceGuidePort {
  Future<void> speak(String text);
  Future<void> stop();
}
