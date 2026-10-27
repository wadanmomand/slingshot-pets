// Level map: full-3D garden world, 3D-styled winding path with coin nodes.
// Chunky golden 3D chapter title on top (locked design language).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_service.dart';
import '../art/sprites.dart';
import '../audio/sfx.dart';
import '../core/haptics.dart';
import '../core/level_model.dart';
import '../meta/progress.dart';
import 'icon3d.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class LevelMapScreen extends StatefulWidget {
  final List<LevelDef> levels;
  final ProgressState progress;
  final AdService ads;
  final int startChapter;

  const LevelMapScreen({
    super.key,
    required this.levels,
    required this.progress,
    required this.ads,
    this.startChapter = 0,
  });

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late int _chapter;
  late final BannerAd _banner;
  final _scroll = ScrollController();
  final _sfx = Sfx();

  static const double _spacing = 132;
  static const double _nodeR = 44;

  static const List<String> _names = [
    'Backyard Basics', 'Workshop', 'Rooftops', 'Construction', 'Playground',
    'Barn', 'Harbor', 'Mountains', 'Desert', 'Summit',
  ];

  @override
  void initState() {
    super.initState();
    _chapter = widget.startChapter;
    _banner = widget.ads.makeBanner();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _banner.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double _nodeX(int i, double w) => w / 2 + (w * 0.30) * sin(i * 0.5);

  void _jumpToCurrent() {
    if (!_scroll.hasClients) return;
    // Chapter-relative index: chapter 2's level 250 is node 49, not 99 (m5).
    final idx = (widget.progress.maxUnlocked - 1 - _chapter * 100).clamp(0, 99);
    final y = idx * _spacing + _spacing / 2 - MediaQuery.of(context).size.height / 2;
    _scroll.jumpTo(y.clamp(0, _scroll.position.maxScrollExtent));
  }

  void _jumpToChapter(int c) {
    setState(() => _chapter = c);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  Widget build(BuildContext context) {
    // Honor the Settings toggles (SFX + vibration).
    _sfx.enabled = widget.progress.sfxOn;
    Haptics.enabled = widget.progress.vibration;
    final start = _chapter * 100;
    final chapterLevels = widget.levels.sublist(start, start + 100);
    final bg = SpriteCache.instance.get('bg_map');
    final fountain = SpriteCache.instance.get('fountain_3d');
    return Scaffold(
      body: Column(
        children: [
          // Fixed header: title, stats and chips no longer scroll away.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _roundBtn(
                  'btn3d_back',
                  () => Navigator.pop(context),
                ),
                Expanded(child: _BigTitle(_names[_chapter])),
                _roundBtn('btn3d_gear', () {
                  _sfx.click();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SettingsScreen(progress: widget.progress),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Cream stats bar: coins + stars (concept).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFD4A017), width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('coin_3d', '${widget.progress.coins}'),
                  _stat('star_3d', '${widget.progress.totalStars}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Chapter quick-jump chips.
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 10,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _chapter == i,
                  selectedColor: const Color(0xFFFFB300),
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  onSelected: (_) => _jumpToChapter(i),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Scrolling node list. Rows are viewport-sized (132px) so no
          // single layer is ever taller than the screen: the old
          // 13,820px canvas failed to rasterize on phones (grey map).
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return RepaintBoundary(
                  child: Stack(
                  children: [
                    // Garden background, viewport-sized.
                    Positioned.fill(
                      child: bg != null
                          ? RawImage(image: bg, fit: BoxFit.cover)
                          : Container(color: const Color(0xFF7CB342)),
                    ),
                    ListView.builder(
                      controller: _scroll,
                      itemCount: 100,
                      itemExtent: _spacing,
                      itemBuilder: (context, i) {
                        final x0 = _nodeX(i, w);
                        final x1 = i < 99 ? _nodeX(i + 1, w) : x0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Cobblestone path segment to the next node.
                            Positioned.fill(
                              child: CustomPaint(
                                painter:
                                    _PathSegmentPainter(x0: x0, x1: x1),
                              ),
                            ),
                            // Fountain decoration mid-map.
                            if (i == 40 && fountain != null)
                              Positioned(
                                top: -40,
                                right: -30,
                                child: RawImage(
                                    image: fountain, width: 220, height: 220),
                              ),
                            Positioned(
                              left: x0 - _nodeR,
                              top: _spacing / 2 - _nodeR,
                              child: _levelNode(chapterLevels[i]),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                );
              },
            ),
          ),
          SizedBox(
            height: 60,
            child: AdWidget(ad: _banner),
          ),
          // Golden PLAY LEVEL button (concept).
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: GestureDetector(
              onTap: () async {
                final idx =
                    (widget.progress.maxUnlocked - 1).clamp(0, 999);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      levels: widget.levels,
                      startIndex: idx,
                      progress: widget.progress,
                      ads: widget.ads,
                    ),
                  ),
                );
                setState(() {});
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFE082),
                      Color(0xFFFFB300),
                      Color(0xFFF57C00)
                    ],
                  ),
                  border:
                      Border.all(color: const Color(0xFFFFF8E1), width: 3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 10,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: Text(
                    'PLAY LEVEL ${widget.progress.maxUnlocked.clamp(1, 1000)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                            color: Color(0xFFB25000),
                            blurRadius: 0,
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Teal circular button (concept).
  Widget _roundBtn(String spriteKey, VoidCallback onTap) {
    return Icon3DButton(spriteKey: spriteKey, size: 52, onTap: onTap);
  }

  Widget _stat(String spriteKey, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Sprite3D(spriteKey, size: 32),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D3A00))),
      ],
    );
  }

  Widget _levelNode(LevelDef level) {
    final unlocked = widget.progress.isUnlocked(level.id);
    final stars = widget.progress.starsFor(level.id);
    final isNext = level.id == widget.progress.maxUnlocked;
    final coinImg = SpriteCache.instance.get('coin_3d');
    final lockImg = SpriteCache.instance.get('lock_3d');
    final starImg = SpriteCache.instance.get('star_3d');
    return GestureDetector(
      onTap: unlocked
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    levels: widget.levels,
                    startIndex: level.id - 1,
                    progress: widget.progress,
                    ads: widget.ads,
                  ),
                ),
              );
              setState(() {});
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D coin / stone-lock sprite with the level number.
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (unlocked && coinImg != null)
                  RawImage(image: coinImg, width: 88, height: 88)
                else if (!unlocked && lockImg != null)
                  RawImage(image: lockImg, width: 88, height: 88)
                else
                  _fallbackBadge(unlocked),
                if (unlocked)
                  Text(
                    '${level.id}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: isNext ? Colors.white : const Color(0xFF7A4A00),
                      shadows: const [
                        Shadow(
                            color: Color(0xFFB25000),
                            blurRadius: 0,
                            offset: Offset(0, 2)),
                        Shadow(
                            color: Colors.white,
                            blurRadius: 0,
                            offset: Offset(0, -1)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 3D stars overlapping the coin's bottom edge (concept).
          // Unearned stars are dimmed with Opacity, not a saturation
          // ColorFilter: the filter broke rasterization of the whole
          // scrolling list (grey map in goldens and on phones), and 33
          // saveLayers per frame also hurt weak phones.
          Transform.translate(
            offset: const Offset(0, -16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = 0; s < 3; s++)
                  if (starImg != null)
                    Opacity(
                      opacity: s < stars ? 1.0 : 0.3,
                      child:
                          RawImage(image: starImg, width: 26, height: 26),
                    )
                  else
                    const SizedBox(width: 26, height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Procedural fallback if a sprite failed to load.
  Widget _fallbackBadge(bool unlocked) {
    final lockImg = SpriteCache.instance.get('lock_3d');
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked
            ? const Color(0xFFFFB300)
            : const Color(0xFF8D8D8D).withValues(alpha: 0.6),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: unlocked
          ? null
          : lockImg != null
              ? RawImage(image: lockImg, width: 40, height: 40)
              : const SizedBox.shrink(),
    );
  }
}

/// One cobblestone path segment between two neighbouring nodes.
///
/// The old map painted a single 13,820px-tall canvas; that giant layer
/// failed to rasterize on phones (grey map). Segments are 132px rows, so
/// no layer is ever taller than the screen. The segment spans from this
/// row's node (y=66) to the next row's node (y=198, overflowing 66px into
/// the next row, whose own segment starts exactly there — no gaps).
class _PathSegmentPainter extends CustomPainter {
  final double x0;
  final double x1;

  _PathSegmentPainter({required this.x0, required this.x1});

  @override
  void paint(Canvas canvas, Size size) {
    // Smooth curve from this node down to the next node.
    final path = Path()..moveTo(x0, 66);
    path.cubicTo(x0, 132, x1, 132, x1, 198);

    // Soft drop shadow: a solid offset stroke (kept simple; the blur
    // version was removed during diagnosis and never needed back).
    canvas.save();
    canvas.translate(0, 14);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.restore();

    // Soil edge, then sand bed.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 96
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF7A5230),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 84
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC9A06B),
    );

    // Individual 3D cobblestones in staggered rows.
    final rnd = Random(21);
    const stoneTones = [
      Color(0xFFD8C0A0),
      Color(0xFFCFB28E),
      Color(0xFFE0CAA8),
      Color(0xFFC7A87F),
    ];
    for (final m in path.computeMetrics()) {
      var d = 8.0;
      var row = 0;
      while (d < m.length - 8) {
        final tan = m.getTangentForOffset(d);
        if (tan != null) {
          final nrm = Offset(-tan.vector.dy, tan.vector.dx);
          final angle = atan2(tan.vector.dy, tan.vector.dx);
          // Stagger: 3 stones, then 2 offset stones.
          final offs =
              row.isEven ? [-27.0, 0.0, 27.0] : [-13.5, 13.5];
          for (final off in offs) {
            final c = tan.position + nrm * off;
            final tone = stoneTones[
                (rnd.nextDouble() * stoneTones.length).floor()];
            canvas.save();
            canvas.translate(c.dx, c.dy);
            canvas.rotate(angle);
            // Stone shadow (bottom-right).
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: const Offset(1.5, 2), width: 25, height: 19),
                  const Radius.circular(8)),
              Paint()..color = const Color(0xFF6B4A2E),
            );
            // Stone body.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset.zero, width: 25, height: 19),
                  const Radius.circular(8)),
              Paint()..color = tone,
            );
            // Top highlight for 3D roundness.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: const Offset(-2, -4), width: 16, height: 9),
                  const Radius.circular(4.5)),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.35),
            );
            canvas.restore();
          }
        }
        d += 24;
        row++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathSegmentPainter old) =>
      old.x0 != x0 || old.x1 != x1;
}

