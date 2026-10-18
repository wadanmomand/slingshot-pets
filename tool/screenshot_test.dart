// One-off screenshot generator for Pawzzle Smash (NOT a regression test).
// Run: flutter test --update-goldens tool/screenshot_test.dart
// PNGs land in tool/goldens/ — copy to design/screenshots/.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smash/ads/ad_service.dart';
import 'package:smash/art/sprites.dart';
import 'package:smash/core/level_model.dart';
import 'package:smash/core/slingshot.dart';
import 'package:smash/meta/progress.dart';
import 'package:smash/ui/game_screen.dart';
import 'package:smash/ui/home_screen.dart';
import 'package:smash/ui/level_map_screen.dart';
import 'package:smash/ui/pets_screen.dart';
import 'package:smash/ui/settings_screen.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

Future<void> _loadSprites() async {
  // rootBundle can't load assets in widget tests; decode from files instead.
  final dir =
      '${Platform.environment['HOME']}/workspace/pawzzle-smash/app/assets/sprites';
  for (final n in SpriteCache.names) {
    final png = File('$dir/$n.png');
    final file = await png.exists() ? png : File('$dir/$n.jpg');
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    SpriteCache.instance.put(n, (await codec.getNextFrame()).image);
  }
}

Future<void> _loadFonts() async {
  final mdir =
      '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, String path) async {
    final bytes = await File(path).readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await load('Roboto', '$mdir/Roboto-Regular.ttf');
  await load('Roboto', '$mdir/Roboto-Bold.ttf');
  await load('MaterialIcons', '$mdir/MaterialIcons-Regular.otf');
  // Emoji fallback for 🐾🪙⭐ etc. in the test environment.
  await load('NotoColorEmoji', '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
}

/// Sprite PNG bytes preloaded via runAsync (File IO hangs in FakeAsync).
final Map<String, Uint8List> _spriteBytes = {};

Future<void> _loadSpriteBytes() async {
  final dir =
      '${Platform.environment['HOME']}/workspace/pawzzle-smash/app/assets/sprites';
  for (final n in SpriteCache.names) {
    for (final ext in ['png', 'jpg']) {
      final file = File('$dir/$n.$ext');
      if (await file.exists()) {
        _spriteBytes['assets/sprites/$n.$ext'] = await file.readAsBytes();
        break;
      }
    }
  }
}

/// Serves the real sprite PNGs to Image.asset in widget tests.
class _FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('AssetManifest.bin') ||
        key.endsWith('AssetManifest.json')) {
      // Empty manifest: no resolution variants, keys used as-is.
      final data =
          const StandardMessageCodec().encodeMessage(<String, Object>{});
      return data!;
    }
    final bytes = _spriteBytes[key];
    if (bytes != null) return ByteData.view(bytes.buffer);
    throw FlutterError('test bundle has no $key');
  }
}

class _NoAds extends AdService {
  @override
  BannerAd makeBanner() => BannerAd(
        size: AdSize.banner,
        adUnitId: 'test',
        request: const AdRequest(),
        listener: BannerAdListener(),
      ); // never load() — no plugin in tests

  @override
  void onLevelWon() {}

  @override
  Future<bool> showRewarded() async => false;
}

LevelDef _demoLevel() => LevelDef.fromJson({
      'id': 1,
      'balls': 3,
      'par': 2,
      'slingX': -6.0,
      'slingY': 2.0,
      'bodies': [
        {'kind': 'ground', 'x': 4, 'y': -0.5, 'w': 32, 'h': 1},
        {'kind': 'wood', 'x': 5, 'y': 1.0, 'w': 0.6, 'h': 2.0},
        {'kind': 'wood', 'x': 7, 'y': 1.0, 'w': 0.6, 'h': 2.0},
        {'kind': 'wood', 'x': 6, 'y': 2.2, 'w': 2.6, 'h': 0.4},
        {'kind': 'glass', 'x': 6, 'y': 2.55, 'w': 1.6, 'h': 0.3},
        {'kind': 'cage', 'x': 6, 'y': 3.2, 'w': 1.0, 'h': 1.0, 'petId': 'L1p1'},
      ],
    });

/// 100 stub levels so the map's chapter-1 grid has real data.
List<LevelDef> _hundredLevels() => List.generate(
      100,
      (i) => LevelDef.fromJson({
        'id': i + 1,
        'balls': 3,
        'par': 2,
        'slingX': -6.0,
        'slingY': 2.0,
        'bodies': [
          {'kind': 'ground', 'x': 4, 'y': -0.5, 'w': 32, 'h': 1},
          {
            'kind': 'cage',
            'x': 6,
            'y': 0.5,
            'w': 1.0,
            'h': 1.0,
            'petId': 'L${i + 1}p1'
          },
        ],
      }),
    );

LevelDef _winLevel() => LevelDef.fromJson({
      'id': 1,
      'balls': 3,
      'par': 1,
      'slingX': -6.0,
      'slingY': 2.0,
      'bodies': [
        {'kind': 'ground', 'x': 4, 'y': -0.5, 'w': 32, 'h': 1},
        {
          'kind': 'cage',
          'x': -1.5,
          'y': 0.5,
          'w': 1.0,
          'h': 1.0,
          'petId': 'L1p1'
        },
      ],
    });

