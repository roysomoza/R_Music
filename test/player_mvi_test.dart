import 'dart:async';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/domain/entities/track.dart';
import 'package:pure_audio/domain/repositories/i_audio_player_repository.dart';
import 'package:pure_audio/domain/repositories/i_music_repository.dart';
import 'package:pure_audio/models/track_model.dart';
import 'package:pure_audio/presentation/mvi/player/player_effect.dart';
import 'package:pure_audio/presentation/mvi/player/player_intent.dart';
import 'package:pure_audio/presentation/mvi/player/player_state.dart';
import 'package:pure_audio/presentation/mvi/player/player_store.dart';
import 'package:pure_audio/widgets/player_dock.dart';

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
  final StreamController<String> _errorController = StreamController<String>.broadcast();

  bool isPlaying = false;
  Duration currentPos = Duration.zero;
  RepeatMode currentRepeat = RepeatMode.off;
  bool isShuffle = false;

  void emitError(String message) => _errorController.add(message);

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
  Stream<String> get playbackErrorStream => _errorController.stream;

  @override
  Future<void> setQueue(List<Track> queue, {int initialIndex = 0, bool autoPlay = true, bool preload = true}) async {
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
    await _errorController.close();
  }
}

class FakeMusicRepository implements IMusicRepository {
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();
  Set<String> favorites = {};

  @override
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;

  @override
  Future<void> toggleFavorite(String trackId) async {
    if (favorites.contains(trackId)) {
      favorites.remove(trackId);
    } else {
      favorites.add(trackId);
    }
    _favoritesController.add(Set.from(favorites));
  }

  @override
  Future<bool> isFavorite(String trackId) async => favorites.contains(trackId);

  @override
  Future<Set<String>> getFavorites() async => Set.from(favorites);

  @override
  Future<void> dispose() async {
    await _favoritesController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

    test('RestorePlaybackIntent populates queue and current track in paused state without autoPlay', () async {
      final track2 = Track(
        id: 'track_2',
        path: '/storage/music/CyberPulse.mp3',
        title: 'Cyber Pulse',
        artist: 'Pure Audio',
        duration: const Duration(seconds: 180),
        dateAdded: DateTime.now(),
      );
      final queue = [testTrack, track2];

      await store.dispatch(RestorePlaybackIntent(queue: queue, initialIndex: 1));

      expect(store.state.currentTrack, equals(track2));
      expect(store.state.queue.length, equals(2));
      expect(store.state.currentIndex, equals(1));
      expect(store.state.status, equals(PlaybackStatus.paused));
      expect(store.state.isPlaying, isFalse);
      expect(fakeRepo.isPlaying, isFalse);
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

  group('PlayerDock MVI State Synchronization Widget Tests', () {
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

    testWidgets('PlayerDock is hidden with SizedBox.shrink when state has no track', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(store: store),
        ),
      ));

      expect(find.text('Neon Odyssey'), findsNothing);
      expect(find.byType(PlayerDock), findsOneWidget);
    });

    testWidgets('PlayerDock renders immediately when RestorePlaybackIntent is dispatched', (tester) async {
      await store.dispatch(RestorePlaybackIntent(queue: [testTrack], initialIndex: 0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(store: store),
        ),
      ));
      await tester.pump();

      expect(find.text('Neon Odyssey'), findsOneWidget);
      expect(find.text('Pure Audio'), findsOneWidget);
    });

    testWidgets('PlayerDock falls back to currentTrack parameter if store has not yet populated currentTrack', (tester) async {
      final modelTrack = TrackModel(
        id: 'track_model_1',
        path: '/storage/music/ModelTrack.mp3',
        title: 'Fallback Odyssey',
        artist: 'Fallback Artist',
        duration: const Duration(seconds: 200),
        dateAdded: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(store: store, currentTrack: modelTrack),
        ),
      ));
      await tester.pump();

