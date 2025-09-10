import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._internal() {
    _init();
  }

  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  late final AudioPlayer _bgmPlayer;
  final List<AudioPlayer> _sfxPlayers = [];
  int _sfxIndex = 0;
  bool _initialized = false;
  bool _bgmPlaying = false;

  double bgmVolume = 0.5;
  double sfxVolume = 1.0;
  // bgmVolume 范围 0.0 - 1.0
  bool get bgmPlaying => _bgmPlaying;

  Future<void> _init() async {
    if (_initialized) return;
    _bgmPlayer = AudioPlayer(playerId: 'bgm_player');
    for (int i = 0; i < 4; i++) {
      _sfxPlayers.add(AudioPlayer(playerId: 'sfx_player_$i'));
    }
    _initialized = true;
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _bgmPlaying = false;
        // 可选：自动重启
        playBgm();
      }
    });
  }

  Future<void> playBgm({String assetPath = 'assets/audio/bgm.mp3'}) async {
    await _init();
    if (_bgmPlaying) {
      return;
    }
    try {
      await _bgmPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        // iOS: AudioContextIOS(
        //   category: AVAudioSessionCategory.ambient,
        //   options: [AVAudioSessionOptions.mixWithOthers],
        // ),
      ));
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmVolume);
      await _bgmPlayer.play(AssetSource(assetPath));
      _bgmPlaying = true;
    } catch (e) {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        await _bgmPlayer.play(BytesSource(bytes));
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(bgmVolume);
        _bgmPlaying = true;
      } catch (e2) {
      }
    }
  }

  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
      _bgmPlaying = false;
    } catch (e) {
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _bgmPlaying = false;
    } catch (e) {
    }
  }

  Future<void> setBgmVolume(double volume) async {
    bgmVolume = volume.clamp(0.0, 1.0);
    try {
      await _bgmPlayer.setVolume(bgmVolume);
    } catch (e) {
    }
  }

  Future<void> _playSfx(String assetPath, [double? volume]) async {
    await _init();
    final effectiveVolume = volume ?? sfxVolume;
    try {
      final player = _sfxPlayers[_sfxIndex % _sfxPlayers.length];
      _sfxIndex++;
      await player.stop();
      await player.setVolume(effectiveVolume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        final player = _sfxPlayers[_sfxIndex % _sfxPlayers.length];
        _sfxIndex++;
        await player.stop();
        await player.setVolume(effectiveVolume);
        await player.play(BytesSource(bytes));
      } catch (e2) {
      }
    }
  }

  Future<void> playPlaceSound() async {
    await _playSfx('assets/audio/place_sound.wav');
  }

  Future<void> playSnapSound() async {
    await _playSfx('assets/audio/snap_sound.wav');
  }

  Future<void> playCustomEffect(String assetPath) async {
    await _playSfx(assetPath);
  }

  Future<void> playSuccessSound() async {
    await _playSfx('assets/audio/success_sound.wav', sfxVolume * 0.1);
  }

  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
      for (final p in _sfxPlayers) {
        await p.dispose();
      }
      _bgmPlaying = false;
    } catch (e) {
    }
  }
}
