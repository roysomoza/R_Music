import '../../../domain/entities/track.dart';

/// Base class for all user intents dispatched to the Player MVI Store.
sealed class PlayerIntent {
  const PlayerIntent();
}

/// Dispatched when the user taps on a track to play it with an optional queue.
class PlayTrackIntent extends PlayerIntent {
  final Track track;
  final List<Track>? queue;
  final int? initialIndex;

  const PlayTrackIntent(
    this.track, {
    this.queue,
    this.initialIndex,
  });
}

/// Dispatched when playing an entire playlist/queue starting at a given index.
class PlayQueueIntent extends PlayerIntent {
  final List<Track> queue;
  final int initialIndex;

  const PlayQueueIntent(this.queue, {this.initialIndex = 0});
}

/// Toggles between Play and Pause.
class PlayPauseIntent extends PlayerIntent {
  const PlayPauseIntent();
}

/// Pauses current playback.
class PauseIntent extends PlayerIntent {
  const PauseIntent();
}

/// Resumes current playback.
class ResumeIntent extends PlayerIntent {
  const ResumeIntent();
}

/// Stops playback and clears audio buffer.
class StopIntent extends PlayerIntent {
  const StopIntent();
}

/// Seeks playback to the requested position.
class SeekIntent extends PlayerIntent {
  final Duration position;
  const SeekIntent(this.position);
}

/// Skips to the next track in the queue.
class SkipToNextIntent extends PlayerIntent {
  const SkipToNextIntent();
}

/// Skips to the previous track or restarts the current track.
class SkipToPreviousIntent extends PlayerIntent {
  const SkipToPreviousIntent();
}

/// Toggles shuffle mode on/off.
class ToggleShuffleIntent extends PlayerIntent {
  const ToggleShuffleIntent();
}

/// Cycles repeat modes: Off -> All -> One -> Off.
class CycleRepeatModeIntent extends PlayerIntent {
  const CycleRepeatModeIntent();
}

/// Sets or updates the Sleep Timer duration.
class SetSleepTimerIntent extends PlayerIntent {
  final Duration? duration;
  const SetSleepTimerIntent(this.duration);
}

/// Cancels active Sleep Timer.
class CancelSleepTimerIntent extends PlayerIntent {
  const CancelSleepTimerIntent();
}

/// Internal intent triggered each second by the active Sleep Timer.
class SleepTimerTickIntent extends PlayerIntent {
  final Duration remaining;
  const SleepTimerTickIntent(this.remaining);
}

/// Sets audio volume (0.0 to 1.0).
class SetVolumeIntent extends PlayerIntent {
  final double volume;
  const SetVolumeIntent(this.volume);
}

/// Toggles favorite status of currently playing track.
class ToggleFavoriteCurrentIntent extends PlayerIntent {
  const ToggleFavoriteCurrentIntent();
}
