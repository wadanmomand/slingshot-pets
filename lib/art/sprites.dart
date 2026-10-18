// 3D sprite cache: loads AI-rendered sprites once, serves them to the
// painter. If a sprite is missing (or loading failed), the painter falls
// back to its procedural 3D-shaded drawing, so the game never breaks.
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class SpriteCache {
  SpriteCache._();
  static final SpriteCache instance = SpriteCache._();

  static const List<String> names = [
    'wood',
    'glass',
    'stone',
    'cage',
    'pet_puppy',
    'pet_kitten',
    'pet_ginger',
    'pet_bunny',
    'ball',
    'slingshot',
    'bg_game',
    'bg_home',
    'bg_map',
    'bg_pets',
    'btn3d_back',
    'btn3d_pause',
    'btn3d_gear',
    'btn3d_music',
    'btn3d_sound',
    'btn3d_vibrate',
    'btn3d_bell',
    'btn3d_globe',
    'coin_3d',
    'lock_3d',
    'star_3d',
    'fountain_3d',
  ];

  final Map<String, ui.Image> _imgs = {};

  bool get loaded => _imgs.isNotEmpty;

  Future<void> load() async {
    if (loaded) return;
    for (final n in names) {
      // Backgrounds are JPG (smaller); sprites are PNG (transparency).
      for (final ext in ['png', 'jpg']) {
        try {
          final data = await rootBundle.load('assets/sprites/$n.$ext');
          final codec =
              await ui.instantiateImageCodec(data.buffer.asUint8List());
          _imgs[n] = (await codec.getNextFrame()).image;
          break;
        } catch (_) {
          // Try the next extension; procedural fallback covers failures.
        }
      }
    }
  }

  ui.Image? get(String name) => _imgs[name];

  /// Test/tool hook: inject a pre-decoded image.
  void put(String name, ui.Image img) => _imgs[name] = img;
}
