// Validates the shipped level pack (assets/levels/levels.json).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smash/core/level_model.dart';

void main() {
  late List<LevelDef> levels;
  late List<Map<String, dynamic>> raw;

  setUpAll(() {
    final file = File('assets/levels/levels.json');
    expect(file.existsSync(), isTrue, reason: 'level pack missing');
    raw = (jsonDecode(file.readAsStringSync())['levels'] as List)
        .cast<Map<String, dynamic>>();
    levels = raw.map(LevelDef.fromJson).toList();
  });

  test('pack has 1000 uniquely-id\'d levels', () {
    expect(levels.length, 1000);
    final ids = levels.map((l) => l.id).toSet();
    expect(ids.length, 1000);
  });

  test('100 levels per chapter across 10 chapters', () {
    final chapters = raw.map((l) => l['chapter'] as int).toList();
    for (var c = 1; c <= 10; c++) {
      expect(chapters.where((x) => x == c).length, 100,
          reason: 'chapter $c count wrong');
    }
    final names =
        raw.map((l) => l['chapterName'] as String).toSet().toList()..sort();
    expect(names.length, 10);
  });

  test('every level is winnable in principle', () {
    for (final l in levels) {
      expect(l.totalPets, greaterThanOrEqualTo(1),
          reason: 'level ${l.id} has no pets');
      expect(l.balls, greaterThanOrEqualTo(1));
      expect(l.par, greaterThanOrEqualTo(1));
      expect(l.par, lessThanOrEqualTo(l.balls),
          reason: 'level ${l.id}: par > balls');
      // Every cage must hold a pet.
      for (final b in l.bodies) {
        if (b.kind == SmashBodyKind.cage) {
          expect(b.petId, isNotNull, reason: 'level ${l.id} cage w/o pet');
        }
      }
      // Structures must sit above the ground plane (y=0 top),
      // accounting for body rotation.
      for (final b in l.bodies) {
        if (b.kind != SmashBodyKind.ground) {
          final c = cos(b.angle).abs();
          final s = sin(b.angle).abs();
          final bottom = b.y - (c * b.h / 2 + s * b.w / 2);
          expect(bottom, greaterThanOrEqualTo(-0.01),
              reason: 'level ${l.id}: ${b.kind} sunk in ground');
        }
      }
    }
  });

  test('difficulty ramps: later chapters allow fewer spare balls', () {
    double spare(int chapter) {
      final ls = <LevelDef>[];
      for (var i = 0; i < raw.length; i++) {
        if (raw[i]['chapter'] == chapter) ls.add(levels[i]);
      }
      return ls.map((l) => l.balls - l.par).reduce((a, b) => a + b) /
          ls.length;
    }
    expect(spare(1), greaterThan(spare(10)));
  });
}
