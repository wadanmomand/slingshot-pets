// Temporary smoke test: verifies pure-Dart forge2d works under flutter test.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';

void main() {
  test('forge2d world steps and gravity applies', () {
    final world = World(Vector2(0, -10));
    final body = world.createBody(
      BodyDef(type: BodyType.dynamic, position: Vector2(0, 5)),
    );
    body.createFixtureFromShape(CircleShape(radius: 0.5), density: 1.0);
    final y0 = body.position.y;
    for (var i = 0; i < 60; i++) {
      world.stepDt(1 / 60);
    }
    expect(body.position.y, lessThan(y0));
  });
}
