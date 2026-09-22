import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/track_normalizer.dart';
import '../models/track_model.dart';

class AudioScannerService {
  static const List<String> supportedAudioExtensions = [
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
  ];

  // Ignored messaging / voice note / system audio keywords
  static const List<String> excludedKeywords = [
    'whatsapp',
    'telegram',
    'voice note',
    'voicenote',
    'voice_note',
    'audio note',
    'audionote',
    'audio_note',
    'ptt-',
    'aud-2',
    'file_picker',
    '.opus',
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

  // Priority download keywords (always included)
  static const List<String> priorityInclusionKeywords = [
    'snaptube',
    'download',
    'music',
    'musica',
    'songs',
    'canciones',
    'audio',
  ];

  /// Requests storage and audio permissions on Android
  Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // 1. Android 13+ (API 33+) requires Permission.audio
      final audioStatus = await Permission.audio.status;
      if (!audioStatus.isGranted) {
        final res = await Permission.audio.request();
        if (res.isGranted) return true;
      } else {
        return true;
      }

      // 2. Fallback to Permission.storage (Android <= 12)
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final res = await Permission.storage.request();
        if (res.isGranted) return true;
      } else {
        return true;
      }

      // 3. Optional manageExternalStorage for broad access if needed
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
    }

    return true;
  }

  /// Main method to scan the device storage and return filtered tracks
  Future<List<TrackModel>> scanAllTracks({
    Map<String, TrackModel>? existingTracksMap,
    List<String>? customDirectories,
  }) async {
    // Ensure runtime permissions are requested
    await requestStoragePermissions();

    final List<Directory> directoriesToScan = [];
    final Map<String, TrackModel> knownTracks = existingTracksMap ?? {};

    // 1. Gather search directories based on platform
    if (Platform.isAndroid) {
      final explicitCandidatePaths = [
        // Exact User-Specified Snaptube Paths (Root & Emulated)
        '/storage/snaptube/download/SnapTube Audio',
        '/storage/snaptube/download',
        '/storage/snaptube',
        '/storage/emulated/0/snaptube/download/SnapTube Audio',
        '/storage/emulated/0/snaptube/download/Snaptube Audio',
        '/storage/emulated/0/snaptube/download',
        '/storage/emulated/0/snaptube',
        '/sdcard/snaptube/download/SnapTube Audio',
        '/sdcard/snaptube/download',
        '/sdcard/snaptube',
        '/storage/self/primary/snaptube/download/SnapTube Audio',
        '/storage/self/primary/snaptube/download',
        '/storage/self/primary/snaptube',

        // Standard Downloads & Music folders
        '/storage/emulated/0/Download/SnapTube Audio',
        '/storage/emulated/0/Download/Snaptube Audio',
        '/storage/emulated/0/Download/SnapTube',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Audio',
        '/sdcard/Download',
        '/sdcard/Music',
        '/storage/self/primary/Download',
        '/storage/self/primary/Music',
      ];

      for (var path in explicitCandidatePaths) {
        try {
          final dir = Directory(path);
          if (await dir.exists()) {
            if (!directoriesToScan.any((d) => d.path == dir.path)) {
              directoriesToScan.add(dir);
            }
          }
        } catch (_) {}
      }

      // Check root of storage mount points (e.g. /storage/)
      try {
        final storageRoot = Directory('/storage');
        if (await storageRoot.exists()) {
          await for (var entity in storageRoot.list(recursive: false, followLinks: false)) {
            if (entity is Directory) {
              final snaptubeDir = Directory(p.join(entity.path, 'snaptube', 'download', 'SnapTube Audio'));
              if (await snaptubeDir.exists() && !directoriesToScan.any((d) => d.path == snaptubeDir.path)) {
                directoriesToScan.add(snaptubeDir);
              }
            }
          }
        }
      } catch (_) {}

      // Add path_provider external storage directories
      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (var d in extDirs) {
            if (await d.exists() && !directoriesToScan.any((existing) => existing.path == d.path)) {
              directoriesToScan.add(d);
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching external storage directories: $e");
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final musicDir = Directory(p.join(userProfile, 'Music'));
        final downloadsDir = Directory(p.join(userProfile, 'Downloads'));
        if (await musicDir.exists()) directoriesToScan.add(musicDir);
        if (await downloadsDir.exists()) directoriesToScan.add(downloadsDir);
      }
    }

    // Add general documents/downloads from path_provider
    try {
      final docs = await getApplicationDocumentsDirectory();
      if (await docs.exists() && !directoriesToScan.any((d) => d.path == docs.path)) {
        directoriesToScan.add(docs);
      }
    } catch (_) {}

    // Add any custom folders requested
    if (customDirectories != null) {
      for (var path in customDirectories) {
        final dir = Directory(path);
        if (await dir.exists() && !directoriesToScan.any((d) => d.path == dir.path)) {
          directoriesToScan.add(dir);
        }
      }
    }

    // 2. Discover audio files across collected directories
    final Map<String, File> discoveredFiles = {};

    for (var rootDir in directoriesToScan) {
      await _traverseDirectory(rootDir, discoveredFiles);
    }

    // 3. Process into TrackModel list with preservation of dateAdded
    final List<TrackModel> resultTracks = [];
    final now = DateTime.now();

    for (var file in discoveredFiles.values) {
      try {
        final stat = await file.stat();
        final filePath = p.normalize(file.path).replaceAll('\\', '/');

        // If track already exists in database, preserve its original dateAdded and ID
        if (knownTracks.containsKey(filePath)) {
          final existing = knownTracks[filePath]!;
          resultTracks.add(existing.copyWith(path: filePath, fileSize: stat.size));
        } else {
          // Parse title and artist from filename
          final parsed = _parseTrackMeta(filePath);
          final dateAdded = stat.modified.isBefore(now) ? stat.modified : now;

          final newTrack = TrackModel(
            id: filePath.hashCode.toString(),
            path: filePath,
            title: parsed['title']!,
            artist: parsed['artist']!,
            album: 'R Music',
            duration: Duration.zero,
            dateAdded: dateAdded,
            fileSize: stat.size,
          );
          resultTracks.add(newTrack);
        }
      } catch (e) {
        debugPrint("Error processing audio file ${file.path}: $e");
      }
    }

    // 4. Strict O(n) Deduplication before returning to UI
    final Map<String, List<TrackModel>> titleBuckets = {};

    for (final track in resultTracks) {
      if (track.duration > Duration.zero && track.duration.inSeconds < 30) {
        continue; // Exclude voice notes < 30s
      }

      final cleanTitle = TrackNormalizer.cleanDisplayTitle(track.title, track.path);
      final normalizedTrack = track.copyWith(title: cleanTitle);
      final titleKey = TrackNormalizer.normalizeTitle(cleanTitle.isNotEmpty ? cleanTitle : track.title);
      titleBuckets.putIfAbsent(titleKey, () => []).add(normalizedTrack);
    }

    final List<TrackModel> cleanList = [];

    for (final bucket in titleBuckets.values) {
      if (bucket.length == 1) {
        cleanList.add(bucket.first);
        continue;
      }

      final List<TrackModel> mergedList = [];
      for (final candidate in bucket) {
        final candArtistNorm = TrackNormalizer.normalizeArtist(candidate.artist);
        final candDurSec = candidate.duration.inSeconds;

        int matchIndex = -1;
        for (int i = 0; i < mergedList.length; i++) {
          final existing = mergedList[i];
          final existArtistNorm = TrackNormalizer.normalizeArtist(existing.artist);
          final existDurSec = existing.duration.inSeconds;

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
          final bool preferCandidate = candidate.fileSize > existing.fileSize;
          final base = preferCandidate ? candidate : existing;
          final other = preferCandidate ? existing : candidate;

          final bestDuration = base.duration > Duration.zero ? base.duration : other.duration;
          final bestArtist = candArtistNorm.isNotEmpty ? candidate.artist : existing.artist;
          final bestDate = base.dateAdded.isBefore(other.dateAdded) ? base.dateAdded : other.dateAdded;

          mergedList[matchIndex] = base.copyWith(
            duration: bestDuration,
            artist: bestArtist,
            dateAdded: bestDate,
          );
        }
      }

      cleanList.addAll(mergedList);
    }

    cleanList.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return cleanList;
  }

  /// Traverses directory iteratively with exclusion rules
  Future<void> _traverseDirectory(
    Directory rootDir,
    Map<String, File> filesCollector,
  ) async {
    final List<Directory> queue = [rootDir];
    final Set<String> visitedPaths = {};

    while (queue.isNotEmpty) {
      final currentDir = queue.removeAt(0);
      final currentPath = currentDir.path;

      if (visitedPaths.contains(currentPath)) continue;
      visitedPaths.add(currentPath);

      // Check if folder contains .nomedia or matches excluded messaging keywords
      if (_isPathExcluded(currentPath)) {
        continue;
      }

      try {
        await for (var entity in currentDir.list(recursive: false, followLinks: false)) {
          final entityPath = entity.path;

          if (_isPathExcluded(entityPath)) {
            continue;
          }

          if (entity is File) {
            final ext = p.extension(entityPath).toLowerCase();
            if (supportedAudioExtensions.contains(ext)) {
              try {
                final length = await entity.length();
                final isPriority = priorityInclusionKeywords.any((k) => entityPath.toLowerCase().contains(k));

                // Filter out small audio files (< 100KB) unless explicitly a prioritized download (Snaptube/Music)
                if (length >= 100 * 1024 || (isPriority && length > 10 * 1024)) {
                  filesCollector[entityPath] = entity;
                }
              } catch (_) {
                // If length read fails, still include if it's a valid audio extension
                filesCollector[entityPath] = entity;
              }
            }
          } else if (entity is Directory) {
            final dirName = p.basename(entityPath);
            if (!dirName.startsWith('.')) {
              queue.add(Directory(entityPath));
            }
          }
        }
      } catch (e) {
        debugPrint("Skipping directory $currentPath: $e");
      }
    }
  }

  /// Check if a path matches messaging/voice note exclusion rules
  bool _isPathExcluded(String path) {
    final lower = path.toLowerCase();
    for (var keyword in excludedKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Extracts artist and title cleanly from file name
  Map<String, String> _parseTrackMeta(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);

    // If fileName contains ' - ' (e.g. "Artist - Song Title")
    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      if (parts.length >= 2) {
        final artist = parts[0].trim();
        final title = parts.sublist(1).join(' - ').trim();
        if (artist.isNotEmpty && title.isNotEmpty) {
          return {
            'artist': artist,
            'title': _cleanTrackTitle(title),
          };
        }
      }
    }

    // Default: use parent directory name as artist if it's not a generic folder or numeric timestamp
    final parentDir = p.basename(p.dirname(filePath));
    String artist = 'Artista Desconocido';
    final parentLower = parentDir.toLowerCase();
    final isGeneric = ['music', 'download', 'downloads', 'audio', 'snaptube audio', 'snaptube', '0', 'emulated', 'primary', 'sdcard'].contains(parentLower);
    final isNumeric = RegExp(r'^\d+$').hasMatch(parentDir);

    if (!isGeneric && !isNumeric) {
      artist = parentDir;
    }

    return {
      'artist': artist,
      'title': _cleanTrackTitle(fileName),
    };
  }

  /// Cleans junk tokens often added by video/audio downloaders
  String _cleanTrackTitle(String rawTitle) {
    return TrackNormalizer.cleanDisplayTitle(rawTitle, '');
  }
}
