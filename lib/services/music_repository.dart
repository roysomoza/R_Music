import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/utils/track_normalizer.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import 'audio_scanner_service.dart';
import 'metadata_resolution_service.dart';

class MusicRepository {
  final AudioScannerService _scannerService = AudioScannerService();
  final MetadataResolutionService _resolutionService = MetadataResolutionService();

  final StreamController<List<TrackModel>> _tracksUpdatedController =
      StreamController<List<TrackModel>>.broadcast();
  final StreamController<Set<String>> _favoritesUpdatedController =
      StreamController<Set<String>>.broadcast();

  Set<String> _cachedFavorites = {};
  bool _favoritesLoaded = false;

  static final RegExp _cacheFilePickerPattern = RegExp(r'/cache/file_picker/\d{8,}/');

  /// Reactive stream emitted when background metadata batch resolution updates tracks
  Stream<List<TrackModel>> get onTracksUpdated => _tracksUpdatedController.stream;

  /// Reactive stream emitted when favorites are loaded, toggled, or modified
  Stream<Set<String>> get onFavoritesUpdated => _favoritesUpdatedController.stream;

  /// Synchronous snapshot of current favorites in memory
  Set<String> get currentFavorites => Set.unmodifiable(_cachedFavorites);

  MetadataResolutionService get resolutionService => _resolutionService;

  Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, fileName));
  }

  /// Writes file contents atomically via a temporary file replacement.
  /// Prevents zero-byte corruption or half-written files if app is killed mid-write.
  Future<void> _writeAtomic(String fileName, String content) async {
    final file = await _getFile(fileName);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    if (await tempFile.exists()) {
      try {
        await tempFile.rename(file.path);
      } catch (e) {
        // Fallback en caso de error de sistema de archivos: copiar contenido y eliminar el archivo .tmp
        try {
          await tempFile.copy(file.path);
          await tempFile.delete();
        } catch (fallbackError) {
          debugPrint("Fallback copy/delete failed for $fileName: $fallbackError");
        }
      }
    }
  }

  /// Top-level or static worker to encode large track lists off the main UI isolate
  static String _encodeTracksJsonWorker(List<Map<String, dynamic>> list) {
    return jsonEncode(list);
  }

  /// Normalizes file path to ensure uniform comparisons across OS separators and Android mount aliases
  String _normalizePath(String rawPath) {
    return TrackNormalizer.canonicalizePath(rawPath);
  }

  /// Strict O(n) Deduplication Algorithm
  /// Deduplicates tracks ensuring multiple downloads of the same song (e.g. Cancion(MP3_160K) and Cancion(MP3_128K))
  /// are strictly merged into a single high-quality entry based on normalized title, artist compatibility, and duration.
  List<TrackModel> deduplicateTracks(List<TrackModel> tracks) {
    // 1. Group by normalized title
    final Map<String, List<TrackModel>> titleBuckets = {};

    for (final track in tracks) {
      // Exclude messaging voice notes, audio notes, and non-music files
      final lowerPath = track.path.toLowerCase();
      final lowerTitle = track.title.toLowerCase();
      if (lowerPath.contains('ptt-') ||
          lowerTitle.contains('ptt-') ||
          lowerPath.contains('aud-2') ||
          lowerTitle.contains('aud-2') ||
          lowerPath.endsWith('.opus') ||
          lowerPath.contains('cache/file_picker')) {
        continue;
      }

      // Exclude short voice notes (<30s) if duration is confirmed
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

          if (deduplicated.isNotEmpty) {
            // If deduplication removed duplicates, persist the clean state asynchronously
            if (deduplicated.length != tracks.length) {
              saveTracks(deduplicated);
            }

            // Post-startup deferred batch resolution: keeps initial frame render at 60 FPS
            Future.delayed(const Duration(milliseconds: 500), () {
              autoResolveUnresolvedTracks(deduplicated);
            });

            return deduplicated;
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

  /// Asynchronously evaluates tracks in the background, resolving numeric/unknown artists
  /// in a single Isolate worker and persisting in a single atomic transaction.
  Future<List<TrackModel>> autoResolveUnresolvedTracks(List<TrackModel> tracks) async {
    final needsWork = tracks.any((t) =>
        TrackNormalizer.isInvalidOrGenericArtist(t.artist) ||
        TrackNormalizer.isNonMusic(t.path, t.title) ||
        _cacheFilePickerPattern.hasMatch(t.path));

    if (!needsWork) {
      return tracks;
    }

    try {
      final resolved = await _resolutionService.resolveBatch(tracks);
      final deduplicated = deduplicateTracks(resolved);

      bool changed = deduplicated.length != tracks.length;
      if (!changed) {
        for (int i = 0; i < tracks.length; i++) {
          if (tracks[i].artist != deduplicated[i].artist ||
              tracks[i].title != deduplicated[i].title) {
            changed = true;
            break;
          }
        }
      }

      if (changed) {
        await saveTracks(deduplicated);
        _tracksUpdatedController.add(deduplicated);
        return deduplicated;
      }
    } catch (e) {
      debugPrint("Background auto-resolution error: $e");
    }
    return tracks;
  }

  /// Saves tracks to tracks_db.json ensuring strict deduplication and atomic persistence
  Future<void> saveTracks(List<TrackModel> tracks) async {
    try {
      final uniqueTracks = deduplicateTracks(tracks);
      final jsonList = uniqueTracks.map((t) => t.toJson()).toList();

      final String jsonContent;
      if (uniqueTracks.length > 300) {
        jsonContent = await compute(_encodeTracksJsonWorker, jsonList);
      } else {
        jsonContent = jsonEncode(jsonList);
      }

      await _writeAtomic('tracks_db.json', jsonContent);
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
    final resolved = await _resolutionService.resolveBatch(merged);
    final cleanResolved = deduplicateTracks(resolved);
    await saveTracks(cleanResolved);
    return cleanResolved;
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
      final resolved = await _resolutionService.resolveBatch(merged);
      final cleanResolved = deduplicateTracks(resolved);
      await saveTracks(cleanResolved);
      return cleanResolved;
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
      final jsonList = folders.map((f) => f.toJson()).toList();
      await _writeAtomic('folders.json', jsonEncode(jsonList));
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

  /// Loads favorites (Set of file paths) and emits to onFavoritesUpdated
  Future<Set<String>> loadFavorites() async {
    try {
      final file = await _getFile('favorites.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _cachedFavorites = jsonList.map((item) => _normalizePath(item.toString())).toSet();
          _favoritesLoaded = true;
          _favoritesUpdatedController.add(Set.unmodifiable(_cachedFavorites));
          return Set.from(_cachedFavorites);
        }
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
    _cachedFavorites = {};
    _favoritesLoaded = true;
    _favoritesUpdatedController.add(Set.unmodifiable(_cachedFavorites));
    return {};
  }

  /// Saves favorites (Set of file paths) atomically and notifies all reactive subscribers
  Future<void> saveFavorites(Set<String> favorites) async {
    try {
      final normSet = favorites.map(_normalizePath).toSet();
      _cachedFavorites = normSet;
      _favoritesLoaded = true;
      final normList = normSet.toList();
      await _writeAtomic('favorites.json', jsonEncode(normList));
      _favoritesUpdatedController.add(Set.unmodifiable(_cachedFavorites));
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
  }

  /// Toggles favorite status for a track path atomically and broadcasts to all listeners
  Future<Set<String>> toggleFavorite(String trackPath) async {
    if (!_favoritesLoaded) {
      await loadFavorites();
    }
    final norm = _normalizePath(trackPath);
    final updated = Set<String>.from(_cachedFavorites);
    if (updated.contains(norm)) {
      updated.remove(norm);
    } else {
      updated.add(norm);
    }
    await saveFavorites(updated);
    return updated;
  }

  /// Checks whether a track path is in favorites synchronously against memory cache
  bool isFavoriteSync(String trackPath) {
    return _cachedFavorites.contains(_normalizePath(trackPath));
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
      final data = {
        'playlist': playlistPaths.map(_normalizePath).toList(),
        'currentIndex': currentIndex,
      };
      await _writeAtomic('playback_state.json', jsonEncode(data));
    } catch (e) {
      debugPrint("Error saving playback state: $e");
    }
  }

  /// Releases stream controllers
  void dispose() {
    _tracksUpdatedController.close();
    _favoritesUpdatedController.close();
  }
}
