import '../../core/utils/track_normalizer.dart';

/// Immutable domain entity representing an audio track in R Music.
/// Pure Dart class without UI or framework dependencies.
class Track {
  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int? year;
  final Duration duration;
  final DateTime dateAdded;
  final int fileSize;
  final String? artworkPath;
  final bool isFavorite;
  final String? lyricsPath;

  const Track({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    this.album = 'R Music',
    this.genre = 'Unknown',
    this.year,
    this.duration = Duration.zero,
    required this.dateAdded,
    this.fileSize = 0,
    this.artworkPath,
    this.isFavorite = false,
    this.lyricsPath,
  });

  /// Key used for exact deduplication (normalized title + duration in seconds, or artist + title)
  String get deduplicationKey => TrackNormalizer.generateDeduplicationKey(
        title: title,
        durationSeconds: duration.inSeconds,
        artist: artist,
        fallbackPath: path,
      );

  Track copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? year,
    Duration? duration,
    DateTime? dateAdded,
    int? fileSize,
    String? artworkPath,
    bool? isFavorite,
    String? lyricsPath,
  }) {
    return Track(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      fileSize: fileSize ?? this.fileSize,
      artworkPath: artworkPath ?? this.artworkPath,
      isFavorite: isFavorite ?? this.isFavorite,
      lyricsPath: lyricsPath ?? this.lyricsPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path &&
          isFavorite == other.isFavorite;

  @override
  int get hashCode => id.hashCode ^ path.hashCode ^ isFavorite.hashCode;

  @override
  String toString() {
    return 'Track(id: $id, title: $title, artist: $artist, duration: ${duration.inSeconds}s, path: $path)';
  }
}
