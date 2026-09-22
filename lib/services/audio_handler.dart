import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Professional AudioHandler implementation running independently from the UI Widget tree.
/// Provides buffer retention, anchor protection against sample clock resets on Bluetooth connect/disconnect,
/// and proper audio focus and becoming noisy handling.
class SafeAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  AudioSession? _session;
  final Future<AudioSession> _sessionFuture;

  // Position anchor to prevent resetting to 00:00 on Bluetooth sample clock shifts
  Duration _lastKnownPosition = Duration.zero;
  bool _wasPlayingBeforeInterruption = false;
  final List<StreamSubscription> _subscriptions = [];

  SafeAudioHandler({
    AudioPlayer? player,
    AudioSession? session,
  })  : _player = player ?? AudioPlayer(),
        _sessionFuture =
            session != null ? Future.value(session) : AudioSession.instance {
    _initAudioSession();
    _listenToPlayerEvents();
  }

  AudioPlayer get player => _player;
  Duration get lastKnownPosition => _lastKnownPosition;

  Future<void> _initAudioSession() async {
    try {
      final session = await _sessionFuture;
      _session = session;

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

      // 1. Becoming Noisy (Headphones or Bluetooth disconnected)
      // MUST pause, NEVER stop, preserving ExoPlayer buffer and last position
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) async {
          debugPrint('[SafeAudioHandler] Becoming Noisy detected (Bluetooth/Headphones disconnected).');
          _wasPlayingBeforeInterruption = _player.playing;
          _lastKnownPosition = _player.position;
          await pause();
        }),
      );

      // 2. Audio focus interruptions (Phone calls, alarms, ducking)
      _subscriptions.add(
        session.interruptionEventStream.listen((event) async {
          debugPrint('[SafeAudioHandler] AudioInterruptionEvent: begin=${event.begin}, type=${event.type}');
          if (event.begin) {
            _wasPlayingBeforeInterruption = _player.playing;
            _lastKnownPosition = _player.position;

            if (event.type == AudioInterruptionType.pause ||
                event.type == AudioInterruptionType.unknown) {
              await pause();
            } else if (event.type == AudioInterruptionType.duck) {
              await _player.setVolume(0.25);
            }
          } else {
            if (event.type == AudioInterruptionType.duck) {
              await _player.setVolume(1.0);
            } else if (_wasPlayingBeforeInterruption) {
              _wasPlayingBeforeInterruption = false;
              await play();
            }
          }
        }),
      );
    } catch (e) {
      debugPrint('[SafeAudioHandler] Error configuring AudioSession: $e');
    }
  }

  void _listenToPlayerEvents() {
    // Sincronizar posición continua y almacenar el ancla de seguridad
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        if (pos > Duration.zero) {
          _lastKnownPosition = pos;
        }
        _broadcastState();
      }),
    );

    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        _broadcastState();
      }),
    );
  }

  void _broadcastState() {
    final processingStateMap = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingStateMap[_player.processingState] ?? AudioProcessingState.idle,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() async {
    try {
      final session = _session ?? await _sessionFuture;
      final focusGranted = await session.setActive(true);
      if (!focusGranted) {
        debugPrint('[SafeAudioHandler] AudioFocus request rejected by system.');
        return;
      }

      // LÓGICA DE ANCLAJE: Si el hardware/controlador Bluetooth reinició accidentalmente la posición
      // cerca de 0 (< 300ms) habiendo una posición previa válida (> 1s), ejecutar seek preventivo.
      final currentPos = _player.position;
      if (_lastKnownPosition > const Duration(seconds: 1) &&
          currentPos < const Duration(milliseconds: 300)) {
        debugPrint('[SafeAudioHandler] Hardware clock reset detected during reconnect. Restoring position: $_lastKnownPosition');
        await _player.seek(_lastKnownPosition);
      }

      await _player.play();
    } catch (e) {
      debugPrint('[SafeAudioHandler] Error in play(): $e');
    }
  }

  @override
  Future<void> pause() async {
    _lastKnownPosition = _player.position;
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('[SafeAudioHandler] Error in pause(): $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _lastKnownPosition = position;
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('[SafeAudioHandler] Error in seek(): $e');
    }
  }

  @override
  Future<void> stop() async {
    _lastKnownPosition = Duration.zero;
    try {
      await _player.stop();
      final session = _session ?? await _sessionFuture;
      await session.setActive(false);
    } catch (e) {
      debugPrint('[SafeAudioHandler] Error in stop(): $e');
    }
    await super.stop();
  }

  Future<void> customDispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _player.dispose();
  }
}
