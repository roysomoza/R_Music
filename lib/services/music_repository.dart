import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/utils/track_normalizer.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import 'audio_scanner_service.dart';

class MusicRepository {
  final AudioScannerService _scannerService = AudioScannerService();

  Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, fileName));
  }

  /// Normalizes file path to ensure uniform comparisons across OS separators
  String _normalizePath(String rawPath) {
    return p.normalize(rawPath).replaceAll('\\', '/').trim();
  }

  /// Strict O(n) Deduplication Algorithm
  /// Deduplicates tracks ensuring multiple downloads of the same song (e.g. Cancion(MP3_160K) and Cancion(MP3_128K))
  /// are strictly merged into a single high-quality entry based on normalized title, artist compatibility, and duration.
  List<TrackModel> deduplicateTracks(List<TrackModel> tracks) {
    // 1. Group by normalized title
    final Map<String, List<TrackModel>> titleBuckets = {};

    for (final track in tracks) {
      // Exclude voice notes (<30s) if duration is confirmed
      if (track.duration > Duration.zero && track.duration.inSeconds < 30) {
        continue;
      }

      final normPath = _normalizePath(track.path);
      final cleanTitle = TrackNormalizer.cleanDisplayTitle(track.title, track.path);
      final normalizedTrack = track.copyWith(
        path: normPath,
        title: cleanTitle,
      );

      final titleKey = TrackNormalizer.normalizeTitle(cleanTitle.isNotEmpty ? cleanTitle : track.title);
      titleBuckets.putIfAbsent(titleKey, () => []).add(normalizedTrack);
    }

    final List<TrackModel> result = [];

    // 2. Deduplicate within each title bucket
    for (final bucket in titleBuckets.values) {
      if (bucket.length == 1) {
        result.add(bucket.first);
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

          // Compatible if either artist is generic/empty, or both normalized artists are equal
          final artistsCompatible = candArtistNorm.isEmpty ||
              existArtistNorm.isEmpty ||
              candArtistNorm == existArtistNorm;

          if (!artistsCompatible) continue;

          // Compatible if either duration is 0, or duration difference is <= 20 seconds
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
          // Prefer higher fileSize (higher quality/bitrate)
          final bool preferCandidate = candidate.fileSize > existing.fileSize;
          final base = preferCandidate ? candidate : existing;
          final other = preferCandidate ? existing : candidate;

          // Preserve valid duration (>0)
          final bestDuration = base.duration > Duration.zero ? base.duration : other.duration;
          // Preserve non-generic artist
          final bestArtist = candArtistNorm.isNotEmpty ? candidate.artist : existing.artist;
          // Preserve earliest or valid dateAdded
          final bestDate = base.dateAdded.isBefore(other.dateAdded) ? base.dateAdded : other.dateAdded;

          mergedList[matchIndex] = base.copyWith(
            duration: bestDuration,
            artist: bestArtist,
            dateAdded: bestDate,
          );
        }
      }

      result.addAll(mergedList);
    }

    result.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return result;
  }

  /// Loads tracks from tracks_db.json, deduplicates, and cleans up any invalid entries
  Future<List<TrackModel>> loadCachedTracks() async {
    try {
      final file = await _getFile('tracks_db.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          final tracks = jsonList.map((j) => TrackModel.fromJson(j)).toList();

          // Deduplicate immediately upon loading
          final deduplicated = deduplicateTracks(tracks);

          final List<TrackModel> validTracks = [];
          for (var t in deduplicated) {
            final f = File(t.path);
            if (await f.exists()) {
              validTracks.add(t);
            } else {
              // Keep in cache in case permissions or mount point is pending
              validTracks.add(t);
            }
          }

          if (validTracks.isNotEmpty) {
            // If deduplication removed duplicates, persist the clean state
            if (validTracks.length != tracks.length) {
              await saveTracks(validTracks);
            }
            return validTracks;
          }
        }
      }

      // ── LEGACY MIGRATION: Read from scanned_folders.json if tracks_db is empty ──
      final legacyFoldersFile = await _getFile('scanned_folders.json');
      if (await legacyFoldersFile.exists()) {
        final legacyContent = await legacyFoldersFile.readAsString();
        if (legacyContent.trim().isNotEmpty) {
          final List<dynamic> legacyJson = jsonDecode(legacyContent);
          final List<TrackModel> migrated = [];

          for (var folderJson in legacyJson) {
            final List<dynamic>? filePaths = folderJson['filePaths'] as List<dynamic>?;
            if (filePaths != null) {
              for (var pathStr in filePaths) {
                final path = _normalizePath(pathStr.toString());
                final fileName = p.basenameWithoutExtension(path);
                final parentDir = p.basename(p.dirname(path));

                migrated.add(TrackModel(
                  id: path.hashCode.toString(),
                  path: path,
                  title: fileName,
                  artist: parentDir.isNotEmpty ? parentDir : 'R Music',
                  album: 'R Music',
                  duration: Duration.zero,
                  dateAdded: DateTime.now(),
                ));
              }
            }
          }

          if (migrated.isNotEmpty) {
            final uniqueMigrated = deduplicateTracks(migrated);
            await saveTracks(uniqueMigrated);
            return uniqueMigrated;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading cached tracks: $e");
    }
    return [];
  }

  /// Saves tracks to tracks_db.json ensuring strict deduplication
  Future<void> saveTracks(List<TrackModel> tracks) async {
    try {
      final uniqueTracks = deduplicateTracks(tracks);
      final file = await _getFile('tracks_db.json');
      final jsonList = uniqueTracks.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving tracks: $e");
    }
  }

  /// Directly merges and persists manually picked tracks without duplicates
  Future<List<TrackModel>> addManualTracks(List<TrackModel> newTracks) async {
    final cached = await loadCachedTracks();
    final Map<String, TrackModel> map = {
      for (var t in cached) _normalizePath(t.path): t
    };

    for (var track in newTracks) {
      final norm = _normalizePath(track.path);
      map[norm] = track.copyWith(path: norm);
    }

    final merged = deduplicateTracks(map.values.toList());
    await saveTracks(merged);
    return merged;
  }

  /// Scans device and non-destructively merges with existing records
  Future<List<TrackModel>> scanAndSaveTracks({List<String>? customDirs}) async {
    final cached = await loadCachedTracks();
    final Map<String, TrackModel> map = {
      for (var t in cached) _normalizePath(t.path): t
    };

    final scannedTracks = await _scannerService.scanAllTracks(
      existingTracksMap: map,
      customDirectories: customDirs,
    );

    for (var track in scannedTracks) {
      final norm = _normalizePath(track.path);
      map[norm] = track.copyWith(path: norm);
    }

    final merged = deduplicateTracks(map.values.toList());

    if (merged.isNotEmpty) {
      await saveTracks(merged);
    }

    return merged;
  }

  /// Deletes a track from database, favorites, and folders
  Future<List<TrackModel>> deleteTrack(String trackPath, {bool deleteFileFromDisk = false}) async {
    final normPath = _normalizePath(trackPath);

    // 1. Remove file from storage if requested
    if (deleteFileFromDisk) {
      try {
        final f = File(trackPath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        debugPrint("Error deleting physical file: $e");
      }
    }

    // 2. Remove from tracks database
    final cached = await loadCachedTracks();
    final updated = cached.where((t) => _normalizePath(t.path) != normPath).toList();
    await saveTracks(updated);

    // 3. Remove from favorites
    final favs = await loadFavorites();
    if (favs.contains(normPath) || favs.contains(trackPath)) {
      favs.remove(normPath);
      favs.remove(trackPath);
      await saveFavorites(favs);
    }

    // 4. Remove from all folders
    final folders = await loadFolders();
    bool foldersChanged = false;
    for (var folder in folders) {
      if (folder.trackPaths.any((p) => _normalizePath(p) == normPath)) {
        folder.trackPaths.removeWhere((p) => _normalizePath(p) == normPath);
        foldersChanged = true;
      }
    }
    if (foldersChanged) {
      await saveFolders(folders);
    }

    return updated;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOLDERS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads custom user folders from folders.json
  Future<List<FolderModel>> loadFolders() async {
    try {
      final file = await _getFile('folders.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          return jsonList.map((j) => FolderModel.fromJson(j)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading folders: $e");
    }
    return [];
  }

  /// Saves custom user folders to folders.json
  Future<void> saveFolders(List<FolderModel> folders) async {
    try {
      final file = await _getFile('folders.json');
      final jsonList = folders.map((f) => f.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving folders: $e");
    }
  }

  /// Creates a new folder
  Future<List<FolderModel>> createFolder(String name) async {
    final folders = await loadFolders();
    final newFolder = FolderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      createdAt: DateTime.now(),
      trackPaths: [],
    );
    folders.insert(0, newFolder);
    await saveFolders(folders);
    return folders;
  }

  /// Deletes a folder by ID
  Future<List<FolderModel>> deleteFolder(String folderId) async {
    final folders = await loadFolders();
    final updated = folders.where((f) => f.id != folderId).toList();
    await saveFolders(updated);
    return updated;
  }

  /// Renames a folder by ID
  Future<List<FolderModel>> renameFolder(String folderId, String newName) async {
    final folders = await loadFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      folders[index] = folders[index].copyWith(name: newName.trim());
      await saveFolders(folders);
    }
    return folders;
  }

  /// Adds tracks to a folder avoiding internal duplicates
  Future<List<FolderModel>> addTracksToFolder(String folderId, List<String> newTrackPaths) async {
    final folders = await loadFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      final folder = folders[index];
      final currentNormalized = folder.trackPaths.map(_normalizePath).toSet();

      for (var path in newTrackPaths) {
        final norm = _normalizePath(path);
        if (!currentNormalized.contains(norm)) {
          folder.trackPaths.add(norm);
          currentNormalized.add(norm);
        }
      }

      folders[index] = folder;
      await saveFolders(folders);
    }
    return folders;
  }

  /// Removes a track from a folder
  Future<List<FolderModel>> removeTrackFromFolder(String folderId, String trackPath) async {
    final normPath = _normalizePath(trackPath);
    final folders = await loadFolders();
    final index = folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      folders[index].trackPaths.removeWhere((p) => _normalizePath(p) == normPath);
      await saveFolders(folders);
    }
    return folders;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FAVORITES & PLAYBACK STATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads favorites (Set of file paths)
  Future<Set<String>> loadFavorites() async {
    try {
      final file = await _getFile('favorites.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((item) => _normalizePath(item.toString())).toSet();
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
    return {};
  }

  /// Saves favorites (Set of file paths)
  Future<void> saveFavorites(Set<String> favorites) async {
    try {
      final file = await _getFile('favorites.json');
      final normList = favorites.map(_normalizePath).toSet().toList();
      await file.writeAsString(jsonEncode(normList));
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
  }

  /// Loads last playback state
  Future<Map<String, dynamic>?> loadPlaybackState() async {
    try {
      final file = await _getFile('playback_state.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error loading playback state: $e");
    }
    return null;
  }

  /// Saves playback state
  Future<void> savePlaybackState(List<String> playlistPaths, int currentIndex) async {
    try {
      final file = await _getFile('playback_state.json');
      final data = {
        'playlist': playlistPaths.map(_normalizePath).toList(),
        'currentIndex': currentIndex,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint("Error saving playback state: $e");
    }
  }
}
