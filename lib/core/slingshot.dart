// Slingshot aim model: drag vector -> launch velocity + trajectory preview.
// Pure Dart — no physics dependency, fully unit-testable.
import 'package:vector_math/vector_math.dart';

class Slingshot {
  /// Sling anchor in meters (y-up world coords).
  final Vector2 anchor;

  /// Max pull distance in meters.
  final double maxDrag;

  /// Launch speed per meter of pull (m/s per m).
  final double power;

  const Slingshot({
    required this.anchor,
    this.maxDrag = 2.5,
    this.power = 9.0,
  });

  /// [drag] is the finger position minus anchor (i.e. how far the band is
  /// pulled, in world meters). Launch goes opposite the pull.
  Vector2 launchVelocity(Vector2 drag) {
    final pull = drag.clone();
    if (pull.length > maxDrag) {
      pull.normalize();
      pull.scale(maxDrag);
    }
    return Vector2(-pull.x * power, -pull.y * power);
  }

  /// Analytic projectile preview points (no collisions), for the aim dots.
  List<Vector2> trajectory(
    Vector2 velocity,
    Vector2 gravity, {
    int points = 24,
    double dt = 1 / 30,
  }) {
    final out = <Vector2>[];
    var p = anchor.clone();
    var v = velocity.clone();
    for (var i = 0; i < points; i++) {
      v = v + gravity * dt;
      p = p + v * dt;
      out.add(p.clone());
    }
    return out;
  }
}
