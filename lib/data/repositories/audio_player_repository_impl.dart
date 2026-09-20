import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/platform/equalizer_channel.dart';
import '../../core/platform/permission_handler_service.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/i_audio_player_repository.dart';

/// Concrete implementation of [IAudioPlayerRepository] integrating just_audio,
/// just_audio_background, system media notifications, and full AudioSession /
/// Audio Focus management (transient/permanent interruptions, ducking, becoming noisy).
class AudioPlayerRepositoryImpl implements IAudioPlayerRepository {
  final AudioPlayer _player;
  AudioSession? _audioSession;
  late final Future<AudioSession> _sessionFuture;

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

  // Audio Focus & Interruption management state
  double _userVolume = 1.0;
  bool _isDucked = false;
  bool _playOnResume = false;
  bool _isInterrupted = false;

  AudioPlayerRepositoryImpl({
    AudioPlayer? player,
    AudioSession? session,
  }) : _player = player ?? AudioPlayer() {
    _sessionFuture =
        session != null ? Future.value(session) : AudioSession.instance;
    _initListeners();
    _initAudioSession();
  }

  /// Configures AudioSession for music playback with appropriate Android/iOS audio attributes.
  Future<void> _initAudioSession() async {
    try {
      final session = await _sessionFuture;
      _audioSession = session;

      await session.configure(
        const AudioSessionConfiguration.music().copyWith(
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      // Subscribe to audio focus interruptions (calls, other media apps, ducking)
      _subscriptions.add(
        session.interruptionEventStream.listen(_handleInterruption),
      );

      // Subscribe to headphone / Bluetooth disconnection events
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) => _handleBecomingNoisy()),
      );
    } catch (e) {
      debugPrint('Error configuring AudioSession: $e');
    }
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

    // 4. Playing state listener for AudioSession activation and user pause tracking
    _subscriptions.add(
      _player.playingStream.listen((playing) async {
        if (playing) {
          try {
            final session = _audioSession ?? await _sessionFuture;
            await session.setActive(true);
          } catch (e) {
            debugPrint('Error activating AudioSession on playing stream: $e');
          }
        } else if (!_isInterrupted) {
          // If paused by user/external trigger while not interrupted, do not resume later
          _playOnResume = false;
        }
      }),
    );
  }

  /// Handles audio focus interruptions from other apps or system events.
  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    debugPrint('AudioInterruptionEvent: begin=${event.begin}, type=${event.type}');

    if (event.type == AudioInterruptionType.duck) {
      if (event.begin) {
        // Transient duckable interruption (notifications, messages, WhatsApp sounds).
        // DO NOT pause; lower volume to ~25% of current volume.
        _isDucked = true;
        await _player.setVolume((_userVolume * 0.25).clamp(0.0, 1.0));
      } else {
        // Ducking ended: restore user-configured volume immediately.
        _isDucked = false;
        await _player.setVolume(_userVolume.clamp(0.0, 1.0));
      }
    } else if (event.type == AudioInterruptionType.pause ||
        event.type == AudioInterruptionType.unknown) {
      if (event.begin) {
        // Exclusive focus loss (phone calls, YouTube, Spotify, etc.)
        _isInterrupted = true;
        _playOnResume = _player.playing;
        if (_playOnResume) {
          try {
            await _player.pause();
          } catch (e) {
            debugPrint('Error pausing during audio interruption: $e');
          }
        }
      } else {
        // Interruption ended: resume only if track was playing prior to interruption
        _isInterrupted = false;
        if (_playOnResume) {
          _playOnResume = false;
          await play();
        }
      }
    }
  }

  /// Handles becoming noisy event (headphone / Bluetooth disconnect).
  void _handleBecomingNoisy() {
    debugPrint('Audio becoming noisy: headphones disconnected. Pausing playback.');
    _playOnResume = false;
    pause();
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
        await play();
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
        if (autoPlay) await play();
      } catch (fallbackErr) {
        debugPrint('Fallback audio playback error: $fallbackErr');
      }
    }
  }

  @override
  Future<void> play() async {
    _playOnResume = false;
    try {
      if (Platform.isAndroid) {
        await PermissionHandlerService.requestNotificationPermission();
      }
      final session = _audioSession ?? await _sessionFuture;
      final activated = await session.setActive(true);
      if (!activated) {
        debugPrint('AudioSession focus request was rejected');
        return;
      }
      await _player.play();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Future<void> pause() async {
    _playOnResume = false;
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Audio pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    _playOnResume = false;
    try {
      await _player.stop();
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }
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
    _userVolume = volume.clamp(0.0, 1.0);
    try {
      if (_isDucked) {
        await _player.setVolume((_userVolume * 0.25).clamp(0.0, 1.0));
      } else {
        await _player.setVolume(_userVolume);
      }
    } catch (e) {
      debugPrint('Audio setVolume error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _currentTrackController.close();
    await _queueController.close();
    await _currentIndexController.close();
    await _repeatModeController.close();
    if (_audioSession != null) {
      try {
        await _audioSession!.setActive(false);
      } catch (e) {
        debugPrint('Error deactivating AudioSession: $e');
      }
    }
    await _player.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Visible For Testing Hooks
  // ══════════════════════════════════════════════════════════════════════════

  @visibleForTesting
  bool get playOnResume => _playOnResume;

  @visibleForTesting
  bool get isDucked => _isDucked;

  @visibleForTesting
  bool get isInterrupted => _isInterrupted;

  @visibleForTesting
  double get userVolume => _userVolume;

  @visibleForTesting
  Future<void> handleInterruptionEvent(AudioInterruptionEvent event) =>
      _handleInterruption(event);

  @visibleForTesting
  void handleBecomingNoisyEvent() => _handleBecomingNoisy();
}
