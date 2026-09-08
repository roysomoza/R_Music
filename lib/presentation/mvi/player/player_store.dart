import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/repositories/i_audio_player_repository.dart';
import '../../../domain/repositories/i_music_repository.dart';
import 'player_effect.dart';
import 'player_intent.dart';
import 'player_state.dart';

/// MVI Store / State Machine managing audio playback, queue, sleep timer,
/// and reactive unidirectional data flow.
class PlayerStore {
  final IAudioPlayerRepository _playerRepo;
  final IMusicRepository? _musicRepo;

  final ValueNotifier<PlayerState> _stateNotifier =
      ValueNotifier<PlayerState>(const PlayerState());
  final StreamController<PlayerEffect> _effectController =
      StreamController<PlayerEffect>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  Timer? _sleepTimer;

  PlayerStore({
    required IAudioPlayerRepository playerRepo,
    IMusicRepository? musicRepo,
  })  : _playerRepo = playerRepo,
        _musicRepo = musicRepo {
    _bindEngineStreams();
  }

  /// Current immutable state snapshot
  PlayerState get state => _stateNotifier.value;

  /// ValueListenable for fine-grained, efficient Flutter widget rebuilds
  ValueListenable<PlayerState> get stateListenable => _stateNotifier;

  /// Reactive stream of single-shot UI side effects
  Stream<PlayerEffect> get effectStream => _effectController.stream;

  void _emit(PlayerState newState) {
    _stateNotifier.value = newState;
  }

  void _emitEffect(PlayerEffect effect) {
    if (!_effectController.isClosed) {
      _effectController.add(effect);
    }
  }

  /// Connects audio engine streams to the MVI state machine
  void _bindEngineStreams() {
    _subscriptions.add(
      _playerRepo.currentTrackStream.listen((track) {
        if (track != null) {
          _emit(state.copyWith(
            currentTrack: track,
            status: state.isPlaying ? PlaybackStatus.playing : state.status,
          ));
        }
      }),
    );

    _subscriptions.add(
      _playerRepo.positionStream.listen((pos) {
        _emit(state.copyWith(position: pos));
      }),
    );

    _subscriptions.add(
      _playerRepo.durationStream.listen((dur) {
        if (dur != null) {
          _emit(state.copyWith(duration: dur));
        }
      }),
    );

    _subscriptions.add(
      _playerRepo.isPlayingStream.listen((playing) {
        _emit(state.copyWith(
          status: playing ? PlaybackStatus.playing : PlaybackStatus.paused,
        ));
      }),
    );

    _subscriptions.add(
      _playerRepo.isBufferingStream.listen((buffering) {
        _emit(state.copyWith(isBuffering: buffering));
      }),
    );

    _subscriptions.add(
      _playerRepo.queueStream.listen((q) {
        _emit(state.copyWith(queue: q));
      }),
    );

    _subscriptions.add(
      _playerRepo.currentIndexStream.listen((idx) {
        _emit(state.copyWith(currentIndex: idx));
      }),
    );

    _subscriptions.add(
      _playerRepo.isShuffleStream.listen((shuffle) {
        _emit(state.copyWith(isShuffle: shuffle));
      }),
    );

    _subscriptions.add(
      _playerRepo.repeatModeStream.listen((repeat) {
        _emit(state.copyWith(repeatMode: repeat));
      }),
    );

    // Synchronize favorites if music repo is supplied
    if (_musicRepo != null) {
      _subscriptions.add(
        _musicRepo.favoritesStream.listen((favorites) {
          if (state.currentTrack != null) {
            final isFav = favorites.contains(state.currentTrack!.id);
            if (isFav != state.currentTrack!.isFavorite) {
              _emit(state.copyWith(
                currentTrack: state.currentTrack!.copyWith(isFavorite: isFav),
              ));
            }
          }
        }),
      );
    }
  }

