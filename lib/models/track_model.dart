import 'dart:io';
import 'package:path/path.dart' as p;

class TrackModel {
  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final DateTime dateAdded;
  final int fileSize;

  const TrackModel({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    this.album = 'R Music',
    this.duration = Duration.zero,
    required this.dateAdded,
    this.fileSize = 0,
  });

  File get file => File(path);

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'dateAdded': dateAdded.toIso8601String(),
        'fileSize': fileSize,
      };

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: json['id'] as String? ?? json['path'] as String,
      path: json['path'] as String,
      title: json['title'] as String? ?? p.basenameWithoutExtension(json['path'] as String),
      artist: json['artist'] as String? ?? 'Artista Desconocido',
      album: json['album'] as String? ?? 'R Music',
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      dateAdded: json['dateAdded'] != null
          ? DateTime.tryParse(json['dateAdded'] as String) ?? DateTime.now()
          : DateTime.now(),
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }

  TrackModel copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    DateTime? dateAdded,
    int? fileSize,
  }) {
    return TrackModel(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
