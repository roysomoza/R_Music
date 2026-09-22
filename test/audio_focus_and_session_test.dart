import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pure_audio/data/repositories/audio_player_repository_impl.dart';

class MockAudioPlayer implements AudioPlayer {
  bool _playing = false;
  double _volume = 1.0;
  bool playCalled = false;
  bool pauseCalled = false;
  bool stopCalled = false;

  final StreamController<int?> _currentIndexController =
      StreamController<int?>.broadcast();
  final StreamController<PlayerState> _playerStateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<int?> _androidAudioSessionIdController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<PlaybackEvent> _playbackEventController =
      StreamController<PlaybackEvent>.broadcast();

  @override
  bool get playing => _playing;

  set playing(bool val) {
    _playing = val;
    _playingController.add(val);
  }

  @override
  double get volume => _volume;

  Duration _position = Duration.zero;
  bool seekCalled = false;
  Duration? lastSeekPosition;
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  @override
  Duration get position => _position;

  set position(Duration val) {
    _position = val;
    _positionController.add(val);
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seekCalled = true;
    lastSeekPosition = position;
    if (position != null) {
      _position = position;
      _positionController.add(position);
    }
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventController.stream;

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<int?> get androidAudioSessionIdStream =>
      _androidAudioSessionIdController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Future<void> play() async {
    playCalled = true;
    _playing = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    _playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    _playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> dispose() async {
    await _currentIndexController.close();
    await _playerStateController.close();
    await _androidAudioSessionIdController.close();
    await _playingController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioSession & Audio Focus Management Tests', () {
    late MockAudioPlayer mockPlayer;
    late AudioPlayerRepositoryImpl repo;

    setUp(() {
      mockPlayer = MockAudioPlayer();
      repo = AudioPlayerRepositoryImpl(player: mockPlayer);
    });

    tearDown(() async {
      await repo.dispose();
    });

    test('Initial audio focus and interruption state is clean', () {
      expect(repo.userVolume, equals(1.0));
      expect(repo.isDucked, isFalse);
      expect(repo.playOnResume, isFalse);
      expect(repo.isInterrupted, isFalse);
    });

    test('Audio Ducking: lowers volume to 25% on begin and restores on end without pausing', () async {
      mockPlayer.playing = true;
      await repo.setVolume(1.0);
      expect(mockPlayer.volume, equals(1.0));

      // 1. Transient notification arrives (duck begins)
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );

      expect(repo.isDucked, isTrue);
      expect(mockPlayer.volume, closeTo(0.25, 0.001));
      expect(repo.userVolume, equals(1.0));
      expect(mockPlayer.pauseCalled, isFalse, reason: 'Ducking must NOT pause playback');

      // 2. Notification ends (duck ends)
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );

      expect(repo.isDucked, isFalse);
      expect(mockPlayer.volume, closeTo(1.0, 0.001));
      expect(repo.userVolume, equals(1.0));
    });

    test('Audio Ducking: dynamically tracks user volume adjustments made while ducked', () async {
      await repo.setVolume(0.8);
      expect(mockPlayer.volume, closeTo(0.8, 0.001));

      // Duck begins
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      expect(mockPlayer.volume, closeTo(0.8 * 0.25, 0.001));

      // User changes volume to 0.6 while ducked
      await repo.setVolume(0.6);
      expect(repo.userVolume, closeTo(0.6, 0.001));
      expect(mockPlayer.volume, closeTo(0.6 * 0.25, 0.001));

      // Duck ends
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(repo.isDucked, isFalse);
      expect(mockPlayer.volume, closeTo(0.6, 0.001));
    });

    test('Exclusive Interruption (Phone Call): pauses when playing and auto-resumes on end', () async {
      mockPlayer.playing = true;

      // 1. Phone call begins
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );

      expect(repo.isInterrupted, isTrue);
      expect(repo.playOnResume, isTrue, reason: 'Was playing, must remember to resume');
      expect(mockPlayer.pauseCalled, isTrue);

      // 2. Phone call ends
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );

      expect(repo.isInterrupted, isFalse);
      expect(repo.playOnResume, isFalse);
      expect(mockPlayer.playCalled, isTrue, reason: 'Must resume playback automatically');
    });

    test('Exclusive Interruption (Phone Call): stays paused if user was already paused before call', () async {
      mockPlayer.playing = false;

      // 1. Phone call begins while already paused
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );

      expect(repo.isInterrupted, isTrue);
      expect(repo.playOnResume, isFalse, reason: 'Was paused, must NOT flag to resume');

      // 2. Phone call ends
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );

      expect(repo.isInterrupted, isFalse);
      expect(repo.playOnResume, isFalse);
      expect(mockPlayer.playCalled, isFalse, reason: 'Must remain paused');
    });

    test('Manual Pause cancels auto-resume when interruption ends', () async {
      mockPlayer.playing = true;

      // 1. Interruption begins
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(repo.playOnResume, isTrue);

      // 2. User manually pauses during interruption
      await repo.pause();
      expect(repo.playOnResume, isFalse, reason: 'Manual pause clears playOnResume');

      // 3. Interruption ends
      mockPlayer.playCalled = false;
      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );

      expect(mockPlayer.playCalled, isFalse, reason: 'Should not resume after manual pause');
    });

    test('Becoming Noisy (Headphones Disconnect): pauses and prevents auto-resume', () async {
      mockPlayer.playing = true;

      repo.handleBecomingNoisyEvent();

      expect(repo.playOnResume, isFalse);
      expect(mockPlayer.pauseCalled, isTrue);
    });

    test('Unknown Interruption (Permanent loss/Spotify): pauses and handles lifecycle', () async {
      mockPlayer.playing = true;

      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );

      expect(repo.isInterrupted, isTrue);
      expect(repo.playOnResume, isTrue);
      expect(mockPlayer.pauseCalled, isTrue);

      await repo.handleInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.unknown),
      );

      expect(repo.isInterrupted, isFalse);
      expect(repo.playOnResume, isFalse);
      expect(mockPlayer.playCalled, isTrue);
    });

    test('Bluetooth Reconnect / Hardware Clock Reset Anchor: restores lastKnownPosition', () async {
      // 1. Simulate playing at 2 minutes and 15 seconds
      mockPlayer.position = const Duration(minutes: 2, seconds: 15);
      await pumpEventQueue();
      expect(repo.lastKnownPosition, equals(const Duration(minutes: 2, seconds: 15)));

      // 2. Pause on disconnect (becoming noisy)
      repo.handleBecomingNoisyEvent();
      expect(mockPlayer.pauseCalled, isTrue);
      expect(repo.lastKnownPosition, equals(const Duration(minutes: 2, seconds: 15)));

      // 3. Simulate hardware reset (position drops to 00:00 during Bluetooth reconnection)
      mockPlayer.position = Duration.zero;
      mockPlayer.seekCalled = false;

      // 4. Trigger play() on reconnect
      await repo.play();

      // 5. Verify that corrective seek restored the anchor position before playing
      expect(mockPlayer.seekCalled, isTrue);
      expect(mockPlayer.lastSeekPosition, equals(const Duration(minutes: 2, seconds: 15)));
      expect(mockPlayer.playCalled, isTrue);
    });
  });
}
