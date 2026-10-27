// Slingshot Pets — physics rescue puzzler.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ad_service.dart';
import 'art/sprites.dart';
import 'core/level_model.dart';
import 'meta/progress.dart';
import 'ui/chunky_text.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const SlingshotPetsApp());
}

class SlingshotPetsApp extends StatelessWidget {
  const SlingshotPetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slingshot Pets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const _Boot(),
    );
  }
}

/// Loads levels + progress, initializes ads, then shows home.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late final Future<_Ready> _ready = _init();

  static Future<_Ready> _init() async {
    final raw = await rootBundle.loadString('assets/levels/levels.json');
    final list =
        (jsonDecode(raw)['levels'] as List).cast<Map<String, dynamic>>();
    final levels = list.map(LevelDef.fromJson).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final progress = ProgressState();
    await progress.load();
    final ads = AdService();
    // Ads initialize in the background: home must never wait on the
    // network. By the time the player reaches the map (banner) or wins a
    // level (interstitial/rewarded), init has long finished.
    unawaited(ads.init());
    await SpriteCache.instance.load();
    return _Ready(levels, progress, ads);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Ready>(
      future: _ready,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
                child: Text('Failed to start: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          // Branded loading screen (never a bare spinner): the boot only
          // waits on local work now (levels + sprites), ads init in bg.
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFB300), Color(0xFFF57C00)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChunkyText('SLINGSHOT', fontSize: 52),
                    ChunkyText('PETS', fontSize: 52),
                    const SizedBox(height: 28),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading your pets...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final r = snap.data!;
        return HomeScreen(
          levels: r.levels,
          progress: r.progress,
          ads: r.ads,
        );
      },
    );
  }
}

class _Ready {
  final List<LevelDef> levels;
  final ProgressState progress;
  final AdService ads;
  _Ready(this.levels, this.progress, this.ads);
}