      expect(find.text('Fallback Odyssey'), findsOneWidget);
      expect(find.text('Fallback Artist'), findsOneWidget);
    });
  });

  group('Favorites Synchronization (SSOT) & PlayerStore Tests', () {
    late FakeAudioPlayerRepository fakeAudioRepo;
    late FakeMusicRepository fakeMusicRepo;
    late PlayerStore store;

    final testTrack = Track(
      id: 'track_fav_1',
      path: '/storage/music/FavoriteSong.mp3',
      title: 'Favorite Song',
      artist: 'Pure Audio',
      duration: const Duration(seconds: 210),
      dateAdded: DateTime.now(),
      isFavorite: false,
    );

    setUp(() {
      fakeAudioRepo = FakeAudioPlayerRepository();
      fakeMusicRepo = FakeMusicRepository();
      store = PlayerStore(playerRepo: fakeAudioRepo, musicRepo: fakeMusicRepo);
    });

    tearDown(() async {
      await store.dispose();
      await fakeAudioRepo.dispose();
      await fakeMusicRepo.dispose();
    });

    test('ToggleFavoriteCurrentIntent dispatches track id and updates store state reactively', () async {
      await store.dispatch(PlayTrackIntent(testTrack));
      expect(store.state.currentTrack?.isFavorite, isFalse);

      await store.dispatch(const ToggleFavoriteCurrentIntent());
      expect(fakeMusicRepo.favorites.contains(testTrack.id), isTrue);
      expect(store.state.currentTrack?.isFavorite, isTrue);

      await store.dispatch(const ToggleFavoriteCurrentIntent());
      expect(fakeMusicRepo.favorites.contains(testTrack.id), isFalse);
      expect(store.state.currentTrack?.isFavorite, isFalse);
    });

    test('External favorites updates (e.g. from TrackTile/list) update PlayerStore currentTrack immediately', () async {
      await store.dispatch(PlayTrackIntent(testTrack));
      expect(store.state.currentTrack?.isFavorite, isFalse);

      // Simulates list toggling the track via repository
      await fakeMusicRepo.toggleFavorite(testTrack.id);
      await Future<void>.delayed(Duration.zero);

      expect(store.state.currentTrack?.isFavorite, isTrue);

      // Simulates list untoggling the track via repository
      await fakeMusicRepo.toggleFavorite(testTrack.id);
      await Future<void>.delayed(Duration.zero);

      expect(store.state.currentTrack?.isFavorite, isFalse);
    });

    testWidgets('PlayerDock heart icon updates when favorite status changes', (tester) async {
      await store.dispatch(RestorePlaybackIntent(queue: [testTrack], initialIndex: 0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(store: store),
        ),
      ));
      await tester.pump();

      // Initially not favorite: favorite_border
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Toggle favorite via Intent
      await store.dispatch(const ToggleFavoriteCurrentIntent());
      await tester.pump();

      // Now favorite: favorite_rounded (filled red)
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('PlayerDock repeat button cycles RepeatMode and updates icon', (tester) async {
      await store.dispatch(RestorePlaybackIntent(queue: [testTrack], initialIndex: 0));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(store: store),
        ),
      ));
      await tester.pump();

      // Initially repeat off: Icons.repeat_rounded
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);

      // Tap repeat button -> cycles to RepeatMode.all
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pumpAndSettle();

      expect(store.state.repeatMode, equals(RepeatMode.all));
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);

      // Tap repeat button again -> cycles to RepeatMode.one
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      await tester.pumpAndSettle();

      expect(store.state.repeatMode, equals(RepeatMode.one));
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);

      // Tap repeat button again -> cycles back to RepeatMode.off
      await tester.tap(find.byIcon(Icons.repeat_one_rounded));
      await tester.pumpAndSettle();

      expect(store.state.repeatMode, equals(RepeatMode.off));
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);
    });

    test('Playback error events from repository emit ShowErrorEffect on store effectStream', () async {
      PlayerEffect? receivedEffect;
      final sub = store.effectStream.listen((effect) {
        receivedEffect = effect;
      });

      fakeAudioRepo.emitError('Error al reproducir "Cancion": archivo no encontrado o dañado.');
      await Future<void>.delayed(Duration.zero);

      expect(receivedEffect, isA<ShowErrorEffect>());
      expect((receivedEffect as ShowErrorEffect).message,
          equals('Error al reproducir "Cancion": archivo no encontrado o dañado.'));

      await sub.cancel();
    });

    testWidgets('PlayerDock tapping artwork or track info triggers onExpandPlayer', (tester) async {
      await store.dispatch(RestorePlaybackIntent(queue: [testTrack], initialIndex: 0));

      bool expandedTriggered = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDock(
            store: store,
            onExpandPlayer: () {
              expandedTriggered = true;
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap title
      await tester.tap(find.text(testTrack.title));
      await tester.pump();
      expect(expandedTriggered, isTrue);

      // Reset and tap artist
      expandedTriggered = false;
      await tester.tap(find.text(testTrack.artist));
      await tester.pump();
      expect(expandedTriggered, isTrue);
    });
  });
}
