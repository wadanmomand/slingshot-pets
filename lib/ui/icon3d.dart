// 3D icon widgets — every icon in the game is a rendered 3D image,
// never a flat Material glyph. Circular buttons are clipped to a circle
// so the square art's corners never show.
import 'package:flutter/material.dart';

import '../art/sprites.dart';

/// A circular 3D image button (back, pause, gear...). Replaces the old
/// teal Container + flat Icon pattern.
class Icon3DButton extends StatelessWidget {
  final String spriteKey;
  final double size;
  final VoidCallback onTap;

  const Icon3DButton({
    super.key,
    required this.spriteKey,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final img = SpriteCache.instance.get(spriteKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3)),
          ],
        ),
        child: ClipOval(
          child: img != null
              ? RawImage(image: img, fit: BoxFit.cover)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// A circular 3D icon for settings rows (golden circle with brown glyph).
/// Replaces the old golden Container + flat Icon pattern.
class Icon3DRow extends StatelessWidget {
  final String spriteKey;
  final double size;

  const Icon3DRow({
    super.key,
    required this.spriteKey,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final img = SpriteCache.instance.get(spriteKey);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ClipOval(
        child: img != null
            ? RawImage(image: img, fit: BoxFit.cover)
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Small inline 3D sprite (coin in HUD, star, lock fallback).
class Sprite3D extends StatelessWidget {
  final String spriteKey;
  final double size;

  const Sprite3D(this.spriteKey, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final img = SpriteCache.instance.get(spriteKey);
    if (img == null) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: RawImage(image: img, fit: BoxFit.contain),
    );
  }
}
