import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/value_objects/keypoint_2d.dart';

/// One LightGBM-ready window: 126 RAW features plus UI/quality side channels.
class FogWindowFeatures {
  const FogWindowFeatures({
    required this.features,
    required this.freezeIndexAnkle,
    required this.isLowQuality,
  });

  /// `Column_0 .. Column_125` of `lgbm_B_15hz`, unscaled, float32.
  final Float32List features;

  /// Mean `log1p(e_freeze / e_loco)` of vertical velocity (dy) at both ankles.
  final double freezeIndexAnkle;

  /// `true` when > 30% of LB6 points in the window have `conf < 0.20`.
  final bool isLowQuality;
}

/// Immutable, isolate-sendable copy of the LB6 buffer at the moment a window
/// became due. [lb6] is flat `[t][v][x, y, conf]` (`length = frames * 18`).
class FogWindowSnapshot {
  const FogWindowSnapshot({
    required this.lb6,
    required this.frames,
    required this.window,
    required this.lookahead,
    required this.fs,
  });

  final Float32List lb6;
  final int frames;
  final int window;
  final int lookahead;
  final double fs;
}

/// Streaming Scenario B (`B_15hz`) DSP + `extract_fft_kinematic_features`,
/// ported from `parkinsonfp-biomed.ipynb` and
/// `MobileFOG_Rhama_Training_4Models_Kaggle.ipynb`.
///
/// Every [stride] frames the full notebook pipeline (interpolate_low_conf ->
/// Hampel(7, 3.0) -> normalize_lb6 -> np.gradient) runs on all frames seen so
/// far, and the window ending [lookahead] frames before the newest frame is
/// featurized. With 7 lookahead frames the Hampel MAD (needs t+6) and the
/// central difference (needs t+1) inside the window match batch processing
/// exactly; only the session-wide medians in normalize_lb6 see "trial so far"
/// instead of the whole trial. No Butterworth: production runs at 15 Hz.
class FogFeatureExtractor {
  FogFeatureExtractor({
    this.window = 30,
    this.stride = 15,
    this.lookahead = 7,
    this.fs = 15.0,
    this.maxBufferFrames = 2700,
  });

  final int window;
  final int stride;
  final int lookahead;
  final double fs;

  /// Caps memory at 3 minutes @ 15 Hz; oldest frames drop out of the medians.
  final int maxBufferFrames;

  static const List<int> lb6Indices = <int>[11, 12, 13, 14, 15, 16];
  static const int joints = 6;
  static const int featureCount = 126;
  static const double confValid = Keypoint2D.confValidThreshold;
  static const int hampelWindow = 7;
  static const double hampelSigma = 3.0;
  static const double lowQualityRatio = 0.30;

  /// Flat `[t][v][x, y, conf]` LB6 buffer stored as float32 like the notebook.
  final List<Float32List> _frames = <Float32List>[];
  int _framesSinceEmit = 0;
  bool _hasEmitted = false;

  int get bufferLength => _frames.length;

  void reset() {
    _frames.clear();
    _framesSinceEmit = 0;
    _hasEmitted = false;
  }

  /// Appends one LB6 frame laid out as `[v][x, y, conf]` (18 values).
  /// Synchronous convenience: [pushLb6Snapshot] + [computeWindow] inline.
  FogWindowFeatures? pushLb6(Float32List lb6Frame) {
    final snapshot = pushLb6Snapshot(lb6Frame);
    return snapshot == null ? null : computeWindow(snapshot);
  }

  /// Appends one 17-COCO frame; returns a snapshot when a new window is due.
  /// Cheap (buffer copy only) so it can run on the UI isolate.
  FogWindowSnapshot? pushSnapshot(List<Keypoint2D> keypoints17) {
    final frame = Float32List(joints * 3);
    for (var v = 0; v < joints; v++) {
      final kp = keypoints17[lb6Indices[v]];
      frame[v * 3] = kp.x;
      frame[v * 3 + 1] = kp.y;
      frame[v * 3 + 2] = kp.conf;
    }
    return pushLb6Snapshot(frame);
  }