/// Big two-line chunky title, auto-sized to fill width (concept).
class _BigTitle extends StatelessWidget {
  final String name;
  const _BigTitle(this.name);

  @override
  Widget build(BuildContext context) {
    final words =
        name.toUpperCase().split(' ').where((w) => w.isNotEmpty).toList();
    List<String> lines;
    if (words.length <= 1) {
      lines = [name.toUpperCase()];
    } else if (words.length == 2) {
      lines = words;
    } else {
      // Balance into two lines.
      final mid = (words.length / 2).ceil();
      lines = [words.sublist(0, mid).join(' '), words.sublist(mid).join(' ')];
    }
    final longest =
        lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
    final w = MediaQuery.of(context).size.width - 144;
    // Fit-to-width math; the old 48px floor overflowed narrow phones (m6),
    // and FittedBox guarantees it never bleeds past the buttons.
    final fontSize = (w / (longest * 0.72)).clamp(28.0, 88.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _ChunkyTitle(line, fontSize: fontSize),
          ),
      ],
    );
  }
}

/// Chunky golden 3D title text (design language): brown outer stroke,
/// white middle stroke, golden gradient fill, slight tilt.
class _ChunkyTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  const _ChunkyTitle(this.text, {this.fontSize = 34});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      height: 1.0,
    );
    final outer = fontSize * 0.26;
    final inner = fontSize * 0.15;
    return Transform.rotate(
      angle: -0.02,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = outer
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF5D2E00),
            ),
          ),
          Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = inner
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
            ).createShader(bounds),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: base.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
