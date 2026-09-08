import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/domain/entities/track.dart';
import 'package:pure_audio/domain/repositories/i_audio_player_repository.dart';
import 'package:pure_audio/presentation/mvi/player/player_intent.dart';
import 'package:pure_audio/presentation/mvi/player/player_state.dart';
import 'package:pure_audio/presentation/mvi/player/player_store.dart';

class FakeAudioPlayerRepository implements IAudioPlayerRepository {
  final StreamController<Track?> _currentTrackController = StreamController<Track?>.broadcast();
  final StreamController<Duration> _posController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durController = StreamController<Duration?>.broadcast();
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();
  final StreamController<bool> _shuffleController = StreamController<bool>.broadcast();
  final StreamController<RepeatMode> _repeatController = StreamController<RepeatMode>.broadcast();
  final StreamController<List<Track>> _queueController = StreamController<List<Track>>.broadcast();
  final StreamController<int> _indexController = StreamController<int>.broadcast();

  bool isPlaying = false;
  Duration currentPos = Duration.zero;
  RepeatMode currentRepeat = RepeatMode.off;
  bool isShuffle = false;

  @override
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Stream<Duration?> get durationStream => _durController.stream;

  @override
  Stream<bool> get isPlayingStream => _playingController.stream;

  @override
  Stream<bool> get isBufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get isShuffleStream => _shuffleController.stream;

  @override
  Stream<RepeatMode> get repeatModeStream => _repeatController.stream;

  @override
  Stream<List<Track>> get queueStream => _queueController.stream;

  @override
  Stream<int> get currentIndexStream => _indexController.stream;

  @override
  Future<void> setQueue(List<Track> queue, {int initialIndex = 0, bool autoPlay = true}) async {
    _queueController.add(queue);
    _indexController.add(initialIndex);
    if (queue.isNotEmpty) {
      _currentTrackController.add(queue[initialIndex]);
    }
    if (autoPlay) {
      isPlaying = true;
      _playingController.add(true);
    }
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPos = position;
    _posController.add(position);
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> setShuffle(bool enabled) async {
    isShuffle = enabled;
    _shuffleController.add(enabled);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    currentRepeat = mode;
    _repeatController.add(mode);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _currentTrackController.close();
    await _posController.close();
    await _durController.close();
    await _playingController.close();
    await _bufferingController.close();
    await _shuffleController.close();
    await _repeatController.close();
    await _queueController.close();
    await _indexController.close();
  }
}

void main() {
  group('MVI PlayerStore Unit Tests', () {
    late FakeAudioPlayerRepository fakeRepo;
    late PlayerStore store;

    final testTrack = Track(
      id: 'track_1',
      path: '/storage/music/TestTrack.mp3',
      title: 'Neon Odyssey',
      artist: 'Pure Audio',
      duration: const Duration(seconds: 240),
      dateAdded: DateTime.now(),
    );

    setUp(() {
      fakeRepo = FakeAudioPlayerRepository();
      store = PlayerStore(playerRepo: fakeRepo);
    });

    tearDown(() async {
      await store.dispose();
      await fakeRepo.dispose();
    });

    test('Initial state is stopped with empty queue', () {
      expect(store.state.status, equals(PlaybackStatus.stopped));
      expect(store.state.currentTrack, isNull);
      expect(store.state.queue, isEmpty);
      expect(store.state.isPlaying, isFalse);
    });

    test('PlayTrackIntent updates state and starts playback', () async {
      await store.dispatch(PlayTrackIntent(testTrack));

      expect(store.state.currentTrack, equals(testTrack));
      expect(store.state.queue.length, equals(1));
      expect(store.state.currentIndex, equals(0));
      expect(store.state.isPlaying, isTrue);
    });

    test('SeekIntent updates state position', () async {
      await store.dispatch(PlayTrackIntent(testTrack));
      await store.dispatch(const SeekIntent(Duration(seconds: 45)));

      expect(store.state.position, equals(const Duration(seconds: 45)));
    });

    test('CycleRepeatModeIntent toggles off -> all -> one -> off', () async {
      expect(store.state.repeatMode, equals(RepeatMode.off));

      await store.dispatch(const CycleRepeatModeIntent());
      expect(store.state.repeatMode, equals(RepeatMode.all));

      await store.dispatch(const CycleRepeatModeIntent());
      expect(store.state.repeatMode, equals(RepeatMode.one));

      await store.dispatch(const CycleRepeatModeIntent());
      expect(store.state.repeatMode, equals(RepeatMode.off));
    });

    test('ToggleShuffleIntent flips shuffle state', () async {
      expect(store.state.isShuffle, isFalse);

      await store.dispatch(const ToggleShuffleIntent());
      expect(store.state.isShuffle, isTrue);

      await store.dispatch(const ToggleShuffleIntent());
      expect(store.state.isShuffle, isFalse);
    });

    test('Sleep Timer configures duration and cancels cleanly', () async {
      expect(store.state.isSleepTimerActive, isFalse);

      await store.dispatch(const SetSleepTimerIntent(Duration(minutes: 15)));
      expect(store.state.isSleepTimerActive, isTrue);
      expect(store.state.sleepTimerRemaining, equals(const Duration(minutes: 15)));

      await store.dispatch(const CancelSleepTimerIntent());
      expect(store.state.isSleepTimerActive, isFalse);
      expect(store.state.sleepTimerRemaining, isNull);
    });
  });
}
