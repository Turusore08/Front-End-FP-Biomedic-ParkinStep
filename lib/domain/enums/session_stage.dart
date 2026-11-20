/// Lifecycle stages for S-05 framing/calibration, S-06 live HUD, S-08 fall guard & post-DSP.
enum SessionStage {
  framingCheck,
  calibratingStanding,
  recordingActive,
  fallGuardActive,
  emergencyDispatched,
  postSessionAnalyzing,
  summaryReady,
}
