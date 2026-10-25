// Home screen: Play, My Pets, and coins.
import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../art/sprites.dart';
import '../core/level_model.dart';
import '../meta/progress.dart';
import 'level_map_screen.dart';
import 'pets_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<LevelDef> levels;
  final ProgressState progress;
  final AdService ads;

  const HomeScreen({
    super.key,
    required this.levels,
    required this.progress,
    required this.ads,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Painted-button rects in bg_home.jpg fractional coordinates (960x1920),
  // measured from the art. Tap zones are mapped through the BoxFit.cover
  // transform so they stay exactly on the buttons on every screen ratio.
  static const _playRect = Rect.fromLTRB(0.050, 0.896, 0.479, 0.981);
  static const _petsRect = Rect.fromLTRB(0.494, 0.896, 0.950, 0.980);
  // bg_home.jpg aspect ratio.
  static const _artAspect = 960 / 1920;

  /// Maps an art-fraction rect to screen pixels under BoxFit.cover.
  static Rect _coverMap(Rect art, double w, double h) {
    final s = w / h;
    double x0 = 0, x1 = 1, y0 = 0, y1 = 1;
    if (s <= _artAspect) {
      // Taller screen than the art: scale by height, crop left/right.
      final cut = (1 - s / _artAspect) / 2;
      x0 = cut;
      x1 = 1 - cut;
    } else {
      // Wider screen than the art: scale by width, crop top/bottom.
      final cut = (1 - _artAspect / s) / 2;
      y0 = cut;
      y1 = 1 - cut;
    }
    return Rect.fromLTRB(
      (art.left - x0) / (x1 - x0) * w,
      (art.top - y0) / (y1 - y0) * h,
      (art.right - x0) / (x1 - x0) * w,
      (art.bottom - y0) / (y1 - y0) * h,
    );
  }

  @override
  void initState() {
    super.initState();
    SpriteCache.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextLevel = widget.progress.maxUnlocked.clamp(1, widget.levels.length);
    final chapter = (nextLevel - 1) ~/ 100;
    return Scaffold(
      body: Container(
        // Warm golden backdrop; blends with the concept art's edges.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9A825), Color(0xFFEF6C00)],
          ),
        ),
        // Full-bleed art: cover-fit fills every screen ratio (no orange
        // bands on tall phones). Tap zones are mapped through the same
        // cover transform, so they track the painted buttons exactly.
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // The finalized concept art, edge-to-edge.
                  _ConceptArt(),
                  // Invisible tap zone over the painted PLAY button.
                  _TapZone(
                    rect: _coverMap(_playRect, w, h),
                    onTap: () => _openMap(context, chapter),
                  ),
                  // Invisible tap zone over the painted MY PETS button.
                  _TapZone(
                    rect: _coverMap(_petsRect, w, h),
                    onTap: () => _openPets(context),
                  ),
                  // Next-level pill, top-left (compact — never covers the title).
                  Positioned(
                    top: 8,
                    left: 10,
                    child: _levelPill(nextLevel),
                  ),
                  // Coin chip, top-right (compact — never covers the title).
                  Positioned(
                    top: 8,
                    right: 10,
                    child: _coinChip(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context, int chapter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LevelMapScreen(
          levels: widget.levels,
          progress: widget.progress,
          ads: widget.ads,
          startChapter: chapter,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openPets(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetsScreen(progress: widget.progress),
      ),
    );
    setState(() {});
  }

  Widget _levelPill(int nextLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Level $nextLevel',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6D3A00))),
        ],
      ),
    );
  }

  Widget _coinChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _coinIcon(20),
          const SizedBox(width: 4),
          Text('${widget.progress.coins}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  /// Gold coin: AI sprite when loaded, procedural 3D-shaded coin otherwise —
  /// the icon is never blank on any device.
  Widget _coinIcon(double size) {
    final img = SpriteCache.instance.get('coin_3d');
    if (img != null) {
      return SizedBox(
        width: size,
        height: size,
        child: RawImage(image: img, fit: BoxFit.contain),
      );
    }
    return CustomPaint(
      size: Size(size, size),
      painter: _ProceduralCoinPainter(),
    );
  }
}

/// Shows a decoded 3D sprite (via SpriteCache), blank until loaded.
/// Full-screen 3D background image from the sprite cache (cover-fit),
/// with [child] overlaid. Falls back to a sky gradient while loading.
/// The finalized home concept art, drawn edge-to-edge in its box.
class _ConceptArt extends StatelessWidget {
  const _ConceptArt();

  @override
  Widget build(BuildContext context) {
    final img = SpriteCache.instance.get('bg_home');
    if (img == null) {
      return Container(color: const Color(0xFFF9A825));
    }
    // Cover-fit: fills every screen ratio, no letterbox bands.
    return RawImage(image: img, fit: BoxFit.cover);
  }
}

/// Invisible tap target over a painted button in the concept art.
/// [rect] is in screen pixels (already mapped through the cover transform).
class _TapZone extends StatelessWidget {
  final Rect rect;
  final VoidCallback onTap;
  const _TapZone({
    required this.rect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Procedural 3D-shaded gold coin — fallback when the AI coin sprite has not
/// loaded yet, so the coin icon is never blank on any device.
class _ProceduralCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    // Gold disc with radial 3D shading (light from top-left).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFC107),
            Color(0xFFE65100),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Dark rim for depth.
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xFFBF360C),
    );
    // Inner engraved ring.
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..color = const Color(0xFFFFF3C4),
    );
    // Glossy highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.28, -r * 0.34),
        width: r * 0.62,
        height: r * 0.38,
      ),
      Paint()..color = const Color(0xB3FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
