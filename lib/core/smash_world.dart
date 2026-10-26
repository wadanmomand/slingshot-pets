// Physics core for Slingshot Pets: forge2d world, break-on-impact rules,
// cage/pet rescue, ball lifecycle, win/lose detection.
// Rendering lives in the game screen (Phase 3); this file is pure simulation.

import 'package:forge2d/forge2d.dart';

import 'level_model.dart';

/// Approach speed (m/s) at a contact point that breaks each material.
/// Infinity = unbreakable. Tuned via unit tests (see test/smash_world_test).
const Map<SmashBodyKind, double> breakSpeeds = {
  SmashBodyKind.glass: 2.0,
  SmashBodyKind.tnt: 2.0,
  SmashBodyKind.cage: 3.5,
  SmashBodyKind.wood: 5.0,
  SmashBodyKind.ground: double.infinity,
  SmashBodyKind.stone: double.infinity,
  SmashBodyKind.ball: double.infinity,
};

/// Blast radius (meters) of a TNT explosion: destroys every breakable
/// body (wood/glass/cage/TNT) whose center is within this distance.
/// Stone, ground and the ball are never destroyed by a blast.
const double tntBlastRadius = 3.5;

enum GamePhase { aiming, flying, won, lost }

/// Emitted when a body breaks; the game screen turns these into
/// particles, sounds and score popups.
class BreakEvent {
  final SmashBodyKind kind;
  final Vector2 at;
  final String? petId; // set when a cage breaks

  BreakEvent(this.kind, this.at, this.petId);
}

class SmashBody {
  final Body body;
  final SmashBodyKind kind;
  final String? petId;

  /// Full width/height in meters (for boxes); ball stores diameter.
  final double w;
  final double h;
  bool broken = false;

  /// Max contact approach speed recorded this step (reset each step).
  double peakImpact = 0;

  SmashBody(this.body, this.kind, this.petId, this.w, this.h);
}

/// Records per-body impact speeds at contact begin.
class _ImpactListener extends ContactListener {
  final void Function(SmashBody sb, double speed) onImpact;

  _ImpactListener(this.onImpact);

  @override
  void beginContact(Contact contact) {
    final a = contact.bodyA.userData;
    final b = contact.bodyB.userData;
    if (a is! SmashBody || b is! SmashBody) return;
    final wm = WorldManifold();
    contact.getWorldManifold(wm);
    final rel = contact.bodyB.linearVelocity - contact.bodyA.linearVelocity;
    final speed = rel.dot(wm.normal).abs();
    onImpact(a, speed);
    onImpact(b, speed);
  }
}

class SmashWorld {
  static const double ballRadius = 0.32;

  final World world = World(Vector2(0, -10));
  final List<SmashBody> bodies = [];
  final List<BreakEvent> _breakEvents = [];
  final Set<String> freedPets = {};

  final int totalPets;
  final int par;
  final Vector2 slingPos;

  int ballsLeft;
  int ballsUsed = 0;

  Body? _ballBody;
  double _ballAge = 0;
  double _ballQuietTime = 0;

  SmashWorld(LevelDef level)
      : totalPets = level.totalPets,
        par = level.par,
        slingPos = Vector2(level.slingX, level.slingY),
        ballsLeft = level.balls {
    world.setContactListener(_ImpactListener((sb, speed) {
      if (speed > sb.peakImpact) sb.peakImpact = speed;
    }));
    for (final p in level.bodies) {
      _addPlaced(p);
    }
  }

  void _addPlaced(PlacedBody p) {
    final type =
        p.kind == SmashBodyKind.ground ? BodyType.static : BodyType.dynamic;
    final body = world.createBody(
      BodyDef(type: type, position: Vector2(p.x, p.y), angle: p.angle),
    );
    final shape = PolygonShape()..setAsBoxXY(p.w / 2, p.h / 2);
    final (density, friction, restitution) = switch (p.kind) {
      SmashBodyKind.wood => (1.0, 0.5, 0.1),
      SmashBodyKind.glass => (0.6, 0.3, 0.1),
      SmashBodyKind.stone => (3.0, 0.6, 0.05),
      SmashBodyKind.cage => (0.8, 0.4, 0.2),
      SmashBodyKind.tnt => (0.8, 0.4, 0.1),
      SmashBodyKind.ground => (1.0, 0.8, 0.0),
      SmashBodyKind.ball => (1.2, 0.4, 0.45),
    };
    body.createFixtureFromShape(
      shape,
      density: density,
      friction: friction,
      restitution: restitution,
    );
    final sb = SmashBody(body, p.kind, p.petId, p.w, p.h);
    body.userData = sb;
    bodies.add(sb);
  }