/// Mirror of GameScreen._frameCamera: tight per-level horizontal framing.
(double, double) _frameFor(LevelDef def) {
  var x0 = def.slingX - 2.0;
  var x1 = def.slingX + 2.0;
  for (final b in def.bodies) {
    if (b.x - b.w < x0) x0 = b.x - b.w;
    if (b.x + b.w > x1) x1 = b.x + b.w;
  }
  final cx = (x0 + x1) / 2;
  var half = (x1 - x0) / 2 + 1.2;
  half = half.clamp(7.5, 11.5);
  return (cx - half, cx + half);
}

/// World->screen for [def]'s camera frame (1080x1920, DPR 1).
Offset _w2sFor(LevelDef def, double x, double y) {
  final (vx0, vx1) = _frameFor(def);
  const w = 1080.0, h = 1920.0;
  const vh = 13.0; // vy1 - vy0
  final vw = vx1 - vx0;
  final scale = min(w / vw, h / vh);
  final ox = (w - vw * scale) / 2;
  final oy = (h - vh * scale) / 2;
  return Offset(ox + (x - vx0) * scale, oy + (10.5 - y) * scale);
}

void main() {
  testWidgets('generate screenshots', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member (screenshot tool)
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(_loadFonts); // real async: FakeAsync hangs FontLoader
    await tester.runAsync(_loadSprites);
    await tester.runAsync(_loadSpriteBytes);
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ads = _NoAds();
    final progress = ProgressState();
    final themed = ThemeData(fontFamily: 'Roboto');

    // 1. Home
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: HomeScreen(levels: [_demoLevel()], progress: progress, ads: ads),
    )));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(HomeScreen), matchesGoldenFile('goldens/shot-home.png'));

    // 2. Level map (chapter 1 needs 100 levels)
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: LevelMapScreen(
          levels: _hundredLevels(), progress: progress, ads: ads),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(LevelMapScreen),
        matchesGoldenFile('goldens/shot-map.png'));

    // 2b. Pets (with 2 rescued pets unlocked).
    final petsProgress = ProgressState();
    petsProgress.rescuedPets.addAll(['L1p1', 'L2p1']);
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: PetsScreen(progress: petsProgress),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(PetsScreen),
        matchesGoldenFile('goldens/shot-pets.png'));

    // 2c. Settings.
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: SettingsScreen(progress: progress),
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('goldens/shot-settings.png'));

    // 3+4. Game: aim pose, then mid-flight
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: GameScreen(
          key: const ValueKey('demo'),
          levels: [_demoLevel()],
          progress: progress,
          ads: ads),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final demo = _demoLevel();
    final anchor = _w2sFor(demo, -6, 2);
    final pull = _w2sFor(demo, -8.2, 1.2); // pull 2.2m left, 0.8m down
    final g = await tester.startGesture(anchor);
    await g.moveTo(pull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(
        find.byType(GameScreen), matchesGoldenFile('goldens/shot-aim.png'));

    await g.up();
    await tester.pump(const Duration(milliseconds: 350));
    await expectLater(
        find.byType(GameScreen), matchesGoldenFile('goldens/shot-action.png'));

    // 5. Win dialog: solve a pull that hits the lone cage.
    // NOTE: fresh ValueKey — otherwise the old GameScreenState is reused.
    await tester.pumpWidget(DefaultAssetBundle(
      bundle: _FileAssetBundle(),
      child: MaterialApp(
      theme: themed,
      home: GameScreen(
          key: const ValueKey('win'),
          levels: [_winLevel()],
          progress: progress,
          ads: ads),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final sling = Slingshot(anchor: Vector2(-6, 2));
    final cageAt = Vector2(-1.5, 0.5);
    Vector2? best;
    outer:
    for (var px = -2.5; px <= -0.6; px += 0.1) {
      for (var py = -2.0; py <= 2.0; py += 0.1) {
        final v = sling.launchVelocity(Vector2(px, py));
        for (final p
            in sling.trajectory(v, Vector2(0, -10), points: 150, dt: 1 / 60)) {
          if ((p - cageAt).length < 0.8) {
            best = Vector2(px, py);
            break outer;
          }
          if (p.y < -2) break;
        }
      }
    }
    expect(best, isNotNull, reason: 'no hitting pull found');

    final winLvl = _winLevel();
    final g2 = await tester.startGesture(_w2sFor(winLvl, -6, 2));
    await g2.moveTo(_w2sFor(winLvl, -6 + best!.x, 2 + best.y));
    await tester.pump(const Duration(milliseconds: 100));
    await g2.up();
    await tester.pump(const Duration(milliseconds: 300));
    var won = false;
    for (var i = 0; i < 200 && !won; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      won = find.text('LEVEL COMPLETE!').evaluate().isNotEmpty;
    }
    expect(won, isTrue, reason: 'win dialog never appeared');
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
        find.byType(GameScreen), matchesGoldenFile('goldens/shot-win.png'));
  });
}
