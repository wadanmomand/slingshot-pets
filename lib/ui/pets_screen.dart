// My Pets: concept-style collection of rescued pets.
// Chunky golden title, golden 3D frames, cozy room bg, collection banner.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/sprites.dart';
import '../audio/sfx.dart';
import '../meta/progress.dart';
import 'icon3d.dart';
import 'chunky_text.dart';

/// The 4 collectible pet types, mapped from pet ids by hash.
const List<Map<String, String>> _petTypes = [
  {'sprite': 'pet_puppy', 'name': 'GOLDEN PUPPY'},
  {'sprite': 'pet_kitten', 'name': 'GREY KITTEN'},
  {'sprite': 'pet_ginger', 'name': 'ORANGE TABBY'},
  {'sprite': 'pet_bunny', 'name': 'BUNNY'},
];

class PetsScreen extends StatefulWidget {
  final ProgressState progress;

  const PetsScreen({super.key, required this.progress});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  final Sfx _sfx = Sfx();
  bool _spritesReady = false;

  @override
  void initState() {
    super.initState();
    SpriteCache.instance.load().then((_) {
      if (mounted) setState(() => _spritesReady = true);
    });
  }

  /// Which pet types the user has rescued (by id hash), for the collection.
  Set<int> _rescuedTypes() {
    return widget.progress.rescuedPets
        .map((id) => id.hashCode.abs() % _petTypes.length)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final sprites = SpriteCache.instance;
    final bg = sprites.get('bg_pets');
    final rescued = _rescuedTypes();
    return Scaffold(
      body: Stack(
        children: [
          // Cozy 3D room background.
          Positioned.fill(
            child: bg != null
                ? RawImage(image: bg, fit: BoxFit.cover)
                : Container(color: const Color(0xFF8D6E63)),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top row: back button + coins.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon3DButton(
                        spriteKey: 'btn3d_back',
                        size: 52,
                        onTap: () {
                          _sfx.click();
                          Navigator.pop(context);
                        },
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006978),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: const Color(0xFFFFB300), width: 2.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Sprite3D('coin_3d', size: 28),
                            const SizedBox(width: 6),
                            Text('${widget.progress.coins}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Chunky golden title.
                const ChunkyText('MY PETS', fontSize: 80),
                const SizedBox(height: 12),
                // Pet grid.
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _petTypes.length,
                    itemBuilder: (context, i) {
                      final unlocked = rescued.isNotEmpty &&
                          rescued.contains(i);
                                            return _PetCard(
                        sprite: sprites.get(_petTypes[i]['sprite']!),
                        name: _petTypes[i]['name']!,
                        unlocked: unlocked,
                        ready: _spritesReady,
                      );
                    },
                  ),
                ),
                // Collection banner.
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                        color: const Color(0xFF8D5A00), width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Sprite3D('lock_3d', size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'COLLECTION ${rescued.length}/${_petTypes.length} • UNLOCK MORE!',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5D3A1A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Golden 3D frame card for one pet (or a locked stone badge).
class _PetCard extends StatelessWidget {
  final ui.Image? sprite;
  final String name;
  final bool unlocked;
  final bool ready;

  const _PetCard({
    required this.sprite,
    required this.name,
    required this.unlocked,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final lock = SpriteCache.instance.get('lock_3d');
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFF57C00)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF8D5A00), width: 3),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: unlocked
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFB0BEC5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: unlocked
                    ? (sprite != null
                        ? RawImage(image: sprite, fit: BoxFit.contain)
                        : PetAvatar(petId: name, size: 80))
                    : (lock != null
                        ? RawImage(
                            image: lock, width: 130, height: 130)
                        : const SizedBox(width: 130, height: 130)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                unlocked ? name : 'LOCKED',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: unlocked
                      ? const Color(0xFF8D5A00)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cute pet face avatar fallback (procedural, used until sprites load).
class PetAvatar extends StatelessWidget {
  final String petId;
  final double size;

  const PetAvatar({super.key, required this.petId, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PetFacePainter(petId),
    );
  }
}

class _PetFacePainter extends CustomPainter {
  final String petId;
  _PetFacePainter(this.petId);

  @override
  void paint(Canvas canvas, Size size) {
    final fur = [
      const Color(0xFFF5C16C),
      const Color(0xFFB0BEC5),
      const Color(0xFFFFAB91),
      const Color(0xFFBCAAA4),
    ][petId.hashCode.abs() % 4];
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final ear = Paint()..color = fur;
    canvas.drawCircle(c + Offset(-r * 0.6, -r * 0.6), r * 0.38, ear);
    canvas.drawCircle(c + Offset(r * 0.6, -r * 0.6), r * 0.38, ear);
    canvas.drawCircle(c, r * 0.85, Paint()..color = fur);
    final eye = Paint()..color = Colors.black87;
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.05), r * 0.12, eye);
    canvas.drawCircle(c + Offset(r * 0.3, -r * 0.05), r * 0.12, eye);
  }

  @override
  bool shouldRepaint(covariant _PetFacePainter old) =>
      old.petId != petId;
}
