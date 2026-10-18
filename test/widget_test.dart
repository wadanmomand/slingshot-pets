// Widget test: GameScreen boots with real level data (no asset loading,
// which hangs under testWidgets' FakeAsync).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smash/ads/ad_service.dart';
import 'package:smash/core/level_model.dart';
import 'package:smash/meta/progress.dart';
import 'package:smash/ui/game_screen.dart';

LevelDef _level() => LevelDef.fromJson({
      'id': 1,
      'balls': 3,
      'par': 1,
      'slingX': -6.0,
      'slingY': 2.0,
      'bodies': [
        {'kind': 'ground', 'x': 4, 'y': -0.5, 'w': 32, 'h': 1},
        {
          'kind': 'cage',
          'x': 7,
          'y': 0.5,
          'w': 1,
          'h': 1,
          'petId': 'p1',
        },
      ],
    });

void main() {
  testWidgets('game screen boots and shows HUD', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(
        levels: [_level()],
        progress: ProgressState(),
        ads: AdService(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.textContaining('LEVEL 1'), findsWidgets);
    expect(find.textContaining('3/3', findRichText: true), findsWidgets);
  });
}
