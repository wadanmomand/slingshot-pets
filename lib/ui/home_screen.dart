// Home screen: Play, My Pets, coins, and a cross-promo card.
import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../art/sprites.dart';
import '../core/level_model.dart';
import '../meta/progress.dart';
import 'icon3d.dart';
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
        child: SafeArea(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1024 / 1820,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The finalized concept art, pixel-perfect.
                  _ConceptArt(),
                  // Invisible tap zone over the painted PLAY button.
                  _TapZone(
                    alignY: 0.66,
                    widthFactor: 0.84,
                    heightFactor: 0.115,
                    onTap: () => _openMap(context, chapter),
                  ),
                  // Invisible tap zone over the painted MY PETS button.
                  _TapZone(
                    alignY: 0.855,
                    widthFactor: 0.52,
                    heightFactor: 0.065,
                    onTap: () => _openPets(context),
                  ),
                  // Next-level pill, top-left.
                  Positioned(
                    top: 10,
                    left: 12,
                    child: _levelPill(nextLevel),
                  ),
                  // Coin chip, top-right.
                  Positioned(
                    top: 10,
                    right: 12,
                    child: _coinChip(),
                  ),
                  // Cross-promo, bottom.
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 6,
                    child: _crossPromo(),
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Level $nextLevel',
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6D3A00))),
        ],
      ),
    );
  }

  Widget _coinChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Sprite3D('coin_3d', size: 28),
          const SizedBox(width: 6),
          Text('${widget.progress.coins}',
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  /// Cross-promotion for the sibling Pawzzle title (free installs both ways).
  Widget _crossPromo() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text('🎈', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('More from Pawzzle',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Pawzzle Rescue: Bubble Pop — 2000 bubble levels!',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Play Store link goes here once published.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon to Google Play!')),
                );
              },
              child: const Text('GET'),
            ),
          ],
        ),
      ),
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
    // Exact aspect fit: the parent AspectRatio matches the art (1024x1820).
    return RawImage(image: img, fit: BoxFit.fill);
  }
}

/// Invisible tap target over a painted button in the concept art.
class _TapZone extends StatelessWidget {
  final double alignY;
  final double widthFactor;
  final double heightFactor;
  final VoidCallback onTap;
  const _TapZone({
    required this.alignY,
    required this.widthFactor,
    required this.heightFactor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment(0, alignY),
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          heightFactor: heightFactor,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
