// Player progress: unlocked levels, stars, coins, rescued pets.
// Persisted to shared_preferences as JSON. Pure Dart, unit-tested.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProgressState {
  static const String _key = 'slingshot_pets_progress_v1';

  int coins = 0;

  /// level id -> stars (0..3). Presence also marks the level completed.
  final Map<int, int> stars = {};

  /// Rescued pet ids, e.g. 'L12p1'.
  final Set<String> rescuedPets = {};

  /// Highest level id ever unlocked (1-based).
  int maxUnlocked = 1;

  // Settings (persisted).
  bool music = true;
  bool sfxOn = true;
  bool vibration = false;
  bool notifications = true;

  bool isUnlocked(int levelId) => levelId <= maxUnlocked;

  int starsFor(int levelId) => stars[levelId] ?? 0;

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// Records a win. Returns coins earned.
  int recordWin(int levelId, int earnedStars, Set<String> pets) {
    final prev = stars[levelId] ?? 0;
    if (earnedStars > prev) stars[levelId] = earnedStars;
    rescuedPets.addAll(pets);
    if (levelId + 1 > maxUnlocked) maxUnlocked = levelId + 1;
    final coinsEarned = 10 + earnedStars * 5;
    coins += coinsEarned;
    return coinsEarned;
  }

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'stars': stars.map((k, v) => MapEntry(k.toString(), v)),
        'pets': rescuedPets.toList(),
        'maxUnlocked': maxUnlocked,
        'music': music,
        'sfxOn': sfxOn,
        'vibration': vibration,
        'notifications': notifications,
      };

  void fromJson(Map<String, dynamic> json) {
    coins = (json['coins'] as num?)?.toInt() ?? 0;
    stars.clear();
    final s = json['stars'] as Map<String, dynamic>? ?? {};
    for (final e in s.entries) {
      stars[int.parse(e.key)] = (e.value as num).toInt();
    }
    rescuedPets
      ..clear()
      ..addAll((json['pets'] as List?)?.cast<String>() ?? []);
    maxUnlocked = (json['maxUnlocked'] as num?)?.toInt() ?? 1;
    music = (json['music'] as bool?) ?? true;
    sfxOn = (json['sfxOn'] as bool?) ?? true;
    vibration = (json['vibration'] as bool?) ?? false;
    notifications = (json['notifications'] as bool?) ?? true;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt save: start fresh rather than crash.
      }
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
