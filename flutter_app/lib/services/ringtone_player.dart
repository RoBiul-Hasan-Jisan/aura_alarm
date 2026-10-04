import 'package:audioplayers/audioplayers.dart';

/// Plays ringtones for the preview in the alarm form and for in-browser alarms.
class RingtonePlayer {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(String key, {bool loop = false}) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(AssetSource('ringtones/$key.mp3'));
    } catch (_) {/* browsers may block audio until the user interacts with the page */}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
