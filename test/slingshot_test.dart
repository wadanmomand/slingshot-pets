import 'package:flutter_test/flutter_test.dart';
import 'package:smash/core/slingshot.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('launch velocity opposes the drag and scales with power', () {
    final sling = Slingshot(anchor: Vector2(0, 0));
    // Pulled 2m left -> launches right at 2*9 = 18 m/s.
    final v = sling.launchVelocity(Vector2(-2, 0));
    expect(v.x, closeTo(18, 1e-9));
    expect(v.y, closeTo(0, 1e-9));
  });

  test('drag beyond maxDrag is clamped', () {
    final sling = Slingshot(anchor: Vector2(0, 0));
    final v = sling.launchVelocity(Vector2(-10, 0));
    // 2.5m max * 9 power = 22.5 m/s.
    expect(v.x, closeTo(22.5, 1e-9));
  });

  test('trajectory starts at anchor and falls under gravity', () {
    final sling = Slingshot(anchor: Vector2(0, 2));
    final pts = sling.trajectory(Vector2(10, 4), Vector2(0, -10));
    expect(pts.length, 24);
    expect(pts.first.x, greaterThan(0)); // moving right from anchor
    expect(pts.last.y, lessThan(pts.first.y)); // gravity pulls down
  });
}
