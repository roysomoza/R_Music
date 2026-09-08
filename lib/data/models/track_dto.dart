import 'package:path/path.dart' as p;
import '../../domain/entities/track.dart';

/// Data Transfer Object (DTO) for Track persistence and serialization.
class TrackDto {
  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int? year;
  final int durationMs;
  final int dateAddedMs;
  final int fileSize;
  final String? artworkPath;
  final bool isFavorite;
  final String? lyricsPath;

  const TrackDto({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    this.album = 'R Music',
    this.genre = 'Unknown',
    this.year,
    this.durationMs = 0,
    required this.dateAddedMs,
    this.fileSize = 0,
    this.artworkPath,
    this.isFavorite = false,
    this.lyricsPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'year': year,
        'durationMs': durationMs,
        'dateAddedMs': dateAddedMs,
        'fileSize': fileSize,
        'artworkPath': artworkPath,
        'isFavorite': isFavorite,
        'lyricsPath': lyricsPath,
      };

  factory TrackDto.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'] as String? ?? '';
    final title = json['title'] as String? ?? p.basenameWithoutExtension(rawPath);

    int parsedDateMs = 0;
    if (json['dateAddedMs'] is int) {
      parsedDateMs = json['dateAddedMs'] as int;
    } else if (json['dateAdded'] is String) {
      final parsed = DateTime.tryParse(json['dateAdded'] as String);
      parsedDateMs = parsed?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    } else {
      parsedDateMs = DateTime.now().millisecondsSinceEpoch;
    }

    return TrackDto(
      id: json['id'] as String? ?? rawPath.hashCode.toString(),
      path: rawPath,
      title: title.isEmpty ? 'Pista sin título' : title,
      artist: json['artist'] as String? ?? 'Artista Desconocido',
      album: json['album'] as String? ?? 'R Music',
      genre: json['genre'] as String? ?? 'Unknown',
      year: json['year'] as int?,
      durationMs: json['durationMs'] as int? ?? 0,
      dateAddedMs: parsedDateMs,
      fileSize: json['fileSize'] as int? ?? 0,
      artworkPath: json['artworkPath'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      lyricsPath: json['lyricsPath'] as String?,
    );
  }

  Track toDomain() {
    return Track(
      id: id,
      path: path,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      year: year,
      duration: Duration(milliseconds: durationMs),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(dateAddedMs),
      fileSize: fileSize,
      artworkPath: artworkPath,
      isFavorite: isFavorite,
      lyricsPath: lyricsPath,
    );
  }

  factory TrackDto.fromDomain(Track track) {
    return TrackDto(
      id: track.id,
      path: track.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      genre: track.genre,
      year: track.year,
      durationMs: track.duration.inMilliseconds,
      dateAddedMs: track.dateAdded.millisecondsSinceEpoch,
      fileSize: track.fileSize,
      artworkPath: track.artworkPath,
      isFavorite: track.isFavorite,
      lyricsPath: track.lyricsPath,
    );
  }
}
