// Generates the Pawzzle Smash launch level pack.
//
// Every level is validated by simulating its solution shots in the real
// SmashWorld physics: a level only ships if the shots free all pets within
// the ball budget. Deterministic (seeded RNG).
//
// Run:  dart run tool/generate_levels.dart
// Out:  assets/levels/levels.json
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:forge2d/forge2d.dart';
import 'package:smash/core/level_model.dart';
import 'package:smash/core/smash_world.dart';

const double _g = 10.0;
const double _slingX = -4.0; // moved inward 2026-10-19: was -6.0, too close to screen edge to drag
const double _slingY = 2.0;
const int _targetLevels = 1000;
const int _maxAttempts = 30000;
const int _levelsPerChapter = 100;

class ShotPlan {
  final Vector2 target;
  final double speed;
  final bool highArc;
  ShotPlan(this.target, this.speed, {this.highArc = false});
}

/// Ballistic solution: launch velocity from [from] that passes through
/// [target] at the given speed. Null when unreachable at that speed.
Vector2? solveShot(Vector2 from, Vector2 target, double speed,
    {bool highArc = false}) {
  final dx = target.x - from.x;
  final dy = target.y - from.y;
  if (dx <= 0.5) return null;
  final v2 = speed * speed;
  final a = _g * dx * dx / (2 * v2);
  final disc = dx * dx - 4 * a * (dy + a);
  if (disc < 0) return null;
  final sq = sqrt(disc);
  final u1 = (dx - sq) / (2 * a);
  final u2 = (dx + sq) / (2 * a);
  final u = highArc ? max(u1, u2) : min(u1, u2);
  final theta = atan(u);
  return Vector2(cos(theta) * speed, sin(theta) * speed);
}

// ---------------------------------------------------------------------------
// Builders: each returns a level + the shots that solve it.
// ---------------------------------------------------------------------------

PlacedBody _ground() => const PlacedBody(
    kind: SmashBodyKind.ground, x: 4, y: -0.5, w: 32, h: 1);

PlacedBody _box(SmashBodyKind kind, double x, double y, double w, double h,
        {double angle = 0, String? petId}) =>
    PlacedBody(
        kind: kind, x: x, y: y, w: w, h: h, angle: angle, petId: petId);

double _j(Random rng, double v, double amt) => v + (rng.nextDouble() * 2 - 1) * amt;

