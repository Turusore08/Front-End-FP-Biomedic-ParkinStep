/// Interactive gait scenarios supported by preview edge-AI simulation mode.
enum PreviewGaitScenario {
  normalGait('Normal'),
  lowLightOcclusion('Redup'),
  confirmedFog('FoG'),
  suddenFall('Jatuh');

  const PreviewGaitScenario(this.labelId);

  final String labelId;
}
