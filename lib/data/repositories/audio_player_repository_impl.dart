import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/platform/equalizer_channel.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/i_audio_player_repository.dart';

/// Concrete implementation of [IAudioPlayerRepository] integrating just_audio,
/// just_audio_background, and system media notifications.
class AudioPlayerRepositoryImpl implements IAudioPlayerRepository {
  final AudioPlayer _player;

  final StreamController<Track?> _currentTrackController =
      StreamController<Track?>.broadcast();
  final StreamController<List<Track>> _queueController =
      StreamController<List<Track>>.broadcast();
  final StreamController<int> _currentIndexController =
      StreamController<int>.broadcast();
  final StreamController<RepeatMode> _repeatModeController =
      StreamController<RepeatMode>.broadcast();

  List<Track> _queue = [];
  int _currentIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;
  final List<StreamSubscription> _subscriptions = [];

  AudioPlayerRepositoryImpl({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _initListeners();
  }

  void _initListeners() {
    // 1. Current Index synchronization
    _subscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (index != null && index >= 0 && index < _queue.length) {
          _currentIndex = index;
          _currentIndexController.add(_currentIndex);
          _currentTrackController.add(_queue[_currentIndex]);
        }
      }),
    );

    // 2. Playback completion listener to handle next or loop
    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          if (_repeatMode == RepeatMode.one) {
            _player.seek(Duration.zero);
            _player.play();
          }
        }
      }),
    );

    // 3. Audio session id listener for native equalizer integration
    _subscriptions.add(
      _player.androidAudioSessionIdStream.listen((sessionId) {
        if (sessionId != null) {
          EqualizerChannel.initEqualizer(sessionId);
        }
      }),
    );
  }

  @override
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get isPlayingStream => _player.playingStream;

  @override
  Stream<bool> get isBufferingStream => _player.playerStateStream.map(
        (state) =>
            state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading,
      );

  @override
  Stream<bool> get isShuffleStream => _player.shuffleModeEnabledStream;

  @override
  Stream<RepeatMode> get repeatModeStream => _repeatModeController.stream;

  @override
  Stream<List<Track>> get queueStream => _queueController.stream;

  @override
  Stream<int> get currentIndexStream => _currentIndexController.stream;

  @override
  Future<void> setQueue(
    List<Track> queue, {
    int initialIndex = 0,
    bool autoPlay = true,
  }) async {
    if (queue.isEmpty) return;

    _queue = List.from(queue);
    _currentIndex = initialIndex.clamp(0, _queue.length - 1);

    _queueController.add(List.unmodifiable(_queue));
    _currentIndexController.add(_currentIndex);
    _currentTrackController.add(_queue[_currentIndex]);

    final audioSources = _queue.map((track) {
      Uri? artUri;
      if (track.artworkPath != null && File(track.artworkPath!).existsSync()) {
        artUri = Uri.file(track.artworkPath!);
      }

      return AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          title: track.title,
          artist: track.artist,
          album: track.album,
          duration: track.duration > Duration.zero ? track.duration : null,
          artUri: artUri,
        ),
      );
    }).toList();

    try {
      await _player.setAudioSources(
        audioSources,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );

      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      debugPrint('Error setting concatenating audio source: $e');
      // Fallback: set single track
      try {
        final track = _queue[_currentIndex];
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.file(track.path),
            tag: MediaItem(
              id: track.path,
              title: track.title,
              artist: track.artist,
              album: track.album,
            ),
          ),
        );
        if (autoPlay) await _player.play();
      } catch (fallbackErr) {
        debugPrint('Fallback audio playback error: $fallbackErr');
      }
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Audio pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Audio seek error: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      } else if (_queue.isNotEmpty && _repeatMode == RepeatMode.all) {
        await _player.seek(Duration.zero, index: 0);
      }
    } catch (e) {
      debugPrint('Audio skipToNext error: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      } else if (_queue.isNotEmpty && _repeatMode == RepeatMode.all) {
        await _player.seek(Duration.zero, index: _queue.length - 1);
      } else {
        await _player.seek(Duration.zero);
      }
    } catch (e) {
      debugPrint('Audio skipToPrevious error: $e');
    }
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    try {
      await _player.setShuffleModeEnabled(enabled);
      if (enabled) {
        await _player.shuffle();
      }
    } catch (e) {
      debugPrint('Audio setShuffle error: $e');
    }
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
    _repeatModeController.add(_repeatMode);

    switch (mode) {
      case RepeatMode.off:
        await _player.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Audio setVolume error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _currentTrackController.close();
    await _queueController.close();
    await _currentIndexController.close();
    await _repeatModeController.close();
    await _player.dispose();
  }
}