({LevelDef level, List<ShotPlan> shots}) _tOpen(Random rng, int id) {
  final cx = _j(rng, 7.0, 1.0);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [_ground(), _box(SmashBodyKind.cage, cx, 0.84, 1.68, 1.68, petId: pet)],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.84), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tStack(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 2.70, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 2.70), 13.5)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tGlassHouse(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.glass, cx - 0.9, 0.75, 0.15, 1.5),
      _box(SmashBodyKind.glass, cx + 0.9, 0.75, 0.15, 1.5),
      _box(SmashBodyKind.glass, cx, 1.55, 2.1, 0.15),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 0.9, 0.75), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTower(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 2.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 3.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Smash the base: tower topples, cage falls ~3.5m and bursts on landing.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.5), 14)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tStoneShield(Random rng, int id) {
  final cx = _j(rng, 7.2, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.stone, 5.0, 1.3, 0.6, 2.6),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Lob over the unbreakable wall.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.70), 14.5, highArc: true)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tBridge(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 2,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx - 1.2, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx + 1.2, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.15, 3.8, 0.3),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Break a support, then hit the exposed cage.
  return (
    level: level,
    shots: [
      ShotPlan(Vector2(cx - 1.2, 0.5), 13.5),
      ShotPlan(Vector2(cx, 0.70), 13),
    ],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTwin(Random rng, int id) {
  final x1 = _j(rng, 5.0, 0.5);
  final x2 = _j(rng, 9.0, 0.5);
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 2,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.cage, x1, 0.70, 1.40, 1.40, petId: 'L${id}p1'),
      _box(SmashBodyKind.cage, x2, 0.70, 1.40, 1.40, petId: 'L${id}p2'),
    ],
  );
  return (
    level: level,
    shots: [
      ShotPlan(Vector2(x1, 0.70), 13),
      ShotPlan(Vector2(x2, 0.70), 13),
    ],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tPyramid(Random rng, int id) {
  final cx = _j(rng, 6.5, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx - 0.5, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx + 0.5, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 2.70, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 0.5, 0.5), 14)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tPerch(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx - 1, 1.1, 0.8, 2.2),
      _box(SmashBodyKind.wood, cx + 1, 1.1, 0.8, 2.2),
      _box(SmashBodyKind.wood, cx, 2.35, 3, 0.3),
      _box(SmashBodyKind.cage, cx, 3.20, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 3.20), 13.5)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tDome(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.glass, cx - 0.55, 0.9, 0.15, 1.9, angle: 0.45),
      _box(SmashBodyKind.glass, cx + 0.55, 0.9, 0.15, 1.9, angle: -0.45),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 0.55, 0.9), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tDouble(Random rng, int id) {
  final x1 = _j(rng, 5.0, 0.5);
  final x2 = _j(rng, 9.0, 0.5);
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 2,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.cage, x1, 0.70, 1.40, 1.40, petId: 'L${id}p1'),
      _box(SmashBodyKind.wood, x2, 0.5, 1, 1),
      _box(SmashBodyKind.wood, x2, 1.5, 1, 1),
      _box(SmashBodyKind.cage, x2, 2.70, 1.40, 1.40, petId: 'L${id}p2'),
    ],
  );
  return (
    level: level,
    shots: [
      ShotPlan(Vector2(x1, 0.70), 13),
      ShotPlan(Vector2(x2, 2.70), 13.5),
    ],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tFortress(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.stone, cx - 1, 0.5, 0.8, 1),
      _box(SmashBodyKind.stone, cx + 1, 0.5, 0.8, 1),
      _box(SmashBodyKind.wood, cx, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 2.70, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 2.70), 13.5)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tCorridor(Random rng, int id) {
  final cx = _j(rng, 7.5, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.glass, cx - 1.5, 0.75, 0.15, 1.5),
      _box(SmashBodyKind.glass, cx - 0.9, 0.75, 0.15, 1.5),
      _box(SmashBodyKind.glass, cx - 1.2, 1.55, 1.3, 0.15),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Smash through the glass corridor into the cage.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 1.5, 0.75), 14)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tSeesaw(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.stone, cx, 0.3, 0.6, 0.6),
      _box(SmashBodyKind.wood, cx, 0.85, 3.6, 0.25),
      _box(SmashBodyKind.cage, cx + 1.3, 1.55, 1.40, 1.40, petId: pet),
    ],
  );
  // Cage perched on the plank end: direct hit.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx + 1.3, 1.55), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tBunker(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx - 1.2, 0.75, 0.5, 1.5),
      _box(SmashBodyKind.wood, cx + 1.2, 0.75, 0.5, 1.5),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Lob into the open-topped bunker.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.70), 14, highArc: true)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tSplitBridge(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.wood, cx - 1, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx + 1, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.15, 3.4, 0.3),
      _box(SmashBodyKind.cage, cx, 2.00, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 2.00), 13.5)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tArch(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.6);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 4,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.stone, cx - 1, 1.0, 0.6, 2),
      _box(SmashBodyKind.stone, cx + 1, 1.0, 0.6, 2),
      _box(SmashBodyKind.wood, cx, 2.15, 2.6, 0.3),
      _box(SmashBodyKind.cage, cx, 3.00, 1.40, 1.40, petId: pet),
    ],
  );
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 3.00), 13.5)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tScatter(Random rng, int id) {
  final x1 = _j(rng, 4.5, 0.4);
  final x2 = _j(rng, 7.0, 0.4);
  final x3 = _j(rng, 9.5, 0.4);
  final level = LevelDef(
    id: id,
    balls: 5,
    par: 3,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.cage, x1, 0.70, 1.40, 1.40, petId: 'L${id}p1'),
      _box(SmashBodyKind.cage, x2, 0.70, 1.40, 1.40, petId: 'L${id}p2'),
      _box(SmashBodyKind.cage, x3, 0.70, 1.40, 1.40, petId: 'L${id}p3'),
    ],
  );
  return (
    level: level,
    shots: [
      ShotPlan(Vector2(x1, 0.70), 13),
      ShotPlan(Vector2(x2, 0.70), 13),
      ShotPlan(Vector2(x3, 0.70), 13),
    ],
  );
}

