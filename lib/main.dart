// Slingshot Pets — physics rescue puzzler.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ad_service.dart';
import 'core/level_model.dart';
import 'meta/progress.dart';
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
    await ads.init();
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