  /// Appends one LB6 frame (`[v][x, y, conf]`); returns a snapshot when due.
  FogWindowSnapshot? pushLb6Snapshot(Float32List lb6Frame) {
    _frames.add(lb6Frame);
    if (_frames.length > maxBufferFrames) _frames.removeAt(0);
    _framesSinceEmit++;

    if (_frames.length < window + lookahead) return null;
    if (_hasEmitted && _framesSinceEmit < stride) return null;
    _hasEmitted = true;
    _framesSinceEmit = 0;

    const width = joints * 3;
    final flat = Float32List(_frames.length * width);
    for (var t = 0; t < _frames.length; t++) {
      flat.setRange(t * width, (t + 1) * width, _frames[t]);
    }
    return FogWindowSnapshot(
      lb6: flat,
      frames: _frames.length,
      window: window,
      lookahead: lookahead,
      fs: fs,
    );
  }

  /// Full notebook DSP + feature extraction for the newest due window.
  /// Pure and static so it can run inside `Isolate.run`.
  static FogWindowFeatures computeWindow(FogWindowSnapshot snap) {
    final n = snap.frames;
    final x = List<Float32List>.generate(joints, (_) => Float32List(n));
    final y = List<Float32List>.generate(joints, (_) => Float32List(n));
    final c = List<Float32List>.generate(joints, (_) => Float32List(n));
    for (var t = 0; t < n; t++) {
      final base = t * joints * 3;
      for (var v = 0; v < joints; v++) {
        x[v][t] = snap.lb6[base + v * 3];
        y[v][t] = snap.lb6[base + v * 3 + 1];
        c[v][t] = snap.lb6[base + v * 3 + 2];
      }
    }

    for (var v = 0; v < joints; v++) {
      _interpolateLowConf(x[v], y[v], c[v]);
      x[v] = hampel(x[v]);
      y[v] = hampel(y[v]);
    }
    final (xn, yn) = _normalize(x, y);
    final dx = List<Float32List>.generate(joints, (v) => gradient(xn[v]));
    final dy = List<Float32List>.generate(joints, (v) => gradient(yn[v]));

    final end = n - snap.lookahead;
    final start = end - snap.window;
    Float32List slice(Float32List s) => Float32List.sublistView(s, start, end);

    return extractFeatures(
      x: [for (final s in xn) slice(s)],
      y: [for (final s in yn) slice(s)],
      conf: [for (final s in c) slice(s)],
      dx: [for (final s in dx) slice(s)],
      dy: [for (final s in dy) slice(s)],
      fs: snap.fs,
    );
  }

  /// `interpolate_low_conf`: np.interp over good frames, ends held constant.
  static void _interpolateLowConf(
    Float32List xs,
    Float32List ys,
    Float32List cs,
  ) {
    final n = cs.length;
    final good = <int>[
      for (var t = 0; t < n; t++)
        if (cs[t] >= confValid) t,
    ];
    if (good.isEmpty) {
      xs.fillRange(0, n, 0);
      ys.fillRange(0, n, 0);
      return;
    }
    if (good.length == n) return;

    final gx = Float64List.fromList([for (final t in good) xs[t]]);
    final gy = Float64List.fromList([for (final t in good) ys[t]]);
    var k = 0;
    for (var t = 0; t < n; t++) {
      while (k < good.length - 1 && good[k + 1] <= t) {
        k++;
      }
      if (t <= good.first) {
        xs[t] = gx.first;
        ys[t] = gy.first;
      } else if (t >= good.last) {
        xs[t] = gx.last;
        ys[t] = gy.last;
      } else {
        final t0 = good[k];
        final t1 = good[k + 1];
        final w = (t - t0) / (t1 - t0);
        xs[t] = gx[k] + w * (gx[k + 1] - gx[k]);
        ys[t] = gy[k] + w * (gy[k + 1] - gy[k]);
      }
    }
  }

