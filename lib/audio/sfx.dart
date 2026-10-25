// Thin SFX service: fire-and-forget pool players over bundled WAVs.
// Audio must never crash the game: all playback is guarded.
import 'package:audioplayers/audioplayers.dart';

class Sfx {
  bool enabled = true;
  double volume = 1.0;

  Future<void> _play(String asset) async {
    if (!enabled) return;
    final p = AudioPlayer();
    try {
      await p.setVolume(volume);
      await p.play(AssetSource(asset));
      await p.onPlayerComplete.first;
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
    } finally {
      // Always release the native player, even if play() threw (m9).
      await p.dispose();
    }
  }

  Future<void> launch() => _play('audio/launch.wav');
  Future<void> crack() => _play('audio/crack.wav');
  Future<void> shatter() => _play('audio/shatter.wav');
  Future<void> cage() => _play('audio/cage.wav');
  Future<void> cheer() => _play('audio/cheer.wav');
  Future<void> win() => _play('audio/win.wav');
  Future<void> fail() => _play('audio/fail.wav');
  Future<void> click() => _play('audio/click.wav');
  Future<void> chime() => _play('audio/chime.wav');
}