  /// Launches a ball from the slingshot. Ignored when no balls remain
  /// or a ball is already in flight.
  void launchBall(Vector2 velocity) {
    if (ballsLeft <= 0 || _ballBody != null) return;
    ballsLeft--;
    ballsUsed++;
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: slingPos.clone(),
        angularDamping: 2.0,
        linearDamping: 0.05,
      ),
    );
    body.createFixtureFromShape(
      CircleShape(radius: ballRadius),
      density: 1.2,
      friction: 0.4,
      restitution: 0.45,
    );
    body.linearVelocity.setFrom(velocity);
    final sb = SmashBody(body, SmashBodyKind.ball, null, ballRadius * 2, ballRadius * 2);
    body.userData = sb;
    bodies.add(sb);
    _ballBody = body;
    _ballAge = 0;
    _ballQuietTime = 0;
  }

  void step(double dt) {
    for (final b in bodies) {
      b.peakImpact = 0;
    }
    world.stepDt(dt);
    _applyBreaks();
    _updateBall(dt);
  }

  void _applyBreaks() {
    final doomed = <SmashBody>[];
    void markBroken(SmashBody sb) {
      sb.broken = true;
      doomed.add(sb);
      _breakEvents.add(
        BreakEvent(sb.kind, sb.body.position.clone(), sb.petId),
      );
      if (sb.kind == SmashBodyKind.cage && sb.petId != null) {
        freedPets.add(sb.petId!);
      }
    }

    for (final sb in bodies) {
      if (sb.broken) continue;
      final threshold = breakSpeeds[sb.kind]!;
      if (sb.peakImpact > threshold) {
        markBroken(sb);
      }
    }
    // TNT chain reactions: an exploding barrel destroys every breakable
    // body within its blast radius — including other TNT, which chain.
    // Snapshot the TNT list per pass: blasting grows `doomed` while we
    // iterate, and a list must never grow during its own iteration.
    var grew = true;
    while (grew) {
      grew = false;
      final tnts =
          doomed.where((s) => s.kind == SmashBodyKind.tnt).toList();
      for (final tnt in tnts) {
        for (final sb in bodies) {
          if (sb.broken) continue;
          if (breakSpeeds[sb.kind] == double.infinity) continue;
          final d = (sb.body.position - tnt.body.position).length;
          if (d <= tntBlastRadius) {
            markBroken(sb);
            grew = true;
          }
        }
      }
    }
    for (final sb in doomed) {
      bodies.remove(sb);
      if (sb.body == _ballBody) _ballBody = null;
      world.destroyBody(sb.body);
    }
  }

  void _updateBall(double dt) {
    final ball = _ballBody;
    if (ball == null) return;
    _ballAge += dt;
    // Fell out of the world or timed out.
    if (ball.position.y < -8 || _ballAge > 10) {
      _removeBall();
      return;
    }
    // Came to rest.
    if (ball.linearVelocity.length < 0.6) {
      _ballQuietTime += dt;
    } else {
      _ballQuietTime = 0;
    }
    if (_ballQuietTime > 0.8) _removeBall();
  }

  void _removeBall() {
    final ball = _ballBody;
    _ballBody = null;
    _ballAge = 0;
    _ballQuietTime = 0;
    if (ball != null) {
      bodies.removeWhere((sb) => sb.body == ball);
      world.destroyBody(ball);
    }
  }

  /// Adds balls (e.g. rewarded continue). Resets a lost phase back to aiming.
  void addBalls(int n) {
    ballsLeft += n;
  }

  /// Drains break events since the last call (for particles/sound).
  List<BreakEvent> takeBreakEvents() {
    final out = List<BreakEvent>.from(_breakEvents);
    _breakEvents.clear();
    return out;
  }

  bool get _settled {
    for (final sb in bodies) {
      if (sb.kind == SmashBodyKind.ground || sb.kind == SmashBodyKind.ball) {
        continue;
      }
      if (sb.body.isAwake && sb.body.linearVelocity.length > 0.4) {
        return false;
      }
    }
    return true;
  }

  GamePhase get phase {
    if (totalPets > 0 && freedPets.length >= totalPets) return GamePhase.won;
    if (ballsLeft == 0 && _ballBody == null && _settled) {
      return GamePhase.lost;
    }
    if (_ballBody != null) return GamePhase.flying;
    return GamePhase.aiming;
  }

  /// Star rating for a won level based on balls used vs par.
  int starsForWin() {
    if (ballsUsed <= par) return 3;
    if (ballsUsed <= par + 2) return 2;
    return 1;
  }
}
