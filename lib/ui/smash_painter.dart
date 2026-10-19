// 3D-style rendering for Slingshot Pets: gradient sky with sun, clouds and
// mountains, textured ground, beveled wood, frosted glass, metallic cages,
// glossy balls with soft shadows, and cute fluffy pets. World coords are
// meters, y-up.
//
// Bodies prefer AI-rendered 3D sprites (SpriteCache); the procedural
// 3D-shaded drawing below is the fallback when a sprite isn't loaded.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

import '../art/sprites.dart';
import '../core/level_model.dart';
import '../core/slingshot.dart';
import '../core/smash_world.dart';
import 'particles.dart';

/// Maps world meters (y-up) to screen pixels (y-down) for a fixed view rect.
class SmashCamera {
  // World view rect (meters, y-up). The horizontal span is framed per
  // level so objects stay big and juicy on every screen.
  double vx0 = -10, vx1 = 18;
  static const double vy0 = -2.5, vy1 = 10.5;

  /// Tighten the horizontal view around [x0]..[x1] (world meters).
  void frame(double x0, double x1) {
    vx0 = x0;
    vx1 = x1;
  }

  double scale = 1;
  double ox = 0;
  double oy = 0;

  void layout(Size size) {
    final sx = size.width / (vx1 - vx0);
    final sy = size.height / (vy1 - vy0);
    scale = sx < sy ? sx : sy;
    ox = (size.width - (vx1 - vx0) * scale) / 2;
    oy = (size.height - (vy1 - vy0) * scale) / 2;
  }

  Offset worldToScreen(Vector2 w) =>
      Offset(ox + (w.x - vx0) * scale, oy + (vy1 - w.y) * scale);

  Vector2 screenToWorld(Offset s) => Vector2(
      (s.dx - ox) / scale + vx0, vy1 - (s.dy - oy) / scale);

  double s(double meters) => meters * scale;
}

/// A freed pet celebrating its rescue: hops with joy for ~1.8s.
class PetCelebration {
  final Vector2 at; // world meters (y-up)
  final String petId;
  final double startTime; // seconds on the painter clock
  PetCelebration({required this.at, required this.petId, required this.startTime});
}

class SmashPainter extends CustomPainter {
  final SmashWorld world;
  final ParticleSystem particles;
  final Slingshot sling;
  final SmashCamera camera;
  final Vector2? aimDrag; // pull vector in world meters, null when not aiming
  final Offset shake; // screen shake offset in logical px
  final SpriteCache sprites;
  final double time; // seconds, drives ambient animation
  final List<PetCelebration> celebrations;

  SmashPainter({
    required this.world,
    required this.particles,
    required this.sling,
    required this.camera,
    required this.aimDrag,
    required this.shake,
    required this.sprites,
    required this.time,
    this.celebrations = const [],
  });

  Offset _w2s(Vector2 w) => camera.worldToScreen(w);

  double _s(double meters) => camera.s(meters);

