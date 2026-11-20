/// 2D COCO pose keypoint coordinate in sensor image pixel space with detection confidence.
class Keypoint2D {
  const Keypoint2D({
    required this.x,
    required this.y,
    required this.conf,
  });

  static const double confValidThreshold = 0.20;

  final double x;
  final double y;
  final double conf;

  bool get isValid => conf >= confValidThreshold;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Keypoint2D &&
        other.x == x &&
        other.y == y &&
        other.conf == conf;
  }

  @override
  int get hashCode => Object.hash(x, y, conf);
}
