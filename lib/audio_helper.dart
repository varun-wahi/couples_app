import 'package:audioplayers/audioplayers.dart';

class AudioHelper {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBackgroundMusic() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/love_theme.mp3'));
  }

  static Future<void> stopBackgroundMusic() async {
    await _player.stop();
  }
}