  /// Deterministic pseudo-random in [0,1) — stable across frames.
  double _hash(double x, double y, int salt) {
    final h = sin(x * 127.1 + y * 311.7 + salt * 74.7) * 43758.5453;
    return h - h.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!_drawBackgroundImage(canvas, size)) {
      // Procedural fallback when the 3D background isn't loaded.
      _drawSky(canvas, size);
      _drawMountains(canvas, size);
      _drawHills(canvas, size);
    }
    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    _drawGround(canvas);
    for (final sb in world.bodies) {
      if (sb.kind == SmashBodyKind.ball) _drawBallShadow(canvas, sb);
      _drawBody(canvas, sb);
    }
    _drawSlingshot(canvas);
    if (aimDrag != null) _drawTrajectory(canvas);
    _drawCelebrations(canvas);
    particles.paint(
      canvas,
      map: (o) => _w2s(Vector2(o.dx, o.dy)),
      scale: camera.scale,
    );
    _drawDust(canvas, size);
    _drawVignette(canvas, size);
    canvas.restore();
  }

  // ---------------- background ----------------

  /// Draws the AI-rendered 3D environment, cover-fit to the screen.
  /// Returns false when missing (caller uses the procedural fallback).
  bool _drawBackgroundImage(Canvas canvas, Size size) {
    final img = sprites.get('bg_game');
    if (img == null) return false;
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final sc = max(size.width / iw, size.height / ih);
    final w = iw * sc;
    final h = ih * sc;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
      Paint()..filterQuality = FilterQuality.high,
    );
    return true;
  }

  // ---------------- sky ----------------

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E9BE6),
              Color(0xFF7CC7F5),
              Color(0xFFD8F1FD),
            ],
            stops: [0.0, 0.55, 1.0],
          ).createShader(rect));

    // Sun with glow, top-right.
    final sun = Offset(size.width * 0.82, size.height * 0.12);
    final glowR = size.width * 0.22;
    canvas.drawCircle(
        sun,
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF9C4).withValues(alpha: 0.55),
              const Color(0xFFFFF9C4).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: sun, radius: glowR)));
    canvas.drawCircle(
        sun,
        size.width * 0.055,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFFDE7), Color(0xFFFFE082)],
          ).createShader(
              Rect.fromCircle(center: sun, radius: size.width * 0.055)));

    // Rotating god rays from the sun.
    const rayCount = 7;
    for (var i = 0; i < rayCount; i++) {
      final a = time * 0.12 + i * 2 * pi / rayCount;
      final len = size.width * (0.30 + 0.06 * sin(time * 0.7 + i * 1.7));
      final dir = Offset(cos(a), sin(a));
      // Only downward-ish rays read well against the sky.
      if (dir.dy < -0.25) continue;
      canvas.drawLine(
          sun + dir * size.width * 0.06,
          sun + dir * len,
          Paint()
            ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.16)
            ..strokeWidth = size.width * 0.035
            ..strokeCap = StrokeCap.round);
    }

    // Fluffy clouds (deterministic).
    const clouds = [
      (0.12, 0.10, 1.0),
      (0.45, 0.06, 1.35),
      (0.70, 0.16, 0.85),
      (0.28, 0.24, 0.7),
    ];
    for (final (fx, fy, sc) in clouds) {
      _drawCloud(canvas, Offset(size.width * fx, size.height * fy),
          size.width * 0.055 * sc);
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double r) {
    // Soft blue shade underneath, white puffs on top.
    final shade = Paint()..color = const Color(0xFFBFDDF7);
    final white = Paint()..color = Colors.white;
    for (final (dx, dy, s) in [
      (-1.6, 0.25, 0.75),
      (-0.7, 0.05, 1.0),
      (0.3, -0.05, 1.15),
      (1.3, 0.2, 0.8),
      (0.1, 0.35, 1.2),
    ]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r + r * 0.28), s * r, shade);
    }
    for (final (dx, dy, s) in [
      (-1.6, 0.1, 0.75),
      (-0.7, -0.1, 1.0),
      (0.3, -0.2, 1.15),
      (1.3, 0.05, 0.8),
      (0.1, 0.2, 1.2),
    ]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), s * r, white);
    }
  }

  void _drawMountains(Canvas canvas, Size size) {
    final base = size.height * 0.66;
    // Far range.
    final far = Path()
      ..moveTo(0, base)
      ..lineTo(size.width * 0.12, base - size.height * 0.16)
      ..lineTo(size.width * 0.24, base - size.height * 0.07)
      ..lineTo(size.width * 0.38, base - size.height * 0.19)
      ..lineTo(size.width * 0.52, base - size.height * 0.06)
      ..lineTo(size.width * 0.66, base - size.height * 0.15)
      ..lineTo(size.width * 0.80, base - size.height * 0.05)
      ..lineTo(size.width * 0.93, base - size.height * 0.12)
      ..lineTo(size.width, base - size.height * 0.04)
      ..lineTo(size.width, base)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFFA9C6E8));
    // Near range with snow caps.
    final near = Path()
      ..moveTo(0, base)
      ..lineTo(size.width * 0.18, base - size.height * 0.11)
      ..lineTo(size.width * 0.35, base - size.height * 0.03)
      ..lineTo(size.width * 0.55, base - size.height * 0.13)
      ..lineTo(size.width * 0.75, base - size.height * 0.04)
      ..lineTo(size.width * 0.90, base - size.height * 0.09)
      ..lineTo(size.width, base - size.height * 0.02)
      ..lineTo(size.width, base)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF7FA8D6));
    // Snow caps on the two tallest near peaks.
    for (final (fx, ph) in [(0.18, 0.11), (0.55, 0.13)]) {
      final px = size.width * fx;
      final py = base - size.height * ph;
      final cap = Path()
        ..moveTo(px - size.width * 0.035, py + size.height * 0.028)
        ..lineTo(px, py)
        ..lineTo(px + size.width * 0.035, py + size.height * 0.028)
        ..lineTo(px + size.width * 0.015, py + size.height * 0.018)
        ..lineTo(px, py + size.height * 0.030)
        ..lineTo(px - size.width * 0.015, py + size.height * 0.018)
        ..close();
      canvas.drawPath(cap, Paint()..color = Colors.white);
    }
  }

  void _drawHills(Canvas canvas, Size size) {
    Paint hillPaint(Color c) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c, c.withValues(alpha: 0.75)],
      ).createShader(Rect.fromLTWH(
          0, size.height * 0.5, size.width, size.height * 0.5));
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 1.28),
        size.width * 0.48,
        hillPaint(const Color(0xFF9AD184)));
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 1.32),
        size.width * 0.52,
        hillPaint(const Color(0xFF86C46F)));
  }

  // ---------------- ground ----------------

  void _drawGround(Canvas canvas) {
    final topLeft = _w2s(Vector2(camera.vx0, 0));
    final w = _s(camera.vx1 - camera.vx0);
    final grassH = _s(0.55);
    final dirtH = _s(SmashCamera.vy0.abs()) + _s(2.5);

    // Dirt with vertical gradient + speckles.
    final dirtRect =
        Rect.fromLTWH(topLeft.dx, topLeft.dy + grassH, w, dirtH);
    canvas.drawRect(
        dirtRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA5714D), Color(0xFF6E4A2F)],
          ).createShader(dirtRect));
    final speckDark = Paint()..color = Colors.black.withValues(alpha: 0.12);
    final speckLight =
        Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 46; i++) {
      final x = topLeft.dx + _hash(i.toDouble(), 1, 7) * w;
      final y = topLeft.dy + grassH + _hash(i.toDouble(), 2, 7) * dirtH;
      final r = 2 + _hash(i.toDouble(), 3, 7) * 4;
      canvas.drawCircle(Offset(x, y), r, i.isEven ? speckDark : speckLight);
    }

    // Grass with gradient + bright top edge + tufts.
    final grassRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, w, grassH);
    canvas.drawRect(
        grassRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9BDE82), Color(0xFF57A047)],
          ).createShader(grassRect));
    canvas.drawRect(
        Rect.fromLTWH(topLeft.dx, topLeft.dy, w, _s(0.07)),
        Paint()..color = const Color(0xFFC9F2B4).withValues(alpha: 0.8));
    // Grass tufts (deterministic).
    final tuft = Paint()
      ..color = const Color(0xFF4C9340)
      ..strokeWidth = max(_s(0.03), 2)
      ..strokeCap = StrokeCap.round;
    final n = (w / _s(0.7)).floor();
    for (var i = 0; i < n; i++) {
      final bx = topLeft.dx + (i + _hash(i.toDouble(), 0, 3) * 0.8) * _s(0.7);
      final by = topLeft.dy + _s(0.06);
      final h = _s(0.14 + _hash(i.toDouble(), 0, 5) * 0.12);
      for (final lean in [-0.35, 0.0, 0.35]) {
        canvas.drawLine(Offset(bx, by),
            Offset(bx + lean * h, by - h), tuft);
      }
    }
    // Tiny wildflowers.
    const petalCols = [
      Color(0xFFFF8A80),
      Color(0xFFFFD54F),
      Color(0xFFCE93D8),
      Color(0xFFFFFFFF),
    ];
    final nf = (w / _s(2.2)).floor();
    for (var i = 0; i < nf; i++) {
      final fx = topLeft.dx + (i + _hash(i.toDouble(), 4, 11) * 0.9) * _s(2.2);
      final fy = topLeft.dy + _s(0.10 + _hash(i.toDouble(), 5, 13) * 0.12);
      final sway = sin(time * 1.8 + i * 2.1) * _s(0.03);
      final stemH = _s(0.22);
      canvas.drawLine(Offset(fx, fy), Offset(fx + sway, fy - stemH),
          Paint()..color = const Color(0xFF388E3C)..strokeWidth = max(_s(0.025), 1.5));
      canvas.drawCircle(Offset(fx + sway, fy - stemH), max(_s(0.06), 3),
          Paint()..color = petalCols[i % petalCols.length]);
      canvas.drawCircle(Offset(fx + sway, fy - stemH), max(_s(0.025), 1.5),
          Paint()..color = const Color(0xFFFFEB3B));
    }
  }

  // ---------------- bodies ----------------

  /// Draws a sprite fitted to [dst]. Returns false when the sprite is missing
  /// (caller falls back to procedural drawing).
  bool _drawSprite(Canvas canvas, String name, Rect dst) {
    final img = sprites.get(name);
    if (img == null) return false;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    return true;
  }

  /// Wood sprite, rotated 90° for vertical posts so the grain runs along
  /// the beam. Returns false when the sprite is missing.
  bool _drawWoodSprite(Canvas canvas, Rect rect) {
    if (sprites.get('wood') == null) return false;
    if (rect.height > rect.width * 1.2) {
      canvas.save();
      canvas.rotate(pi / 2);
      final r = Rect.fromCenter(
          center: Offset.zero, width: rect.height, height: rect.width);
      final ok = _drawSprite(canvas, 'wood', r);
      canvas.restore();
      return ok;
    }
    return _drawSprite(canvas, 'wood', rect);
  }

  void _drawBody(Canvas canvas, SmashBody sb) {
    final c = _w2s(sb.body.position);
    final w = _s(sb.w);
    final h = _s(sb.h);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-sb.body.angle); // screen y-flip negates rotation
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    switch (sb.kind) {
      case SmashBodyKind.wood:
        if (!_drawWoodSprite(canvas, rect)) _drawWood(canvas, rect, sb);
      case SmashBodyKind.glass:
        if (!_drawSprite(canvas, 'glass', rect)) _drawGlass(canvas, rect);
      case SmashBodyKind.stone:
        if (!_drawSprite(canvas, 'stone', rect)) _drawStone(canvas, rect, sb);
      case SmashBodyKind.cage:
        _drawCage(canvas, rect, sb.petId ?? '?');
      case SmashBodyKind.ball:
        final br = Rect.fromCenter(
            center: Offset.zero, width: w * 1.18, height: h * 1.18);
        if (!_drawSprite(canvas, 'ball', br)) _drawBall(canvas, w / 2);
      case SmashBodyKind.ground:
        break; // drawn as the ground strip
    }
    canvas.restore();
  }

  void _drawWood(Canvas canvas, Rect r, SmashBody sb) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.12));
    // Beveled plank: light top -> rich mid -> dark bottom.
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFFD29A63),
              Color(0xFFA9744F),
              Color(0xFF6E4527),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(r));
    // Edge + top highlight for bevel.
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(r.height * 0.07, 2.5)
          ..color = const Color(0xFF5A3A22));
    canvas.drawLine(
        Offset(r.left + r.height * 0.15, r.top + r.height * 0.10),
        Offset(r.right - r.height * 0.15, r.top + r.height * 0.10),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = max(r.height * 0.08, 2)
          ..strokeCap = StrokeCap.round);
    // Wavy grain (deterministic per body).
    final seed = sb.body.position.x + sb.body.position.y;
    final grain = Paint()
      ..color = const Color(0xFF7A4E2D).withValues(alpha: 0.55)
      ..strokeWidth = max(r.height * 0.045, 1.5)
      ..style = PaintingStyle.stroke;
    final lines = (r.height / _s(0.28)).clamp(1, 4).toInt();
    for (var i = 0; i < lines; i++) {
      final y = r.top + r.height * (i + 1) / (lines + 1);
      final wob = r.height * 0.08;
      final p = Path()
        ..moveTo(r.left + 3, y)
        ..cubicTo(r.left + r.width * 0.3, y - wob * _hash(seed, i.toDouble(), 1),
            r.left + r.width * 0.6, y + wob * _hash(seed, i.toDouble(), 2),
            r.right - 3, y);
      canvas.drawPath(p, grain);
    }
    // Knot.
    final kx = r.left + r.width * (0.3 + 0.4 * _hash(seed, 9, 4));
    final ky = r.top + r.height * (0.3 + 0.4 * _hash(seed, 9, 5));
    canvas.drawCircle(
        Offset(kx, ky),
        max(r.height * 0.09, 2.5),
        Paint()..color = const Color(0xFF5A3A22).withValues(alpha: 0.7));
  }

  void _drawGlass(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.10));
    // Frosted pane.
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE8F7FF).withValues(alpha: 0.75),
              const Color(0xFFBFE8FF).withValues(alpha: 0.45),
              const Color(0xFF9FD4F5).withValues(alpha: 0.60),
            ],
          ).createShader(r));
    // Border + inner bottom shade for thickness.
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(r.height * 0.07, 2.5)
          ..color = const Color(0xFF7FC4E8));
    canvas.drawLine(
        Offset(r.left + 4, r.bottom - r.height * 0.12),
        Offset(r.right - 4, r.bottom - r.height * 0.12),
        Paint()
          ..color = const Color(0xFF5FA8D0).withValues(alpha: 0.5)
          ..strokeWidth = max(r.height * 0.08, 2));
    // Big diagonal shine + sparkle.
    canvas.drawLine(
        Offset(r.left + r.width * 0.22, r.bottom - r.height * 0.15),
        Offset(r.left + r.width * 0.48, r.top + r.height * 0.15),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = max(r.width * 0.10, 4)
          ..strokeCap = StrokeCap.round);
    final sp = Offset(
        r.left + r.width * (0.62 + 0.1 * (r.width % 3) / 3),
        r.top + r.height * 0.3);
    for (final (dy, len) in [(-1.0, 1.0), (1.0, 0.7)]) {
      canvas.drawLine(
          sp + Offset(0, dy * len * r.height * 0.12),
          sp - Offset(0, dy * len * r.height * 0.12),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..strokeWidth = max(r.height * 0.05, 2)
            ..strokeCap = StrokeCap.round);
    }
  }

  void _drawStone(Canvas canvas, Rect r, SmashBody sb) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.14));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFFC6CBD3),
              Color(0xFF9AA0A6),
              Color(0xFF6B7076),
            ],
            stops: [0.0, 0.6, 1.0],
          ).createShader(r));
    // Bevel: light top-left, dark bottom-right.
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(r.height * 0.07, 2.5)
          ..color = const Color(0xFF5F656D));
    canvas.drawLine(
        Offset(r.left + r.height * 0.14, r.top + r.height * 0.10),
        Offset(r.right - r.height * 0.14, r.top + r.height * 0.10),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = max(r.height * 0.07, 2)
          ..strokeCap = StrokeCap.round);
    // Speckles + a crack (deterministic).
    final seed = sb.body.position.x - sb.body.position.y;
    for (var i = 0; i < 8; i++) {
      canvas.drawCircle(
          Offset(r.left + _hash(seed, i.toDouble(), 11) * r.width,
              r.top + _hash(seed, i.toDouble(), 12) * r.height),
          max(r.height * 0.035, 1.5),
          Paint()
            ..color = (i.isEven ? Colors.black : Colors.white)
                .withValues(alpha: 0.14));
    }
    final crack = Path()
      ..moveTo(r.left + r.width * (0.3 + 0.2 * _hash(seed, 1, 13)),
          r.top + r.height * 0.1)
      ..lineTo(r.left + r.width * (0.45 + 0.2 * _hash(seed, 2, 13)),
          r.top + r.height * 0.5)
      ..lineTo(r.left + r.width * (0.35 + 0.2 * _hash(seed, 3, 13)),
          r.top + r.height * 0.9);
    canvas.drawPath(
        crack,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..strokeWidth = max(r.height * 0.04, 1.5)
          ..style = PaintingStyle.stroke);
  }

  static const _petSprites = [
    'pet_puppy',
    'pet_kitten',
    'pet_ginger',
    'pet_bunny',
  ];

  /// Sprite name for a pet id (shared with the celebration renderer).
  static String petSpriteFor(String petId) =>
      _petSprites[petId.hashCode.abs() % _petSprites.length];

  /// Freed pets hop with joy + floating hearts for ~1.8s after rescue.
  void _drawCelebrations(Canvas canvas) {
    const duration = 1.8;
    for (final c in celebrations) {
      final t = time - c.startTime;
      if (t < 0 || t > duration) continue;
      final fade = t > duration - 0.4 ? (duration - t) / 0.4 : 1.0;
      final pop = t < 0.22 ? 0.4 + 0.6 * (t / 0.22) : 1.0;
      final hopAmp = t < 1.2 ? 1.0 : 0.25; // big hops, then settles
      final hop = sin(t * 9.0).abs() * _s(0.38) * hopAmp;
      final wiggle = sin(t * 11.0) * 0.14;
      final center = _w2s(c.at) + Offset(0, -hop - _s(0.35));
      final size = _s(1.35) * pop;
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, fade);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(wiggle);
      final img = sprites.get(petSpriteFor(c.petId));
      if (img != null) {
        final w = size;
        final h = w * img.height / img.width;
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          paint,
        );
      } else {
        _drawPet(canvas, Offset.zero, size * 0.30, c.petId);
      }
      canvas.restore();
      // Floating hearts around the happy pet.
      for (var i = 0; i < 3; i++) {
        final ht = (t * 0.9 + i * 0.33) % 1.0;
        final hx = center.dx + sin(i * 2.4 + t * 3.0) * _s(0.55);
        final hy = center.dy - _s(0.4) - ht * _s(1.1);
        final hs = _s(0.16 + 0.08 * sin(i * 1.7)) * (1.0 - ht * 0.4);
        _drawHeart(canvas, Offset(hx, hy), hs,
            Color.fromRGBO(255, 105, 135, fade * (1.0 - ht * 0.5)));
      }
    }
  }

  /// Small procedural heart (no emoji — all-3D rule).
  void _drawHeart(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(c.dx - s * 1.4, c.dy - s * 0.1, c.dx - s * 0.7, c.dy - s * 1.1,
          c.dx, c.dy - s * 0.35)
      ..cubicTo(c.dx + s * 0.7, c.dy - s * 1.1, c.dx + s * 1.4, c.dy - s * 0.1,
          c.dx, c.dy + s * 0.9)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    // Glossy highlight.
    canvas.drawCircle(
        c + Offset(-s * 0.35, -s * 0.35),
        s * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.55 * color.a));
  }

  void _drawCage(Canvas canvas, Rect r, String petId) {
    final petName = petSpriteFor(petId);
    if (sprites.get('cage') != null) {
      // 3D pet behind the bars.
      final petImg = sprites.get(petName);
      if (petImg != null) {
        final pw = r.width * 0.72;
        final ph = pw * petImg.height / petImg.width;
        _drawSprite(
            canvas,
            petName,
            Rect.fromCenter(
                center: r.center + Offset(0, r.height * 0.10),
                width: pw,
                height: ph));
      } else {
        _drawPet(canvas, r.center, r.width * 0.30, petId);
      }
      // 3D cage, slightly oversized so the dome and tray show.
      _drawSprite(
          canvas,
          'cage',
          Rect.fromCenter(
              center: r.center + Offset(0, -r.height * 0.12),
              width: r.width * 1.28,
              height: r.height * 1.58));
      return;
    }
    // ---- procedural fallback ----
    // Pet behind the bars.
    _drawPet(canvas, r.center, r.width * 0.30, petId);
    // Metallic gold bars: cylindrical shading across each bar.
    final bw = max(r.width * 0.075, 5.0);
    for (var i = 0; i <= 4; i++) {
      final x = r.left + r.width * i / 4;
      final barRect = Rect.fromLTWH(x - bw / 2, r.top, bw, r.height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, Radius.circular(bw / 2)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFF8A5A00),
                Color(0xFFFFE082),
                Color(0xFFE0A800),
                Color(0xFF9A6600),
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ).createShader(barRect));
    }
    // Rounded frame with vertical metal gradient.
    final fw = max(r.width * 0.10, 6.0);
    final frameRect = r.inflate(fw * 0.28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(frameRect, Radius.circular(r.width * 0.16)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fw
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE082),
              Color(0xFFE0A800),
              Color(0xFF9A6600),
            ],
          ).createShader(frameRect));
    // Rivets at the corners.
    final rivetR = max(fw * 0.22, 2.5);
    for (final p in [
      frameRect.topLeft + Offset(fw * 0.5, fw * 0.5),
      frameRect.topRight + Offset(-fw * 0.5, fw * 0.5),
      frameRect.bottomLeft + Offset(fw * 0.5, -fw * 0.5),
      frameRect.bottomRight + Offset(-fw * 0.5, -fw * 0.5),
    ]) {
      canvas.drawCircle(
          p,
          rivetR,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xFFFFF8DC), Color(0xFFB47A00)],
            ).createShader(Rect.fromCircle(center: p, radius: rivetR)));
    }
  }

  /// Cute kawaii pet: 0 golden puppy, 1 grey kitten, 2 ginger kitten, 3 bunny.
  void _drawPet(Canvas canvas, Offset c, double rad, String petId) {
    final v = petId.hashCode.abs() % 4;
    final fur = [
      const Color(0xFFF2C078),
      const Color(0xFFC3CED6),
      const Color(0xFFF5A65B),
      const Color(0xFFF7EDE2),
    ][v];
    final furDark = [
      const Color(0xFFE0A75E),
      const Color(0xFF9AA7B2),
      const Color(0xFFDE8340),
      const Color(0xFFE3CFAF),
    ][v];
    final pink = const Color(0xFFF5A3B5);

    // Ears behind the head.
    if (v == 0) {
      // Floppy puppy ears.
      for (final sgn in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(c.dx + sgn * rad * 0.85, c.dy - rad * 0.55);
        canvas.rotate(sgn * 0.5);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero,
                width: rad * 0.55,
                height: rad * 1.0),
            Paint()..color = furDark);
        canvas.restore();
      }
    } else if (v == 3) {
      // Bunny: tall ears.
      for (final sgn in [-1.0, 1.0]) {
        final base = c + Offset(sgn * rad * 0.35, -rad * 0.85);
        canvas.drawOval(
            Rect.fromCenter(
                center: base + Offset(0, -rad * 0.45),
                width: rad * 0.42,
                height: rad * 1.15),
            Paint()..color = fur);
        canvas.drawOval(
            Rect.fromCenter(
                center: base + Offset(0, -rad * 0.42),
                width: rad * 0.2,
                height: rad * 0.75),
            Paint()..color = pink.withValues(alpha: 0.8));
      }
    } else {
      // Pointy kitten ears with pink inner.
      for (final sgn in [-1.0, 1.0]) {
        final p = Path()
          ..moveTo(c.dx + sgn * rad * 0.95, c.dy - rad * 0.35)
          ..lineTo(c.dx + sgn * rad * 0.55, c.dy - rad * 1.15)
          ..lineTo(c.dx + sgn * rad * 0.15, c.dy - rad * 0.55)
          ..close();
        canvas.drawPath(p, Paint()..color = fur);
        final inner = Path()
          ..moveTo(c.dx + sgn * rad * 0.78, c.dy - rad * 0.45)
          ..lineTo(c.dx + sgn * rad * 0.55, c.dy - rad * 0.92)
          ..lineTo(c.dx + sgn * rad * 0.32, c.dy - rad * 0.55)
          ..close();
        canvas.drawPath(inner, Paint()..color = pink);
      }
    }

    // Head with soft radial shading.
    canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            radius: 0.95,
            colors: [Colors.white.withValues(alpha: 0.55), fur, furDark],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: rad)));

    // Muzzle.
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(0, rad * 0.30),
            width: rad * 1.05,
            height: rad * 0.62),
        Paint()..color = Colors.white.withValues(alpha: 0.65));

    // Eyes: white + pupil + catchlight.
    for (final sgn in [-1.0, 1.0]) {
      final e = c + Offset(sgn * rad * 0.34, -rad * 0.08);
      canvas.drawCircle(e, rad * 0.21, Paint()..color = Colors.white);
      canvas.drawCircle(e + Offset(sgn * rad * 0.03, rad * 0.03),
          rad * 0.115, Paint()..color = const Color(0xFF2B2B2B));
      canvas.drawCircle(e + Offset(-rad * 0.05, -rad * 0.06), rad * 0.045,
          Paint()..color = Colors.white);
    }
    // Blush.
    for (final sgn in [-1.0, 1.0]) {
      canvas.drawCircle(
          c + Offset(sgn * rad * 0.58, rad * 0.28),
          rad * 0.13,
          Paint()..color = const Color(0xFFF49AC1).withValues(alpha: 0.55));
    }
    // Nose + mouth.
    final nose = c + Offset(0, rad * 0.22);
    canvas.drawOval(
        Rect.fromCenter(
            center: nose, width: rad * 0.30, height: rad * 0.20),
        Paint()..color = const Color(0xFF5D4037));
    canvas.drawCircle(nose + Offset(-rad * 0.05, -rad * 0.03), rad * 0.045,
        Paint()..color = Colors.white.withValues(alpha: 0.7));
    final mouth = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = max(rad * 0.045, 1.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: nose + Offset(-rad * 0.11, rad * 0.10), radius: rad * 0.11),
        0.3,
        2.2,
        false,
        mouth);
    canvas.drawArc(
        Rect.fromCircle(center: nose + Offset(rad * 0.11, rad * 0.10), radius: rad * 0.11),
        0.6,
        2.2,
        false,
        mouth);
  }

  void _drawBallShadow(Canvas canvas, SmashBody sb) {
    final pos = sb.body.position;
    final h = pos.y.clamp(0.0, 8.0);
    final t = 1 - h / 8; // 1 on the ground, 0 high up
    if (t <= 0.02) return;
    final w = _s(0.62 * (0.35 + 0.65 * t));
    final c = _w2s(Vector2(pos.x, 0.03));
    canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: w * 0.26),
        Paint()..color = Colors.black.withValues(alpha: 0.20 * t));
  }

  void _drawBall(Canvas canvas, double rad) {
    // Glossy sphere.
    canvas.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.38),
            radius: 0.95,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFF8A80),
              Color(0xFFE53935),
              Color(0xFF9E1B1B),
            ],
            stops: [0.0, 0.28, 0.62, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: rad)));
    // Specular dot + rim light.
    canvas.drawCircle(Offset(-rad * 0.34, -rad * 0.38), rad * 0.17,
        Paint()..color = Colors.white.withValues(alpha: 0.95));
    canvas.drawCircle(Offset(-rad * 0.12, -rad * 0.52), rad * 0.06,
        Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: rad * 0.86),
        0.5,
        1.4,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..strokeWidth = rad * 0.14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  void _drawSlingshot(Canvas canvas) {
    final a = _w2s(sling.anchor);
    final sw = _s(0.30);
    // Fork tip positions (band anchors while aiming).
    late Offset tipL, tipR;

    final forkImg = sprites.get('slingshot');
    if (forkImg != null) {
      // 3D fork sprite; branch junction sits ~59% down the image.
      final w = _s(2.1);
      final h = w * forkImg.height / forkImg.width;
      final dst = Rect.fromLTWH(a.dx - w / 2, a.dy - h * 0.59, w, h);
      _drawSprite(canvas, 'slingshot', dst);
      tipL = Offset(dst.left + w * 0.28, dst.top + h * 0.16);
      tipR = Offset(dst.left + w * 0.72, dst.top + h * 0.16);
    } else {
      // ---- procedural fallback fork ----
      final base = a + Offset(0, _s(0.95));
      tipL = a + Offset(-_s(0.42), -_s(0.48));
      tipR = a + Offset(_s(0.42), -_s(0.48));

          void limb(Offset p1, Offset p2) {
            // Beveled wood: dark edge, warm core, top highlight.
            for (final (wdt, col) in [
              (sw * 1.0, const Color(0xFF5A3A22)),
              (sw * 0.72, const Color(0xFF8D5A2B)),
            ]) {
              canvas.drawLine(
                  p1,
                  p2,
                  Paint()
                    ..color = col
                    ..strokeWidth = wdt
                    ..strokeCap = StrokeCap.round);
            }
            canvas.drawLine(
                p1 + Offset(-sw * 0.12, -sw * 0.12),
                p2 + Offset(-sw * 0.12, -sw * 0.12),
                Paint()
                  ..color = const Color(0xFFC89B6A).withValues(alpha: 0.8)
                  ..strokeWidth = sw * 0.20
                  ..strokeCap = StrokeCap.round);
          }

          limb(base, a);
          limb(a, tipL);
          limb(a, tipR);
            // Leather wraps at the tips.
            for (final tip in [tipL, tipR]) {
              canvas.drawCircle(
                  tip, sw * 0.52, Paint()..color = const Color(0xFF4E342E));
              canvas.drawCircle(tip + Offset(-sw * 0.1, -sw * 0.1), sw * 0.18,
                  Paint()..color = const Color(0xFF8D6E63));
            }
          }

    // Bands + pouch + held ball while aiming.
    if (aimDrag != null) {
      final ballPos =
          a + Offset(aimDrag!.x * camera.scale, -aimDrag!.y * camera.scale);
      final bandW = _s(0.10);
      for (final tip in [tipL, tipR]) {
        // Tapered band: quad from tip to pouch.
        final d = ballPos - tip;
        final dir = d / d.distance;
        final nrm = Offset(-dir.dy, dir.dx);
        final p = Path()
          ..moveTo(tip.dx + nrm.dx * bandW * 0.5, tip.dy + nrm.dy * bandW * 0.5)
          ..lineTo(tip.dx - nrm.dx * bandW * 0.5, tip.dy - nrm.dy * bandW * 0.5)
          ..lineTo(ballPos.dx - nrm.dx * bandW * 0.28,
              ballPos.dy - nrm.dy * bandW * 0.28)
          ..lineTo(ballPos.dx + nrm.dx * bandW * 0.28,
              ballPos.dy + nrm.dy * bandW * 0.28)
          ..close();
        canvas.drawPath(
            p,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0xFF8D5B4C), Color(0xFF4E342E)],
              ).createShader(Rect.fromPoints(tip, ballPos)));
      }
      // Leather pouch.
      final pw = _s(0.62), ph = _s(0.44);
      final pr = RRect.fromRectAndRadius(
          Rect.fromCenter(center: ballPos, width: pw, height: ph),
          Radius.circular(ph * 0.4));
      canvas.drawRRect(
          pr,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
            ).createShader(Rect.fromCenter(
                center: ballPos, width: pw, height: ph)));
      // Stitch.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: ballPos, width: pw * 0.78, height: ph * 0.62),
              Radius.circular(ph * 0.3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(_s(0.02), 1.5)
            ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.7));
      _drawBallAt(canvas, ballPos, _s(SmashWorld.ballRadius));
    }
  }

  void _drawBallAt(Canvas canvas, Offset pos, double rad) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    _drawBall(canvas, rad);
    canvas.restore();
  }

  void _drawTrajectory(Canvas canvas) {
    final vel = sling.launchVelocity(aimDrag!);
    final pts = sling.trajectory(vel, Vector2(0, -10));
    for (var i = 0; i < pts.length; i += 2) {
      final t = 1 - i / pts.length;
      final p = _w2s(pts[i]);
      final r = 5.0 * t + 2.2;
      // Soft glow + bright core.
      canvas.drawCircle(
          p, r * 1.9, Paint()..color = Colors.white.withValues(alpha: 0.22 * t));
      canvas.drawCircle(
          p, r, Paint()..color = Colors.white.withValues(alpha: 0.9 * t));
    }
  }

  void _drawDust(Canvas canvas, Size size) {
    // Golden pollen motes drifting in the light.
    final p = Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: 0.5);
    for (var i = 0; i < 22; i++) {
      final fx = _hash(i.toDouble(), 11, 13);
      final fy = _hash(i.toDouble(), 12, 17);
      final drift = sin(time * 0.6 + i * 1.3) * 0.012;
      final rise = ((time * 0.014 + fy) % 1.0);
      final x = (fx + drift) * size.width;
      final y = (1.0 - rise) * size.height * 0.75;
      final r = 1.5 + _hash(i.toDouble(), 13, 19) * 2.5;
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.75,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.10),
            ],
            stops: const [0.62, 1.0],
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant SmashPainter old) => true;
}
