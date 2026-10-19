// Playable Slingshot Pets screen: game loop, slingshot touch input,
// HUD, particles/shake/slow-mo juice, win/lose dialogs.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forge2d/forge2d.dart' show Vector2;

import '../ads/ad_service.dart';
import '../art/sprites.dart';
import '../audio/sfx.dart';
import '../core/level_model.dart';
import '../core/slingshot.dart';
import 'icon3d.dart';
import '../core/smash_world.dart';
import '../meta/progress.dart';
import 'chunky_text.dart';
import 'particles.dart';
import 'smash_painter.dart';

class GameScreen extends StatefulWidget {
  final List<LevelDef> levels;
  final int startIndex;
  final ProgressState progress;
  final AdService ads;

  const GameScreen({
    super.key,
    required this.levels,
    this.startIndex = 0,
    required this.progress,
    required this.ads,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late int _levelIndex;
  SmashWorld? _world;
  late final Slingshot _sling;
  final SmashCamera _camera = SmashCamera();
  final ParticleSystem _particles = ParticleSystem();
  final Sfx _sfx = Sfx();
  final Random _rng = Random();

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _acc = 0;
  static const double _step = 1 / 60;

  Vector2? _aimDrag; // pull vector in world meters
  bool _grabbing = false;

  Offset _shake = Offset.zero;
  double _shakeMag = 0;
  double _timeScale = 1;
  double _slowmoLeft = 0;

  bool _winShown = false;
  bool _loseShown = false;
  bool _paused = false;
  int _coinsEarned = 0;
  double _playTime = 0;
  final List<PetCelebration> _celebrations = [];

  @override
  void initState() {
    super.initState();
    _levelIndex = widget.startIndex;
    _sling = Slingshot(anchor: Vector2(-4, 2));
    _loadLevel(_levelIndex);
    _ticker = createTicker(_onTick)..start();
    // 3D sprites load async; painter falls back to procedural until ready.
    SpriteCache.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Zoom the camera around the level's actual content so sprites stay
  /// big and juicy on every level.
  void _frameCamera(LevelDef def) {
    var x0 = def.slingX - 2.0;
    var x1 = def.slingX + 2.0;
    for (final b in def.bodies) {
      if (b.x - b.w < x0) x0 = b.x - b.w;
      if (b.x + b.w > x1) x1 = b.x + b.w;
    }
    final cx = (x0 + x1) / 2;
    var half = (x1 - x0) / 2 + 1.2;
    half = half.clamp(7.5, 11.5);
    _camera.frame(cx - half, cx + half);
  }

  void _loadLevel(int index) {
    final def = widget.levels[index];
    _world = SmashWorld(def);
    _sling.anchor.setFrom(Vector2(def.slingX, def.slingY));
    _frameCamera(def);
    _particles.clear();
    _celebrations.clear();
    _aimDrag = null;
    _grabbing = false;
    _winShown = false;
    _loseShown = false;
    _timeScale = 1;
    _slowmoLeft = 0;
    _shakeMag = 0;
    _shake = Offset.zero;
  }

  void _onTick(Duration elapsed) {
    _playTime +=
        min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 20);
    // Prune finished pet celebrations.
    _celebrations.removeWhere((c) => _playTime - c.startTime > 2.0);
    if (_paused) {
      _lastTick = elapsed;
      return;
    }
    final realDt =
        min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 20);
    _lastTick = elapsed;

    if (_slowmoLeft > 0) {
      _slowmoLeft -= realDt;
      if (_slowmoLeft <= 0) _timeScale = 1;
    }

    _acc += realDt * _timeScale;
    var guard = 0;
    while (_acc >= _step && guard < 8) {
      _world?.step(_step);
      _acc -= _step;
      guard++;
    }

    _drainBreakEvents();
    _particles.update(realDt);

    if (_shakeMag > 0.4) {
      _shakeMag *= exp(-6 * realDt);
      _shake = Offset((_rng.nextDouble() * 2 - 1) * _shakeMag,
          (_rng.nextDouble() * 2 - 1) * _shakeMag);
    } else {
      _shakeMag = 0;
      _shake = Offset.zero;
    }

    final w = _world;
    if (w != null && _slowmoLeft <= 0) {
      if (w.phase == GamePhase.won && !_winShown) {
        _winShown = true;
        _sfx.win();
        final coins = widget.progress.recordWin(
          widget.levels[_levelIndex].id,
          w.starsForWin(),
          w.freedPets,
        );
        widget.progress.save();
        widget.ads.onLevelWon();
        _coinsEarned = coins;
        // Let the celebration play a beat before the dialog.
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() {});
        });
      } else if (w.phase == GamePhase.lost && !_loseShown) {
        _loseShown = true;
        _sfx.fail();
        setState(() {});
      }
    }
    setState(() {});
  }

  void _drainBreakEvents() {
    final w = _world;
    if (w == null) return;
    for (final e in w.takeBreakEvents()) {
      final at = Offset(e.at.x, e.at.y);
      switch (e.kind) {
        case SmashBodyKind.wood:
          _burst(at, [const Color(0xFFA9744F), const Color(0xFF7A4E2D)], 14);
          _sfx.crack();
          _shakeMag = max(_shakeMag, 5);
        case SmashBodyKind.glass:
          _burst(at, [const Color(0xFFBFE8FF), const Color(0xFFFFFFFF)], 16);
          _sfx.shatter();
          _shakeMag = max(_shakeMag, 7);
        case SmashBodyKind.cage:
          _burst(at, [const Color(0xFFFFC93C), const Color(0xFFE0A800)], 18);
          _particles.confetti(at: at);
          _sfx.cage();
          _sfx.cheer();
          _shakeMag = max(_shakeMag, 14);
          // The freed pet celebrates its rescue: hops with joy + hearts.
          if (e.petId != null) {
            _celebrations.add(PetCelebration(
              at: Vector2(e.at.x, e.at.y),
              petId: e.petId!,
              startTime: _playTime,
            ));
          }
          if (w.freedPets.length >= w.totalPets && w.totalPets > 0) {
            // Last pet: dramatic slow-mo.
            _slowmoLeft = 0.9;
            _timeScale = 0.25;
          }
        case SmashBodyKind.stone:
        case SmashBodyKind.ground:
        case SmashBodyKind.ball:
          break;
      }
    }
  }

  void _burst(Offset at, List<Color> colors, int count) {
    _particles.burst(
      at: at,
      count: count,
      colors: colors,
      speedMin: 1.5,
      speedMax: 7,
      life: 0.8,
      sizeMin: 0.1,
      sizeMax: 0.28,
      gravity: 22,
    );
  }

  // --- touch input: grab near the sling, drag to aim, release to fire ---

  void _onPanStart(DragStartDetails d, Size size) {
    _camera.layout(size);
    final w = _world;
    if (w == null || w.phase != GamePhase.aiming || _paused) return;
    final wp = _camera.screenToWorld(d.localPosition);
    if ((wp - _sling.anchor).length < 3.0) {
      _grabbing = true;
      _aimDrag = wp - _sling.anchor;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_grabbing) return;
    final wp = _camera.screenToWorld(d.localPosition);
    _aimDrag = wp - _sling.anchor;
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_grabbing) return;
    _grabbing = false;
    final drag = _aimDrag;
    _aimDrag = null;
    final w = _world;
    if (drag != null && drag.length > 0.35 && w != null) {
      w.launchBall(_sling.launchVelocity(drag));
      _sfx.launch();
    }
  }

  void _retry() {
    _sfx.click();
    setState(() => _loadLevel(_levelIndex));
  }

  /// Rewarded continue: watch an ad for +2 balls after failing.
  Future<void> _continueWithAd() async {
    _sfx.click();
    final earned = await widget.ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      final w = _world;
      if (w != null) {
        w.addBalls(2);
        _loseShown = false; // allow the dialog again if they fail once more
        _sfx.chime();
        setState(() {});
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready — try again in a moment.')),
      );
    }
  }

  void _next() {
    _sfx.click();
    if (_levelIndex + 1 < widget.levels.length) {
      setState(() {
        _levelIndex++;
        _loadLevel(_levelIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _world;
    return Scaffold(
      body: w == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                _camera.layout(size);
                return Stack(
                  children: [
                    GestureDetector(
                      onPanStart: (d) => _onPanStart(d, size),
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        size: size,
                        painter: SmashPainter(
                          world: w,
                          particles: _particles,
                          sling: _sling,
                          camera: _camera,
                          aimDrag: _aimDrag,
                          shake: _shake,
                          sprites: SpriteCache.instance,
                          time: _playTime,
                          celebrations: _celebrations,
                        ),
                      ),
                    ),
                    _hud(w),
                    if (_winShown && w.phase == GamePhase.won)
                      _dialog(
                        title: 'Level Complete!',
                        stars: w.starsForWin(),
                        subtitle: '+$_coinsEarned coins',
                        buttons: [
                          _btn('Retry', _retry),
                          _btn('Next', _next,
                              primary: _levelIndex + 1 < widget.levels.length),
                        ],
                      ),
                    if (_loseShown && w.phase == GamePhase.lost)
                      _dialog(
                        title: 'Out of balls!',
                        stars: 0,
                        buttons: [
                          _btn('Retry', _retry),
                          _btn('+2 balls 📺', _continueWithAd, primary: true),
                        ],
                      ),
                    if (_paused) _pauseOverlay(),
                  ],
                );
              },
            ),
    );
  }

  Widget _hud(SmashWorld w) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + coins (concept: dark pill top-left).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon3DButton(
                      spriteKey: 'btn3d_back',
                      size: 44,
                      onTap: () {
                        _sfx.click();
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF37474F),
                        borderRadius: BorderRadius.circular(22),
                        border:
                            Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Sprite3D('coin_3d', size: 26),
                          const SizedBox(width: 4),
                          Text('${widget.progress.coins}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                // Chunky golden LEVEL title (concept).
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ChunkyText('LEVEL ${_levelIndex + 1}', fontSize: 64),
                  ),
                ),
                // Teal pause button (concept).
                Icon3DButton(
                  spriteKey: 'btn3d_pause',
                  size: 52,
                  onTap: () {
                    _sfx.click();
                    setState(() => _paused = true);
                  },
                ),
              ],
            ),
            const Spacer(),
            // Bottom ammo bar (concept): teal bar with balls + count.
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF006978),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white30, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0;
                      i < w.ballsLeft.clamp(0, 8);
                      i++)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3),
                      child: Sprite3D('ball', size: 30),
                    ),
                  const SizedBox(width: 10),
                  Text('${w.ballsLeft}/${w.ballsLeft + w.ballsUsed}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFE082))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

/// Chunky golden 3D bubble title for the game HUD (design language).

  Widget _btn(String label, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFE082),
                    Color(0xFFFFB300),
                    Color(0xFFF57C00)
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFE0E0E0)],
                ),
          border: Border.all(
              color: primary ? const Color(0xFF8D5A00) : Colors.white,
              width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 3)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primary
                    ? const Color(0xFF5D3A1A)
                    : Colors.black87)),
      ),
    );
  }

  Widget _dialog(
      {required String title,
      required int stars,
      String? subtitle,
      required List<Widget> buttons}) {
    final sprites = SpriteCache.instance;
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFB300), width: 4),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45,
                  blurRadius: 24,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChunkyText(title.toUpperCase(), fontSize: 56),
              if (stars > 0) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: sprites.get('star_3d') != null
                            ? ColorFiltered(
                                colorFilter: i < stars
                                    ? const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply)
                                    : const ColorFilter.mode(
                                        Colors.grey, BlendMode.saturation),
                                child: RawImage(
                                    image: sprites.get('star_3d'),
                                    width: 52,
                                    height: 52),
                              )
                            : const SizedBox(width: 52, height: 52),
                      ),
                  ],
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8D5A00))),
              ],
              const SizedBox(height: 22),
              Wrap(spacing: 14, runSpacing: 10, children: buttons),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFB300), width: 4),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45,
                  blurRadius: 24,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ChunkyText('PAUSED', fontSize: 64),
              const SizedBox(height: 22),
              Wrap(spacing: 14, runSpacing: 10, children: [
                _btn('Resume', () {
                  _sfx.click();
                  setState(() => _paused = false);
                }, primary: true),
                _btn('Restart', _retry),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
