import '../../../domain/entities/track.dart';
import '../../../domain/repositories/i_audio_player_repository.dart';

enum PlaybackStatus { stopped, playing, paused, completed }

/// Immutable state representation for the Audio Player MVI architecture.
class PlayerState {
  final Track? currentTrack;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final int currentIndex;
  final bool isShuffle;
  final RepeatMode repeatMode;
  final bool isBuffering;
  final Duration? sleepTimerRemaining;
  final double volume;
  final String? errorMessage;

  const PlayerState({
    this.currentTrack,
    this.status = PlaybackStatus.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.isShuffle = false,
    this.repeatMode = RepeatMode.off,
    this.isBuffering = false,
    this.sleepTimerRemaining,
    this.volume = 1.0,
    this.errorMessage,
  });

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isPaused => status == PlaybackStatus.paused;
  bool get isStopped => status == PlaybackStatus.stopped;
  bool get isSleepTimerActive =>
      sleepTimerRemaining != null && sleepTimerRemaining! > Duration.zero;

  bool get hasNext =>
      queue.isNotEmpty &&
      (currentIndex < queue.length - 1 || repeatMode == RepeatMode.all);

  bool get hasPrevious =>
      queue.isNotEmpty &&
      (currentIndex > 0 || repeatMode == RepeatMode.all || position.inSeconds > 3);

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    Track? currentTrack,
    bool clearCurrentTrack = false,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    List<Track>? queue,
    int? currentIndex,
    bool? isShuffle,
    RepeatMode? repeatMode,
    bool? isBuffering,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
    double? volume,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlayerState(
      currentTrack:
          clearCurrentTrack ? null : (currentTrack ?? this.currentTrack),
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      isBuffering: isBuffering ?? this.isBuffering,
      sleepTimerRemaining: clearSleepTimer
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      volume: volume ?? this.volume,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          currentTrack?.id == other.currentTrack?.id &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          currentIndex == other.currentIndex &&
          isShuffle == other.isShuffle &&
          repeatMode == other.repeatMode &&
          isBuffering == other.isBuffering &&
          sleepTimerRemaining == other.sleepTimerRemaining &&
          volume == other.volume;

  @override
  int get hashCode =>
      (currentTrack?.id.hashCode ?? 0) ^
      status.hashCode ^
      position.hashCode ^
      duration.hashCode ^
      currentIndex.hashCode ^
      isShuffle.hashCode ^
      repeatMode.hashCode ^
      isBuffering.hashCode ^
      sleepTimerRemaining.hashCode ^
      volume.hashCode;

  @override
  String toString() {
    return 'PlayerState(track: ${currentTrack?.title}, status: $status, pos: ${position.inSeconds}/${duration.inSeconds}, queue: ${queue.length})';
  }
}
