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
    'tnt',
    'pet_puppy',
    'pet_kitten',
    'pet_ginger',
    'pet_bunny',
    'pet_full_puppy',
    'pet_full_kitten',
    'pet_full_ginger',
    'pet_full_bunny',
    'ball',
    'slingshot',
    'bg_game',
    'bg_home',
    'bg_map',
    'bg_pets',
    'btn3d_back',
    'btn3d_pause',
    'btn3d_gear',
    'btn3d_sound',
    'btn3d_vibrate',
    'btn3d_globe',
    'coin_3d',
    'lock_3d',
    'star_3d',
    'fountain_3d',
  ];

  final Map<String, ui.Image> _imgs = {};
  Future<void>? _loading;

  bool get loaded => _imgs.isNotEmpty;

  /// Decodes all sprites in parallel: the old sequential loop made boot
  /// take 10-30s on weak phones (one slow decode blocked everything).
  Future<void> load() {
    if (loaded) return Future.value();
    _loading ??= Future.wait(names.map(_loadOne));
    return _loading!;
  }

  Future<void> _loadOne(String n) async {
    // Backgrounds are JPG (smaller); sprites are PNG (transparency).
    for (final ext in ['png', 'jpg']) {
      try {
        final data = await rootBundle.load('assets/sprites/$n.$ext');
        final codec =
            await ui.instantiateImageCodec(data.buffer.asUint8List());
        _imgs[n] = (await codec.getNextFrame()).image;
        return;
      } catch (_) {
        // Try the next extension; procedural fallback covers failures.
      }
    }
  }

  ui.Image? get(String name) => _imgs[name];

  /// Test/tool hook: inject a pre-decoded image.
  void put(String name, ui.Image img) => _imgs[name] = img;
}
