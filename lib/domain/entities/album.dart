import 'track.dart';

/// Immutable domain entity representing a music Album.
class Album {
  final String id;
  final String name;
  final String artist;
  final int? year;
  final String? artworkPath;
  final List<Track> tracks;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.year,
    this.artworkPath,
    this.tracks = const [],
  });

  int get trackCount => tracks.length;

  Duration get totalDuration => tracks.fold(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Album copyWith({
    String? id,
    String? name,
    String? artist,
    int? year,
    String? artworkPath,
    List<Track>? tracks,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      year: year ?? this.year,
      artworkPath: artworkPath ?? this.artworkPath,
      tracks: tracks ?? this.tracks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          artist == other.artist;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ artist.hashCode;

  @override
  String toString() => 'Album(id: $id, name: $name, artist: $artist, tracks: ${tracks.length})';
}
