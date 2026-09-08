import 'track.dart';

/// Immutable domain entity representing a physical audio Folder.
class Folder {
  final String path;
  final String name;
  final List<Track> tracks;

  const Folder({
    required this.path,
    required this.name,
    this.tracks = const [],
  });

  int get trackCount => tracks.length;

  Duration get totalDuration => tracks.fold(
        Duration.zero,
        (prev, track) => prev + track.duration,
      );

  Folder copyWith({
    String? path,
    String? name,
    List<Track>? tracks,
  }) {
    return Folder(
      path: path ?? this.path,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'Folder(name: $name, path: $path, tracks: ${tracks.length})';
}
