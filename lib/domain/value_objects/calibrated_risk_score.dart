/// Piecewise-linear calibration mapping model probability `p` against `thr_val`
/// onto a 0..100% patient/clinician gauge scale where `p == thr_val -> 50%`.
abstract final class CalibratedRiskScore {
  static const double defaultLightGbmThreshold = 0.26;

  static double fromRawProbability(
    double rawProb, {
    double threshold = defaultLightGbmThreshold,
  }) {
    final p = rawProb.isFinite ? rawProb.clamp(0.0, 1.0) : 0.0;
    final thr = threshold.isFinite ? threshold.clamp(1e-4, 0.9999) : 0.26;
    final double score;
    if (p < thr) {
      score = 50.0 * (p / thr);
    } else {
      score = 50.0 + 50.0 * ((p - thr) / (1.0 - thr));
    }
    return score.clamp(0.0, 100.0);
  }
}