// ---------------------------------------------------------------------------
// TNT templates (new in v1.0.2): the first NEW VERB since launch. Earlier
// chapters only re-shaped the same break-the-structure loop; TNT adds
// explosions and chain reactions, so later levels play differently.
// ---------------------------------------------------------------------------

({LevelDef level, List<ShotPlan> shots}) _tTnt(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.tnt, cx - 1.2, 0.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Hit the barrel: the blast (3.5m) frees the cage.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 1.2, 0.5), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTntChain(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.tnt, cx - 2.4, 0.5, 1, 1),
      _box(SmashBodyKind.tnt, cx - 1.2, 0.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // One hit sets off the chain: barrel 1 -> barrel 2 -> cage.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 2.4, 0.5), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTntShield(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.tnt, cx - 2.2, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx - 1.0, 0.75, 0.5, 1.5),
      _box(SmashBodyKind.cage, cx, 0.70, 1.40, 1.40, petId: pet),
    ],
  );
  // The wood wall blocks a direct shot; the blast clears wall + cage.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx - 2.2, 0.5), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTntTwin(Random rng, int id) {
  final x1 = _j(rng, 5.0, 0.5);
  final x2 = _j(rng, 9.0, 0.5);
  final cx = (x1 + x2) / 2;
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.tnt, cx, 0.5, 1, 1),
      _box(SmashBodyKind.cage, x1, 0.70, 1.40, 1.40, petId: 'L${id}p1'),
      _box(SmashBodyKind.cage, x2, 0.70, 1.40, 1.40, petId: 'L${id}p2'),
    ],
  );
  // One barrel between two pets: a single blast frees both.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.5), 13)],
  );
}

({LevelDef level, List<ShotPlan> shots}) _tTntDrop(Random rng, int id) {
  final cx = _j(rng, 7.0, 0.8);
  final pet = 'L${id}p1';
  final level = LevelDef(
    id: id,
    balls: 3,
    par: 1,
    slingX: _slingX,
    slingY: _slingY,
    bodies: [
      _ground(),
      _box(SmashBodyKind.tnt, cx, 0.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 1.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 2.5, 1, 1),
      _box(SmashBodyKind.wood, cx, 3.5, 1, 1),
      _box(SmashBodyKind.cage, cx, 4.70, 1.40, 1.40, petId: pet),
    ],
  );
  // Blast clears the tower base (cage at 4.2m is beyond the 3.5m blast);
  // the cage falls ~4.7m and bursts on landing.
  return (
    level: level,
    shots: [ShotPlan(Vector2(cx, 0.5), 13)],
  );
}

typedef _Builder = ({LevelDef level, List<ShotPlan> shots}) Function(
    Random rng, int id);

