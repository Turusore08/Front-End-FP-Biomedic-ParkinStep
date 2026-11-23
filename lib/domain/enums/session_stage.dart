/// Lifecycle stages for video-based gait recording & post-recording pose extraction.
enum SessionStage {
  readyToRecord,
  countdown,
  recordingActive,
  reviewRecorded,
  analyzingVideo,
  summaryReady,
}
