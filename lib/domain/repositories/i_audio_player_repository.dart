import '../entities/track.dart';

enum RepeatMode { off, all, one }

/// Contract for the Audio Player engine abstraction.
/// Decouples just_audio and system media service from domain and MVI layers.
abstract class IAudioPlayerRepository {
  /// Currently active track
  Stream<Track?> get currentTrackStream;

  /// Current playback position
  Stream<Duration> get positionStream;

  /// Total duration of the active track
  Stream<Duration?> get durationStream;

  /// Whether audio is actively playing
  Stream<bool> get isPlayingStream;

  /// Whether audio engine is buffering or loading
  Stream<bool> get isBufferingStream;

  /// Whether shuffle mode is active
  Stream<bool> get isShuffleStream;

  /// Current repeat mode (off, all, one)
  Stream<RepeatMode> get repeatModeStream;

  /// Current playback queue
  Stream<List<Track>> get queueStream;

  /// Index of currently playing track in queue
  Stream<int> get currentIndexStream;

  /// Sets queue and plays track at [initialIndex]
  Future<void> setQueue(
    List<Track> queue, {
    int initialIndex = 0,
    bool autoPlay = true,
  });

  /// Resumes playback
  Future<void> play();

  /// Pauses playback
  Future<void> pause();

  /// Stops playback
  Future<void> stop();

  /// Seeks to a specific duration
  Future<void> seek(Duration position);

  /// Skips to the next track in the queue
  Future<void> skipToNext();

  /// Skips to the previous track or restarts current track
  Future<void> skipToPrevious();

  /// Toggles or sets shuffle mode
  Future<void> setShuffle(bool enabled);

  /// Sets repeat mode
  Future<void> setRepeatMode(RepeatMode mode);

  /// Sets playback volume (0.0 to 1.0)
  Future<void> setVolume(double volume);

  /// Releases audio engine resources
  Future<void> dispose();
}
