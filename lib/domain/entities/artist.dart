import 'track.dart';

/// Immutable domain entity representing an Artist.
class Artist {
  final String id;
  final String name;
  final List<Track> tracks;

  const Artist({
    required this.id,
    required this.name,
    this.tracks = const [],
  });

  int get trackCount => tracks.length;

  int get albumCount =>
      tracks.map((t) => t.album.trim().toLowerCase()).toSet().length;

  Duration get totalDuration => tracks.fold(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Artist copyWith({
    String? id,
    String? name,
    List<Track>? tracks,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artist &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'Artist(id: $id, name: $name, tracks: ${tracks.length})';
}
