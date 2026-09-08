import '../../domain/entities/folder.dart';
import '../../domain/entities/track.dart';

/// Data Transfer Object for Folder persistence.
class FolderDto {
  final String id;
  final String name;
  final String path;
  final int createdAtMs;
  final List<String> trackPaths;

  const FolderDto({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAtMs,
    this.trackPaths = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'createdAtMs': createdAtMs,
        'trackPaths': trackPaths,
      };

  factory FolderDto.fromJson(Map<String, dynamic> json) {
    int parsedCreated = 0;
    if (json['createdAtMs'] is int) {
      parsedCreated = json['createdAtMs'] as int;
    } else if (json['createdAt'] is String) {
      final parsed = DateTime.tryParse(json['createdAt'] as String);
      parsedCreated = parsed?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    } else {
      parsedCreated = DateTime.now().millisecondsSinceEpoch;
    }

    return FolderDto(
      id: json['id'] as String? ?? json['name'] as String? ?? 'folder',
      name: json['name'] as String? ?? 'Carpeta',
      path: json['path'] as String? ?? '',
      createdAtMs: parsedCreated,
      trackPaths: (json['trackPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Folder toDomain({List<Track> allTracks = const []}) {
    final Map<String, Track> trackMap = {for (var t in allTracks) t.path: t};
    final List<Track> matchingTracks = [];

    for (var trackPath in trackPaths) {
      if (trackMap.containsKey(trackPath)) {
        matchingTracks.add(trackMap[trackPath]!);
      }
    }

    return Folder(
      path: path,
      name: name,
      tracks: matchingTracks,
    );
  }
}
