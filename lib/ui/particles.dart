// Lightweight 2D particle system for impact debris, sparks and confetti.
// Pure Dart model + Canvas painting; no physics dependency.
import 'dart:math';

import 'package:flutter/material.dart';

class Particle {
  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final double gravity;
  double rotation;
  final double spin;
  final bool circle; // false = small rotated square (debris chip)

  Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.color,
    this.gravity = 900,
    this.rotation = 0,
    this.spin = 0,
    this.circle = false,
  }) : maxLife = life;

  bool get dead => life <= 0;

  void update(double dt) {
    life -= dt;
    vel = Offset(vel.dx, vel.dy + gravity * dt);
    pos = Offset(pos.dx + vel.dx * dt, pos.dy + vel.dy * dt);
    rotation += spin * dt;
  }
}

class ParticleSystem {
  final List<Particle> _parts = [];
  final Random _rng = Random();

  bool get isEmpty => _parts.isEmpty;

  /// Radial burst of debris chips.
  void burst({
    required Offset at,
    required int count,
    required List<Color> colors,
    double speedMin = 80,
    double speedMax = 320,
    double life = 0.8,
    double sizeMin = 4,
    double sizeMax = 9,
    double gravity = 900,
  }) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final sp = speedMin + _rng.nextDouble() * (speedMax - speedMin);
      _parts.add(Particle(
        pos: at,
        vel: Offset(cos(a) * sp, sin(a) * sp - 120),
        life: life * (0.6 + _rng.nextDouble() * 0.4),
        size: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
        color: colors[_rng.nextInt(colors.length)],
        gravity: gravity,
        rotation: _rng.nextDouble() * 2 * pi,
        spin: (_rng.nextDouble() - 0.5) * 12,
      ));
    }
  }

  /// Soft round confetti (pet rescue celebration).
  void confetti({required Offset at, int count = 26}) {
    burst(
      at: at,
      count: count,
      colors: const [
        Color(0xFFFFD54F),
        Color(0xFFFF8A65),
        Color(0xFF81D4FA),
        Color(0xFFA5D6A7),
        Color(0xFFCE93D8),
      ],
      speedMin: 60,
      speedMax: 260,
      life: 1.1,
      sizeMin: 4,
      sizeMax: 7,
      gravity: 500,
    );
  }

  void update(double dt) {
    for (final p in _parts) {
      p.update(dt);
    }
    _parts.removeWhere((p) => p.dead);
  }

  /// Paints particles. When [map]/[scale] are given, particle positions
  /// (stored in world meters) are mapped to screen space.
  void paint(Canvas canvas, {Offset Function(Offset p)? map, double scale = 1}) {
    for (final p in _parts) {
      final pos = map != null ? map(p.pos) : p.pos;
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: t);
      final s = p.size * scale;
      if (p.circle) {
        canvas.drawCircle(pos, s * t, paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.rotation);
        final w = s * (0.5 + 0.5 * t);
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.7),
            paint);
        canvas.restore();
      }
    }
  }

  void clear() => _parts.clear();
}
