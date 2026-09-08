import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../core/utils/track_normalizer.dart';

/// Input parameters passed to the Scanner Worker Isolate.
class ScannerWorkerParams {
  final List<String> rootDirectories;
  final Map<String, Map<String, dynamic>> knownTracksByPath;
  final int minDurationMs;
  final int minFileSizeBytes;

  const ScannerWorkerParams({
    required this.rootDirectories,
    this.knownTracksByPath = const {},
    this.minDurationMs = 30000, // 30 seconds heuristic
    this.minFileSizeBytes = 100 * 1024, // 100 KB
  });
}

/// Standalone top-level isolate worker for scanning, filtering, and deduplicating audio files.
/// Runs in a background isolate via [compute] or [Isolate.run].
List<Map<String, dynamic>> runScannerWorker(ScannerWorkerParams params) {
  final stopwatch = Stopwatch()..start();

  const supportedExtensions = <String>{
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
  };

  // Forbidden messaging, ringtones, system audio and voice note directories
  const excludedKeywords = <String>[
    'whatsapp',
    'telegram',
    'voice note',
    'voicenote',
    'voice_note',
    'audio note',
    'audionote',
    'audio_note',
    'ptt-',
    'call_rec',
    'callrecording',
    'recordings',
    'recorder',
    'zedge',
    'ringtone',
    'ringtones',
    'notification',
    'notifications',
    'system/media',
    '.trash',
    '.cache',
    'android/data',
    'android/obb',
  ];

  const priorityKeywords = <String>[
    'snaptube',
    'download',
    'music',
    'musica',
    'songs',
    'canciones',
    'audio',
  ];

  bool isExcludedPath(String path) {
    final lower = path.toLowerCase();
    for (final keyword in excludedKeywords) {
      if (lower.contains(keyword)) return true;
    }
    return false;
  }

  bool isPriorityPath(String path) {
    final lower = path.toLowerCase();
    for (final keyword in priorityKeywords) {
      if (lower.contains(keyword)) return true;
    }
    return false;
  }

  final Map<String, File> discoveredFiles = {};
  final Set<String> visitedDirs = {};

  // 1. Traverse directories iteratively
  for (final rootPath in params.rootDirectories) {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) continue;

    final List<Directory> queue = [rootDir];

    while (queue.isNotEmpty) {
      final currentDir = queue.removeAt(0);
      final currentPath = currentDir.path;

      if (visitedDirs.contains(currentPath)) continue;
      visitedDirs.add(currentPath);

      if (isExcludedPath(currentPath)) continue;

      try {
        final entities = currentDir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          final entityPath = entity.path;
          if (isExcludedPath(entityPath)) continue;

          if (entity is File) {
            final ext = p.extension(entityPath).toLowerCase();
            if (supportedExtensions.contains(ext)) {
              try {
                final length = entity.lengthSync();
                final priority = isPriorityPath(entityPath);

                // Filter out audio clips smaller than 100KB unless from a prioritized music directory
                if (length >= params.minFileSizeBytes || (priority && length > 15 * 1024)) {
                  final normPath = p.normalize(entityPath).replaceAll('\\', '/').trim();
                  discoveredFiles[normPath] = entity;
                }
              } catch (_) {
                final normPath = p.normalize(entityPath).replaceAll('\\', '/').trim();
                discoveredFiles[normPath] = entity;
              }
            }
          } else if (entity is Directory) {
            final dirName = p.basename(entityPath);
            if (!dirName.startsWith('.')) {
              queue.add(entity);
            }
          }
        }
      } catch (_) {
        // Skip unreadable directories
      }
    }
  }

  // 2. Build Track DTO maps
  final List<Map<String, dynamic>> rawTracks = [];
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  for (final entry in discoveredFiles.entries) {
    final normPath = entry.key;
    final file = entry.value;

    try {
      final stat = file.statSync();
      final fileSize = stat.size;
      final dateAddedMs = stat.modified.millisecondsSinceEpoch <= nowMs
          ? stat.modified.millisecondsSinceEpoch
          : nowMs;

      if (params.knownTracksByPath.containsKey(normPath)) {
        final existing = Map<String, dynamic>.from(params.knownTracksByPath[normPath]!);
        existing['fileSize'] = fileSize;
        existing['path'] = normPath;
        rawTracks.add(existing);
      } else {
        final parsed = _parseTitleAndArtist(normPath);
        rawTracks.add({
          'id': normPath.hashCode.toString(),
          'path': normPath,
          'title': parsed['title']!,
          'artist': parsed['artist']!,
          'album': 'R Music',
          'genre': 'Unknown',
          'year': null,
          'durationMs': 0,
          'dateAddedMs': dateAddedMs,
          'fileSize': fileSize,
          'artworkPath': null,
          'isFavorite': false,
          'lyricsPath': null,
        });
      }
    } catch (_) {}
  }

  // 3. Strict O(n) Deduplication Algorithm using title buckets & metadata heuristics
  final Map<String, List<Map<String, dynamic>>> titleBuckets = {};

  for (final track in rawTracks) {
    final title = (track['title'] as String?) ?? '';
    final durationMs = (track['durationMs'] as int?) ?? 0;

    // Rule 3: Exclude voice notes with duration < 30 seconds if duration is known
    if (durationMs > 0 && durationMs < params.minDurationMs) {
      continue;
    }

    final titleKey = TrackNormalizer.normalizeTitle(title);
    titleBuckets.putIfAbsent(titleKey, () => []).add(track);
  }

  final List<Map<String, dynamic>> resultList = [];

  for (final bucket in titleBuckets.values) {
    if (bucket.length == 1) {
      resultList.add(bucket.first);
      continue;
    }

    final List<Map<String, dynamic>> mergedList = [];

    for (final candidate in bucket) {
      final candArtist = (candidate['artist'] as String?) ?? '';
      final candArtistNorm = TrackNormalizer.normalizeArtist(candArtist);
      final candDurMs = (candidate['durationMs'] as int?) ?? 0;
      final candDurSec = candDurMs ~/ 1000;

      int matchIndex = -1;
      for (int i = 0; i < mergedList.length; i++) {
        final existing = mergedList[i];
        final existArtist = (existing['artist'] as String?) ?? '';
        final existArtistNorm = TrackNormalizer.normalizeArtist(existArtist);
        final existDurMs = (existing['durationMs'] as int?) ?? 0;
        final existDurSec = existDurMs ~/ 1000;

        final artistsCompatible = candArtistNorm.isEmpty ||
            existArtistNorm.isEmpty ||
            candArtistNorm == existArtistNorm;

        if (!artistsCompatible) continue;

        final durationCompatible = candDurSec <= 0 ||
            existDurSec <= 0 ||
            (candDurSec - existDurSec).abs() <= 20;

        if (durationCompatible) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex == -1) {
        mergedList.add(candidate);
      } else {
        final existing = mergedList[matchIndex];
        final candSize = (candidate['fileSize'] as int?) ?? 0;
        final existSize = (existing['fileSize'] as int?) ?? 0;
        final bool preferCandidate = candSize > existSize;

        final base = preferCandidate ? candidate : existing;
        final other = preferCandidate ? existing : candidate;

        final bestDurMs = ((base['durationMs'] as int?) ?? 0) > 0
            ? base['durationMs']
            : other['durationMs'];
        final bestArtist = candArtistNorm.isNotEmpty
            ? candidate['artist']
            : existing['artist'];
        final candDate = (candidate['dateAddedMs'] as int?) ?? 0;
        final existDate = (existing['dateAddedMs'] as int?) ?? 0;
        final bestDate = (candDate < existDate && candDate > 0) ? candDate : existDate;

        final merged = Map<String, dynamic>.from(base);
        merged['durationMs'] = bestDurMs;
        merged['artist'] = bestArtist;
        merged['dateAddedMs'] = bestDate;

        mergedList[matchIndex] = merged;
      }
    }

    resultList.addAll(mergedList);
  }

  // Sort descending by dateAddedMs (newest tracks first)
  resultList.sort((a, b) {
    final aDate = (a['dateAddedMs'] as int?) ?? 0;
    final bDate = (b['dateAddedMs'] as int?) ?? 0;
    return bDate.compareTo(aDate);
  });

  stopwatch.stop();
  return resultList;
}

Map<String, String> _parseTitleAndArtist(String filePath) {
  final rawBase = p.basenameWithoutExtension(filePath);
  final cleanTitle = TrackNormalizer.cleanDisplayTitle(rawBase, filePath);

  if (rawBase.contains(' - ')) {
    final parts = rawBase.split(' - ');
    if (parts.length >= 2) {
      final artist = parts[0].trim();
      final titlePart = parts.sublist(1).join(' - ').trim();
      final title = TrackNormalizer.cleanDisplayTitle(titlePart, filePath);
      if (artist.isNotEmpty && title.isNotEmpty) {
        return {'artist': artist, 'title': title};
      }
    }
  }

  final parentDir = p.basename(p.dirname(filePath));
  const genericFolders = {'download', 'music', 'songs', 'audios', 'snaptube audio', 'snaptube', 'bluetooth'};
  final isGeneric = genericFolders.contains(parentDir.toLowerCase());

  return {
    'title': cleanTitle.isEmpty ? 'Pista desconocida' : cleanTitle,
    'artist': isGeneric ? 'Artista Desconocido' : parentDir,
  };
}