  /// `hampel_filter_1d`: pandas centered rolling median, `min_periods=1`.
  static Float32List hampel(
    Float32List sig, {
    int window = hampelWindow,
    double nSigma = hampelSigma,
  }) {
    final n = sig.length;
    final s = Float64List.fromList(sig);
    final med = _rollingMedian(s, window);
    final dev = Float64List(n);
    for (var i = 0; i < n; i++) {
      dev[i] = (s[i] - med[i]).abs();
    }
    final mad = _rollingMedian(dev, window);
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final isOutlier = dev[i] > nSigma * 1.4826 * mad[i];
      out[i] = isOutlier ? med[i] : s[i];
    }
    return out;
  }

  static Float64List _rollingMedian(Float64List s, int window) {
    final n = s.length;
    final left = (window - 1) ~/ 2;
    final right = window ~/ 2;
    final out = Float64List(n);
    final buf = <double>[];
    for (var i = 0; i < n; i++) {
      buf.clear();
      final lo = math.max(0, i - left);
      final hi = math.min(n - 1, i + right);
      for (var j = lo; j <= hi; j++) {
        buf.add(s[j]);
      }
      out[i] = _median(buf);
    }
    return out;
  }

  static double _median(List<double> values) {
    values.sort();
    final m = values.length ~/ 2;
    return values.length.isOdd ? values[m] : (values[m - 1] + values[m]) / 2.0;
  }

  /// `normalize_lb6`: center on median pelvis, scale by median leg length.
  static (List<Float32List>, List<Float32List>) _normalize(
    List<Float32List> x,
    List<Float32List> y,
  ) {
    final n = x[0].length;
    final pelvisX = <double>[];
    final pelvisY = <double>[];
    final legs = <double>[];
    double dist(int a, int b, int t) {
      final ddx = _f32(x[a][t] - x[b][t]);
      final ddy = _f32(y[a][t] - y[b][t]);
      return _f32(math.sqrt(ddx * ddx + ddy * ddy));
    }

    for (var t = 0; t < n; t++) {
      pelvisX.add(_f32(0.5 * _f32(x[0][t] + x[1][t])));
      pelvisY.add(_f32(0.5 * _f32(y[0][t] + y[1][t])));
      final legL = _f32(dist(0, 2, t) + dist(2, 4, t));
      final legR = _f32(dist(1, 3, t) + dist(3, 5, t));
      legs.add(_f32(0.5 * _f32(legL + legR)));
    }
    final cx = _f32(_median(pelvisX));
    final cy = _f32(_median(pelvisY));
    final scale = math.max(_f32(_median(legs)), 1e-4);

    final xn = List<Float32List>.generate(joints, (v) {
      final out = Float32List(n);
      for (var t = 0; t < n; t++) {
        out[t] = _f32(x[v][t] - cx) / scale;
      }
      return out;
    });
    final yn = List<Float32List>.generate(joints, (v) {
      final out = Float32List(n);
      for (var t = 0; t < n; t++) {
        out[t] = _f32(y[v][t] - cy) / scale;
      }
      return out;
    });
    return (xn, yn);
  }

  /// `np.gradient` (unit spacing): central inside, one-sided at the ends.
  static Float32List gradient(Float32List f) {
    final n = f.length;
    final out = Float32List(n);
    if (n < 2) return out;
    out[0] = f[1] - f[0];
    out[n - 1] = f[n - 1] - f[n - 2];
    for (var i = 1; i < n - 1; i++) {
      out[i] = (f[i + 1] - f[i - 1]) / 2.0;
    }
    return out;
  }

  /// `extract_fft_kinematic_features` for one window; each list is `[v][t]`.
  static FogWindowFeatures extractFeatures({
    required List<Float32List> x,
    required List<Float32List> y,
    required List<Float32List> conf,
    required List<Float32List> dx,
    required List<Float32List> dy,
    required double fs,
  }) {
    final t = x[0].length;
    final out = Float32List(featureCount);
    var k = 0;
    void put(double v) => out[k++] = v.isFinite ? v : 0.0;

    // 1) mean / std(ddof=0) / max|.| per channel x, y, dx, dy.
    for (final ch in <List<Float32List>>[x, y, dx, dy]) {
      for (var v = 0; v < joints; v++) {
        put(_mean(ch[v]));
      }
      for (var v = 0; v < joints; v++) {
        put(_std(ch[v]));
      }
      for (var v = 0; v < joints; v++) {
        put(_maxAbs(ch[v]));
      }
    }

    // 2) Band energies & Moore's freeze index on dx, dy (unnormalized rfft).
    final bins = t ~/ 2 + 1;
    final freezeHi = math.min(8.0, 0.49 * fs);
    final loco = <int>[];
    final freeze = <int>[];
    for (var b = 0; b < bins; b++) {
      final f = b * fs / t;
      if (f >= 0.5 && f <= 3.0) loco.add(b);
      if (f > 3.0 && f <= freezeHi) freeze.add(b);
    }
    var fiAnkleSum = 0.0;
    for (final (chIdx, ch) in <(int, List<Float32List>)>[(3, dx), (4, dy)]) {
      final eLoco = Float64List(joints);
      final eFreeze = Float64List(joints);
      for (var v = 0; v < joints; v++) {
        final psd = _powerSpectrum(ch[v]);
        for (final b in loco) {
          eLoco[v] += psd[b];
        }
        for (final b in freeze) {
          eFreeze[v] += psd[b];
        }
        eLoco[v] += 1e-8;
        eFreeze[v] += 1e-8;
      }
      for (var v = 0; v < joints; v++) {
        put(_log1p(eLoco[v]));
      }
      for (var v = 0; v < joints; v++) {
        put(_log1p(eFreeze[v]));
      }
      for (var v = 0; v < joints; v++) {
        final fi = _log1p(eFreeze[v] / eLoco[v]);
        put(fi);
        if (chIdx == 4 && v >= 4) fiAnkleSum += fi;
      }
    }

    // 3) Bilateral distance & velocity asymmetry for hip, knee, ankle pairs.
    for (final (l, r) in const <(int, int)>[(0, 1), (2, 3), (4, 5)]) {
      final distXy = Float32List(t);
      final asymV = Float32List(t);
      for (var i = 0; i < t; i++) {
        final ddx = x[l][i] - x[r][i];
        final ddy = y[l][i] - y[r][i];
        distXy[i] = math.sqrt(ddx * ddx + ddy * ddy);
        asymV[i] = (dx[l][i] - dx[r][i]).abs() + (dy[l][i] - dy[r][i]).abs();
      }
      put(_mean(distXy));
      put(_std(distXy));
      put(_mean(asymV));
      put(_std(asymV));
    }

    // 4) Mean confidence per joint.
    var lowConf = 0;
    for (var v = 0; v < joints; v++) {
      put(_mean(conf[v]));
      for (var i = 0; i < t; i++) {
        if (conf[v][i] < confValid) lowConf++;
      }
    }

    return FogWindowFeatures(
      features: out,
      freezeIndexAnkle: fiAnkleSum / 2,
      isLowQuality: lowConf / (joints * t) > lowQualityRatio,
    );
  }

  static Float64List _powerSpectrum(Float32List sig) {
    final n = sig.length;
    final mean = _mean(sig);
    final centered = Float64List(n);
    for (var i = 0; i < n; i++) {
      centered[i] = _f32(sig[i] - mean);
    }
    final bins = n ~/ 2 + 1;
    final psd = Float64List(bins);
    for (var b = 0; b < bins; b++) {
      var re = 0.0;
      var im = 0.0;
      for (var i = 0; i < n; i++) {
        final a = 2 * math.pi * b * i / n;
        re += centered[i] * math.cos(a);
        im -= centered[i] * math.sin(a);
      }
      psd[b] = re * re + im * im;
    }
    return psd;
  }

  static double _mean(Float32List a) {
    var s = 0.0;
    for (final v in a) {
      s += v;
    }
    return s / a.length;
  }

  static double _std(Float32List a) {
    final m = _mean(a);
    var s = 0.0;
    for (final v in a) {
      final d = v - m;
      s += d * d;
    }
    return math.sqrt(s / a.length);
  }

  static double _maxAbs(Float32List a) {
    var m = 0.0;
    for (final v in a) {
      final av = v.abs();
      if (av > m) m = av;
    }
    return m;
  }

  static double _log1p(double v) => math.log(1 + v);

  static final Float32List _f32Box = Float32List(1);

  /// Rounds to float32 to mirror NumPy float32 intermediate storage.
  static double _f32(double v) {
    _f32Box[0] = v;
    return _f32Box[0];
  }
}
