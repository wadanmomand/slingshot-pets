import 'package:flutter_test/flutter_test.dart';
import 'package:smash/meta/progress.dart';

void main() {
  test('fresh progress unlocks only level 1', () {
    final p = ProgressState();
    expect(p.isUnlocked(1), isTrue);
    expect(p.isUnlocked(2), isFalse);
    expect(p.coins, 0);
    expect(p.totalStars, 0);
  });

  test('recordWin unlocks next, keeps best stars, pays coins', () {
    final p = ProgressState();
    final c1 = p.recordWin(1, 2, {'L1p1'});
    expect(c1, 10 + 2 * 5);
    expect(p.coins, c1);
    expect(p.isUnlocked(2), isTrue);
    expect(p.starsFor(1), 2);
    expect(p.rescuedPets, contains('L1p1'));
    // Replaying worse keeps the best.
    p.recordWin(1, 1, {});
    expect(p.starsFor(1), 2);
    expect(p.totalStars, 2);
  });

  test('spendCoins respects balance', () {
    final p = ProgressState();
    p.recordWin(1, 3, {});
    expect(p.spendCoins(10), isTrue);
    expect(p.spendCoins(99999), isFalse);
  });

  test('toJson/fromJson round-trips', () {
    final p = ProgressState();
    p.recordWin(5, 3, {'L5p1', 'L5p2'});
    p.recordWin(6, 1, {});
    final q = ProgressState();
    q.fromJson(p.toJson());
    expect(q.coins, p.coins);
    expect(q.starsFor(5), 3);
    expect(q.rescuedPets, {'L5p1', 'L5p2'});
    expect(q.maxUnlocked, 7);
    expect(q.isUnlocked(7), isTrue);
    expect(q.isUnlocked(8), isFalse);
  });
}
