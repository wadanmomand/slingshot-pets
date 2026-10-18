import 'package:flutter_test/flutter_test.dart';
import 'package:smash/core/level_model.dart';

void main() {
  test('LevelDef.fromJson parses bodies and counts pets', () {
    final level = LevelDef.fromJson({
      'id': 1,
      'balls': 3,
      'par': 2,
      'slingX': -6.0,
      'slingY': 2.0,
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 30, 'h': 1},
        {'kind': 'glass', 'x': 5, 'y': 1.5, 'w': 0.2, 'h': 3.0},
        {
          'kind': 'cage',
          'x': 5.9,
          'y': 0.5,
          'w': 1.0,
          'h': 1.0,
          'petId': 'puppy1'
        },
        {
          'kind': 'cage',
          'x': 8,
          'y': 0.5,
          'w': 1.0,
          'h': 1.0,
          'petId': 'kitty1',
          'angle': 0.2,
        },
      ],
    });
    expect(level.id, 1);
    expect(level.balls, 3);
    expect(level.par, 2);
    expect(level.slingX, -6.0);
    expect(level.bodies.length, 4);
    expect(level.bodies[1].kind, SmashBodyKind.glass);
    expect(level.bodies[2].petId, 'puppy1');
    expect(level.bodies[3].angle, 0.2);
    expect(level.totalPets, 2);
  });

  test('unknown kind throws FormatException', () {
    expect(
      () => PlacedBody.fromJson(
          {'kind': 'nope', 'x': 0, 'y': 0, 'w': 1, 'h': 1}),
      throwsFormatException,
    );
  });

  test('toJson round-trips', () {
    const p = PlacedBody(
        kind: SmashBodyKind.wood, x: 1, y: 2, w: 3, h: 0.5, angle: 0.1);
    final back = PlacedBody.fromJson(p.toJson());
    expect(back.kind, SmashBodyKind.wood);
    expect(back.x, 1);
    expect(back.angle, 0.1);
  });
}