  /// Dispatches a user intent to be processed by the reducer/engine.
  Future<void> dispatch(PlayerIntent intent) async {
    switch (intent) {
      case PlayTrackIntent(:final track, :final queue, :final initialIndex):
        final activeQueue = queue ?? (state.queue.isNotEmpty ? state.queue : [track]);
        final index = initialIndex ?? activeQueue.indexWhere((t) => t.id == track.id);
        final clampedIndex = index >= 0 ? index : 0;

        _emit(state.copyWith(
          currentTrack: track,
          queue: activeQueue,
          currentIndex: clampedIndex,
          status: PlaybackStatus.playing,
        ));

        await _playerRepo.setQueue(activeQueue, initialIndex: clampedIndex, autoPlay: true);
        break;

      case PlayQueueIntent(:final queue, :final initialIndex):
        if (queue.isEmpty) return;
        final clampedIndex = initialIndex.clamp(0, queue.length - 1);
        final initialTrack = queue[clampedIndex];

        _emit(state.copyWith(
          currentTrack: initialTrack,
          queue: queue,
          currentIndex: clampedIndex,
          status: PlaybackStatus.playing,
        ));

        await _playerRepo.setQueue(queue, initialIndex: clampedIndex, autoPlay: true);
        break;

      case PlayPauseIntent():
        if (state.isPlaying) {
          await _playerRepo.pause();
        } else {
          await _playerRepo.play();
        }
        break;

      case PauseIntent():
        await _playerRepo.pause();
        break;

      case ResumeIntent():
        await _playerRepo.play();
        break;

      case StopIntent():
        await _playerRepo.stop();
        _emit(state.copyWith(status: PlaybackStatus.stopped));
        break;

      case SeekIntent(:final position):
        _emit(state.copyWith(position: position));
        await _playerRepo.seek(position);
        break;

      case SkipToNextIntent():
        await _playerRepo.skipToNext();
        break;

      case SkipToPreviousIntent():
        await _playerRepo.skipToPrevious();
        break;

      case ToggleShuffleIntent():
        final newShuffle = !state.isShuffle;
        await _playerRepo.setShuffle(newShuffle);
        _emit(state.copyWith(isShuffle: newShuffle));
        break;

      case CycleRepeatModeIntent():
        final nextMode = switch (state.repeatMode) {
          RepeatMode.off => RepeatMode.all,
          RepeatMode.all => RepeatMode.one,
          RepeatMode.one => RepeatMode.off,
        };
        await _playerRepo.setRepeatMode(nextMode);
        _emit(state.copyWith(repeatMode: nextMode));
        break;

      case SetSleepTimerIntent(:final duration):
        _sleepTimer?.cancel();
        if (duration == null || duration <= Duration.zero) {
          _emit(state.copyWith(clearSleepTimer: true));
        } else {
          _emit(state.copyWith(sleepTimerRemaining: duration));
          _startSleepTimerCountdown(duration);
          _emitEffect(ShowToastEffect('Temporizador de apagado configurado para ${duration.inMinutes} min'));
        }
        break;

      case CancelSleepTimerIntent():
        _sleepTimer?.cancel();
        _emit(state.copyWith(clearSleepTimer: true));
        _emitEffect(const ShowToastEffect('Temporizador cancelado'));
        break;

      case SleepTimerTickIntent(:final remaining):
        if (remaining <= Duration.zero) {
          _sleepTimer?.cancel();
          _emit(state.copyWith(clearSleepTimer: true));
          await _playerRepo.pause();
          _emitEffect(const SleepTimerExpiredEffect());
        } else {
          _emit(state.copyWith(sleepTimerRemaining: remaining));
        }
        break;

      case SetVolumeIntent(:final volume):
        _emit(state.copyWith(volume: volume));
        await _playerRepo.setVolume(volume);
        break;

      case ToggleFavoriteCurrentIntent():
        if (state.currentTrack != null && _musicRepo != null) {
          await _musicRepo.toggleFavorite(state.currentTrack!.id);
        }
        break;
    }
  }

  void _startSleepTimerCountdown(Duration initialDuration) {
    var current = initialDuration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      current -= const Duration(seconds: 1);
      dispatch(SleepTimerTickIntent(current));
    });
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _effectController.close();
    _stateNotifier.dispose();
  }
}