const List<List<_Builder>> _chapterTemplates = [
  [_tOpen, _tStack, _tGlassHouse, _tTnt],
  [_tOpen, _tStack, _tGlassHouse, _tTower, _tTwin, _tTnt, _tTntChain],
  [_tTower, _tStoneShield, _tBridge, _tTwin, _tPyramid, _tTntChain, _tTntShield],
  [
    _tTower,
    _tStoneShield,
    _tBridge,
    _tPyramid,
    _tPerch,
    _tDome,
    _tTntShield,
    _tTntTwin
  ],
  [
    _tGlassHouse,
    _tPerch,
    _tDome,
    _tDouble,
    _tFortress,
    _tCorridor,
    _tTnt,
    _tTntTwin,
    _tTntDrop
  ],
  [
    _tStoneShield,
    _tDouble,
    _tFortress,
    _tCorridor,
    _tSeesaw,
    _tBunker,
    _tTntChain,
    _tTntDrop
  ],
  [
    _tPyramid,
    _tCorridor,
    _tSeesaw,
    _tBunker,
    _tSplitBridge,
    _tArch,
    _tTntShield,
    _tTntTwin,
    _tTntDrop
  ],
  [
    _tDouble,
    _tFortress,
    _tBunker,
    _tSplitBridge,
    _tArch,
    _tScatter,
    _tTntChain,
    _tTntDrop
  ],
  [
    _tTwin,
    _tCorridor,
    _tSplitBridge,
    _tArch,
    _tScatter,
    _tTower,
    _tTntShield,
    _tTntTwin,
    _tTntDrop
  ],
  [
    _tStoneShield,
    _tDome,
    _tSeesaw,
    _tArch,
    _tScatter,
    _tPyramid,
    _tTnt,
    _tTntChain,
    _tTntShield,
    _tTntTwin,
    _tTntDrop
  ],
];

const List<String> _chapterNames = [
  'Backyard Basics',
  'Workshop',
  'Rooftops',
  'Construction',
  'Playground',
  'Barn',
  'Harbor',
  'Mountains',
  'Desert',
  'Summit',
];

/// Spare balls beyond the solution shot count, per chapter (0-based).
const List<int> _chapterSlack = [2, 2, 1, 1, 1, 1, 1, 0, 0, 0];

// ---------------------------------------------------------------------------
// Validation: simulate the solution shots in the real physics world.
// ---------------------------------------------------------------------------

bool _validate(LevelDef level, List<ShotPlan> shots) {
  final w = SmashWorld(level);
  final from = Vector2(_slingX, _slingY);
  for (final s in shots) {
    if (w.phase == GamePhase.won) return true;
    if (w.ballsLeft <= 0) return false;
    final vel = solveShot(from, s.target, s.speed, highArc: s.highArc);
    if (vel == null) return false;
    w.launchBall(vel);
    var n = 0;
    while (w.phase == GamePhase.flying && n < 900) {
      w.step(1 / 60);
      n++;
    }
    if (w.phase == GamePhase.won) return true;
  }
  return w.phase == GamePhase.won;
}

void main() {
  final rng = Random(20261026);
  final levels = <Map<String, dynamic>>[];
  var attempts = 0;
  var failures = 0;
  var id = 1;

  while (levels.length < _targetLevels && attempts < _maxAttempts) {
    attempts++;
    final chapter = (levels.length ~/ _levelsPerChapter).clamp(0, 9);
    final pool = _chapterTemplates[chapter];
    final builder = pool[rng.nextInt(pool.length)];
    final built = builder(rng, id);
    if (_validate(built.level, built.shots)) {
      final slack = _chapterSlack[chapter];
      final json = built.level.toJson();
      json['id'] = id;
      json['chapter'] = chapter + 1;
      json['chapterName'] = _chapterNames[chapter];
      json['balls'] = built.shots.length + slack;
      json['par'] = built.shots.length;
      levels.add(json);
      id++;
    } else {
      failures++;
    }
  }

  if (levels.length < _targetLevels) {
    stderr.writeln(
        'FAILED: only ${levels.length}/$_targetLevels levels validated '
        'after $attempts attempts ($failures failures).');
    exit(1);
  }

  final out = File('assets/levels/levels.json');
  out.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  out.writeAsStringSync(encoder.convert({'levels': levels}));
  // ignore: avoid_print — CLI tool output, not app code.
  print('Wrote ${levels.length} validated levels to ${out.path} '
      '($attempts attempts, $failures rejected).');
}
