// Physics integration tests: break-on-impact, pet rescue, win/lose.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash/core/level_model.dart';
import 'package:smash/core/smash_world.dart';
import 'package:vector_math/vector_math.dart';

/// Horizontal range: glass pane in front of the slingshot.
LevelDef _glassRangeLevel() {
  return LevelDef.fromJson({
    'id': 1,
    'balls': 3,
    'par': 1,
    'slingX': 0.0,
    'slingY': 2.0,
    'bodies': [
      {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
      {'kind': 'glass', 'x': 5, 'y': 1.5, 'w': 0.2, 'h': 3.0},
    ],
  });
}

/// Drop tower: ball drops straight onto a caged pet.
LevelDef _dropOnCageLevel() {
  return LevelDef.fromJson({
    'id': 2,
    'balls': 2,
    'par': 1,
    'slingX': 5.9,
    'slingY': 6.0,
    'bodies': [
      {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
      {
        'kind': 'cage',
        'x': 5.9,
        'y': 0.5,
        'w': 1.0,
        'h': 1.0,
        'petId': 'puppy1'
      },
    ],
  });
}

void _stepUntil(SmashWorld w, bool Function() done, {int max = 1200}) {
  var n = 0;
  while (!done() && n < max) {
    w.step(1 / 60);
    n++;
  }
}

void main() {
  test('fast ball shatters glass pane', () {
    final w = SmashWorld(_glassRangeLevel());
    expect(w.phase, GamePhase.aiming);
    w.launchBall(Vector2(12, 0.5));
    expect(w.phase, GamePhase.flying);
    // Let the ball resolve (bounce back, roll, come to rest).
    _stepUntil(w, () => w.phase == GamePhase.aiming);
    expect(w.phase, GamePhase.aiming);
    final kinds = w.takeBreakEvents().map((e) => e.kind).toSet();
    expect(kinds, contains(SmashBodyKind.glass));
    expect(w.ballsLeft, 2);
  });

  test('dropped ball breaks cage, frees pet, wins', () {
    final w = SmashWorld(_dropOnCageLevel());
    w.launchBall(Vector2(0, 0)); // straight drop from 6m: ~9.7 m/s impact
    _stepUntil(w, () => w.phase == GamePhase.won);
    expect(w.phase, GamePhase.won);
    expect(w.freedPets, contains('puppy1'));
    final events = w.takeBreakEvents();
    final cageEvents =
        events.where((e) => e.kind == SmashBodyKind.cage).toList();
    expect(cageEvents.length, 1);
    expect(cageEvents.first.petId, 'puppy1');
    expect(w.ballsUsed, 1);
    expect(w.starsForWin(), 3); // par is 1
  });

  test('light tap does not break wood', () {
    final level = LevelDef.fromJson({
      'id': 3,
      'balls': 3,
      'par': 3,
      'slingX': 3.0,
      'slingY': 1.2, // ball drops ~0.4m onto the plank: gentle
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
        {'kind': 'wood', 'x': 3, 'y': 0.25, 'w': 2.0, 'h': 0.5},
      ],
    });
    final w = SmashWorld(level);
    w.launchBall(Vector2(0, 0)); // drop from rest
    _stepUntil(w, () => w.phase == GamePhase.aiming && w.ballsUsed == 1);
    expect(w.takeBreakEvents(), isEmpty);
    expect(w.ballsLeft, 2);
  });

  test('wasted balls lead to loss once settled', () {
    final level = LevelDef.fromJson({
      'id': 4,
      'balls': 1,
      'par': 1,
      'slingX': 0.0,
      'slingY': 2.0,
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
        {
          'kind': 'cage',
          'x': 15, // on the ground, far from the leftward throw
          'y': 0.5,
          'w': 1.0,
          'h': 1.0,
          'petId': 'far1'
        },
      ],
    });
    final w = SmashWorld(level);
    w.launchBall(Vector2(-4, 3)); // throw away from the cage
    _stepUntil(w, () => w.phase == GamePhase.lost, max: 1500);
    expect(w.phase, GamePhase.lost);
    expect(w.freedPets, isEmpty);
  });

  test('launch is ignored with no balls left or ball in flight', () {
    final w = SmashWorld(_glassRangeLevel());
    w.launchBall(Vector2(1, 1));
    final usedAfterFirst = w.ballsUsed;
    w.launchBall(Vector2(1, 1)); // ball in flight: ignored
    expect(w.ballsUsed, usedAfterFirst);
  });

  test('tnt blast frees a nearby cage', () {
    // Ball drops vertically onto the barrel; the cage beside it is never
    // touched directly, so only the blast can free it.
    final level = LevelDef.fromJson({
      'id': 10,
      'balls': 3,
      'par': 1,
      'slingX': 5.0,
      'slingY': 6.0,
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
        {'kind': 'tnt', 'x': 5.0, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        {
          'kind': 'cage',
          'x': 6.2,
          'y': 0.70,
          'w': 1.40,
          'h': 1.40,
          'petId': 'blast1'
        },
      ],
    });
    final w = SmashWorld(level);
    w.launchBall(Vector2(0, 0)); // straight drop onto the barrel
    _stepUntil(w, () => w.phase == GamePhase.won);
    expect(w.phase, GamePhase.won);
    expect(w.freedPets, contains('blast1'));
    final kinds = w.takeBreakEvents().map((e) => e.kind).toSet();
    expect(kinds, contains(SmashBodyKind.tnt));
    expect(kinds, contains(SmashBodyKind.cage));
  });

  test('tnt chain reaction frees a distant cage', () {
    // Cage is 5.0m from the first barrel (beyond the 3.5m blast) but
    // 2.5m from the second barrel: only a chain frees it.
    final level = LevelDef.fromJson({
      'id': 11,
      'balls': 3,
      'par': 1,
      'slingX': 5.0,
      'slingY': 6.0,
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
        {'kind': 'tnt', 'x': 5.0, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        {'kind': 'tnt', 'x': 7.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        {
          'kind': 'cage',
          'x': 10.0,
          'y': 0.70,
          'w': 1.40,
          'h': 1.40,
          'petId': 'chain1'
        },
      ],
    });
    final w = SmashWorld(level);
    w.launchBall(Vector2(0, 0));
    _stepUntil(w, () => w.phase == GamePhase.won);
    expect(w.phase, GamePhase.won);
    expect(w.freedPets, contains('chain1'));
    final tntEvents = w
        .takeBreakEvents()
        .where((e) => e.kind == SmashBodyKind.tnt)
        .toList();
    expect(tntEvents.length, 2);
  });

  test('tnt blast leaves stone and distant cages untouched', () {
    final level = LevelDef.fromJson({
      'id': 12,
      'balls': 3,
      'par': 1,
      'slingX': 5.0,
      'slingY': 6.0,
      'bodies': [
        {'kind': 'ground', 'x': 0, 'y': -0.5, 'w': 40, 'h': 1},
        {'kind': 'tnt', 'x': 5.0, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        {'kind': 'stone', 'x': 6.0, 'y': 0.5, 'w': 1.0, 'h': 1.0},
        {
          'kind': 'cage',
          'x': 12.0,
          'y': 0.70,
          'w': 1.40,
          'h': 1.40,
          'petId': 'far2'
        },
      ],
    });
    final w = SmashWorld(level);
    w.launchBall(Vector2(0, 0));
    _stepUntil(w, () => w.phase == GamePhase.aiming && w.ballsUsed == 1);
    expect(w.freedPets, isEmpty);
    expect(w.phase, isNot(GamePhase.won));
    expect(w.bodies.any((b) => b.kind == SmashBodyKind.stone), isTrue);
    expect(w.bodies.any((b) => b.kind == SmashBodyKind.cage), isTrue);
  });
}
