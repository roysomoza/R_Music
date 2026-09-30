import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/platform/permission_handler_service.dart';
import '../../core/utils/track_normalizer.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/i_music_repository.dart';
import '../datasources/device/id3_reader_datasource.dart';
import '../datasources/device/isolates/scanner_worker.dart';
import '../datasources/local/local_database.dart';
import '../models/track_dto.dart';
import '../../models/track_model.dart';
import '../../services/metadata_resolution_service.dart';
import '../../services/music_repository.dart';

/// Concrete implementation of [IMusicRepository] following the Offline-First
/// Repository pattern with reactive streams as the Single Source of Truth.
class MusicRepositoryImpl implements IMusicRepository {
  final LocalDatabase _localDb;
  final Id3ReaderDatasource _id3Reader;
  final MetadataResolutionService _resolutionService = MetadataResolutionService();
  final MusicRepository _musicService;

  final StreamController<List<Track>> _tracksController =
      StreamController<List<Track>>.broadcast();
  final StreamController<List<Album>> _albumsController =
      StreamController<List<Album>>.broadcast();
  final StreamController<List<Artist>> _artistsController =
      StreamController<List<Artist>>.broadcast();
  final StreamController<List<Folder>> _foldersController =
      StreamController<List<Folder>>.broadcast();
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  List<Track> _cachedTracks = [];
  Set<String> _cachedFavorites = {};
  List<Folder> _cachedFolders = [];
  List<String> _customFolderPaths = [];
  bool _isInitialized = false;

  MusicRepositoryImpl({
    LocalDatabase? localDb,
    Id3ReaderDatasource? id3Reader,
    MusicRepository? musicService,
  })  : _localDb = localDb ?? LocalDatabase(),
        _id3Reader = id3Reader ?? Id3ReaderDatasource(),
        _musicService = musicService ?? MusicRepository() {
    _initFavoritesBridge();
  }

  void _initFavoritesBridge() {
    _subscriptions.add(
      _musicService.onFavoritesUpdated.listen((favs) {
        for (final item in favs) {
          final id = item.hashCode.toString();
          _cachedFavorites.add(id);
        }
        _localDb.saveFavorites(_cachedFavorites);
        _favoritesController.add(Set.unmodifiable(_cachedFavorites));
        _cachedTracks = _cachedTracks.map((t) {
          final isFav = _isFavoriteInternal(t);
          return t.copyWith(isFavorite: isFav);
        }).toList();
        _emitDerivedEntities();
      }),
    );
  }

  bool _isFavoriteInternal(Track t) {
    return _cachedFavorites.contains(t.id) ||
        _cachedFavorites.contains(t.path) ||
        _cachedFavorites.contains(TrackNormalizer.canonicalizePath(t.path)) ||
        _cachedFavorites.contains(t.path.hashCode.toString());
  }

  /// Synchronous snapshots for immediate UI access
  List<Track> get currentTracks => List.unmodifiable(_cachedTracks);
  List<Folder> get currentFolders => List.unmodifiable(_cachedFolders);
  Set<String> get currentFavorites => Set.unmodifiable(_cachedFavorites);

  @override
  Stream<List<Track>> get tracksStream => _tracksController.stream;

  @override
  Stream<List<Album>> get albumsStream => _albumsController.stream;

  @override
  Stream<List<Artist>> get artistsStream => _artistsController.stream;

  @override
  Stream<List<Folder>> get foldersStream => _foldersController.stream;

  @override
  Stream<Set<String>> get favoritesStream => _favoritesController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Load favorites via SSOT LocalDatabase (favorites_db.json)
    _cachedFavorites = await _localDb.getFavorites();
    _favoritesController.add(Set.unmodifiable(_cachedFavorites));

    // 2. Load custom folders
    _customFolderPaths = await _localDb.getCustomFolders();

    // 3. Load cached tracks and deduplicate
    final dtos = await _localDb.getTracks();
    if (dtos.isNotEmpty) {
      final rawList = dtos.map((d) {
        final domain = d.toDomain();
        return domain.copyWith(isFavorite: _isFavoriteInternal(domain));
      }).toList();

      _cachedTracks = _deduplicateTracks(rawList);
      if (_cachedTracks.length != rawList.length) {
        await _localDb.saveTracks(_cachedTracks.map((t) => TrackDto.fromDomain(t)).toList());
      }
      _emitDerivedEntities();

      // Post-startup deferred background resolution: preserves 60 FPS
      Future.delayed(const Duration(milliseconds: 600), () async {
        final resolved = await _resolveTrackArtists(_cachedTracks);
        final clean = _deduplicateTracks(resolved);
        bool changed = clean.length != _cachedTracks.length;
        if (!changed) {
          for (int i = 0; i < clean.length; i++) {
            if (clean[i].artist != _cachedTracks[i].artist || clean[i].title != _cachedTracks[i].title) {
              changed = true;
              break;
            }
          }
        }
        if (changed) {
          _cachedTracks = clean;
          await _localDb.saveTracks(_cachedTracks.map((t) => TrackDto.fromDomain(t)).toList());
          _tracksController.add(List.unmodifiable(_cachedTracks));
          _emitDerivedEntities();
        }
      });
    }

    _isInitialized = true;
  }

  @override
  Future<List<Track>> scanAndIndexStorage({
    List<String>? customPaths,
    bool forceFullScan = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Request permissions cleanly
    await PermissionHandlerService.requestStoragePermissions();

    if (customPaths != null && customPaths.isNotEmpty) {
      for (final p in customPaths) {
        if (!_customFolderPaths.contains(p)) {
          _customFolderPaths.add(p);
        }
      }
      await _localDb.saveCustomFolders(_customFolderPaths);
    }

    // 1. Collect directories to scan
    final searchDirs = await _resolveCandidateDirectories();

    // 2. Prepare known tracks map for Isolate
    final knownMap = <String, Map<String, dynamic>>{};
    for (final track in _cachedTracks) {
      knownMap[track.path] = TrackDto.fromDomain(track).toJson();
    }

    // 3. Run Isolate scanner worker (Heavy file I/O & Heuristics off the main UI thread)
    final params = ScannerWorkerParams(
      rootDirectories: searchDirs,
      knownTracksByPath: knownMap,
      minDurationMs: 30000, // Filter out < 30 seconds (Voice notes)
      minFileSizeBytes: 100 * 1024,
    );

    final rawScanned = await compute(runScannerWorker, params);

    // 4. Map back from DTOs
    final List<Track> scannedTracks = [];
    final List<Track> tracksNeedingMetadata = [];

    for (final raw in rawScanned) {
      final dto = TrackDto.fromJson(raw);
      var track = dto.toDomain();
      track = track.copyWith(isFavorite: _cachedFavorites.contains(track.id));
      scannedTracks.add(track);

      // Check if we need to enrich ID3 tags (duration is zero or generic title)
      if (track.duration == Duration.zero || track.album == 'R Music') {
        tracksNeedingMetadata.add(track);
      }
    }

    // 5. Asynchronously enrich tracks with ID3 metadata
    if (tracksNeedingMetadata.isNotEmpty) {
      final enrichedMap = <String, Track>{};
      for (final t in scannedTracks) {
        enrichedMap[t.path] = t;
      }

      // Read metadata in small non-blocking chunks
      const chunkSize = 20;
      for (var i = 0; i < tracksNeedingMetadata.length; i += chunkSize) {
        final end = (i + chunkSize < tracksNeedingMetadata.length)
            ? i + chunkSize
            : tracksNeedingMetadata.length;
        final chunk = tracksNeedingMetadata.sublist(i, end);

        await Future.wait(chunk.map((t) async {
          try {
            final meta = await _id3Reader.readMetadata(t.path);
            final enriched = t.copyWith(
              title: meta.title ?? t.title,
              artist: meta.artist ?? t.artist,
              album: meta.album ?? t.album,
              genre: meta.genre ?? t.genre,
              year: meta.year ?? t.year,
              duration: meta.durationMs != null
                  ? Duration(milliseconds: meta.durationMs!)
                  : t.duration,
              artworkPath: meta.artworkPath ?? t.artworkPath,
            );
            enrichedMap[t.path] = enriched;
          } catch (_) {}
        }));
      }

      scannedTracks.clear();
      scannedTracks.addAll(enrichedMap.values);
    }

    // Cascading metadata resolution before deduplication
    final resolvedTracks = await _resolveTrackArtists(scannedTracks);

    // Strict O(n) deduplication with TrackNormalizer
    _cachedTracks = _deduplicateTracks(resolvedTracks);

    // 6. Save to local database (SSOT)
    final dtosToPersist = _cachedTracks.map((t) => TrackDto.fromDomain(t)).toList();
    await _localDb.saveTracks(dtosToPersist);

    // 7. Update reactive streams
    _emitDerivedEntities();

    stopwatch.stop();
    debugPrint('[DMAIC Six Sigma] Scan, filter and deduplication completed in: ${stopwatch.elapsedMilliseconds}ms. Total indexed: ${_cachedTracks.length}');

    return _cachedTracks;
  }

  /// Helper to batch-resolve track artists through the cascading service off the main thread.
  Future<List<Track>> _resolveTrackArtists(List<Track> tracks) async {
    try {
      final models = tracks.map<TrackModel>((t) => TrackModel(
        id: t.id,
        path: t.path,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        dateAdded: t.dateAdded,
        fileSize: t.fileSize,
      )).toList();

      final resolvedModels = await _resolutionService.resolveBatch(models);
      final modelMap = {for (var m in resolvedModels) m.path: m};

      return tracks.map((t) {
        final m = modelMap[t.path];
        if (m != null && (m.artist != t.artist || m.title != t.title)) {
          return t.copyWith(
            title: m.title,
            artist: m.artist,
          );
        }
        return t;
      }).toList();
    } catch (e) {
      debugPrint("Error resolving track artists in repository impl: $e");
      return tracks;
    }
  }

  /// Strict O(n) Deduplication Algorithm
  /// Strict O(n) Deduplication Algorithm
  /// Merges duplicate tracks (e.g. Cancion(MP3_160K) vs Cancion(MP3_128K)) into the single best quality copy.
  List<Track> _deduplicateTracks(List<Track> tracks) {
    final Map<String, List<Track>> titleBuckets = {};

    for (final track in tracks) {
      // Rule 3: Exclude voice notes (<30s)
      if (track.duration > Duration.zero && track.duration.inSeconds < 30) {
        continue;
      }

      final cleanTitle = TrackNormalizer.cleanDisplayTitle(track.title, track.path);
      final normalizedTrack = track.copyWith(title: cleanTitle);
      final titleKey = TrackNormalizer.normalizeTitle(cleanTitle.isNotEmpty ? cleanTitle : track.title);
      titleBuckets.putIfAbsent(titleKey, () => []).add(normalizedTrack);
    }

    final List<Track> result = [];

    for (final bucket in titleBuckets.values) {
      if (bucket.length == 1) {
        result.add(bucket.first);
        continue;
      }

      final List<Track> mergedList = [];
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
          final bool preferCandidate = candidate.fileSize > existing.fileSize ||
              (candidate.artworkPath != null && existing.artworkPath == null);
          final base = preferCandidate ? candidate : existing;
          final other = preferCandidate ? existing : candidate;

          final bestDuration = base.duration > Duration.zero ? base.duration : other.duration;
          final bestArtist = candArtistNorm.isNotEmpty ? candidate.artist : existing.artist;
          final bestArtwork = base.artworkPath ?? other.artworkPath;
          final bestDate = base.dateAdded.isBefore(other.dateAdded) ? base.dateAdded : other.dateAdded;

          mergedList[matchIndex] = base.copyWith(
            duration: bestDuration,
            artist: bestArtist,
            artworkPath: bestArtwork,
            dateAdded: bestDate,
          );
        }
      }

      result.addAll(mergedList);
    }

    result.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return result;
  }

  @override
  Future<void> toggleFavorite(String trackIdOrPath) async {
    String targetId = trackIdOrPath;
    String? targetPath;
    for (final t in _cachedTracks) {
      if (t.id == trackIdOrPath || t.path == trackIdOrPath) {
        targetId = t.id;
        targetPath = t.path;
        break;
      }
    }
    if (targetId == trackIdOrPath && (trackIdOrPath.contains('/') || trackIdOrPath.contains('\\'))) {
      targetId = TrackNormalizer.canonicalizePath(trackIdOrPath).hashCode.toString();
      targetPath = trackIdOrPath;
    }

    if (_cachedFavorites.contains(targetId)) {
      _cachedFavorites.remove(targetId);
      if (targetPath != null) {
        _cachedFavorites.remove(targetPath);
        _cachedFavorites.remove(TrackNormalizer.canonicalizePath(targetPath));
      }
      _cachedFavorites.remove(trackIdOrPath);
    } else {
      _cachedFavorites.add(targetId);
    }

    await _localDb.saveFavorites(_cachedFavorites);
    _favoritesController.add(Set.unmodifiable(_cachedFavorites));

    _cachedTracks = _cachedTracks.map((t) {
      final isFav = _isFavoriteInternal(t);
      return t.copyWith(isFavorite: isFav);
    }).toList();
    _emitDerivedEntities();
  }

  @override
  Future<bool> isFavorite(String trackIdOrPath) async {
    if (_cachedFavorites.contains(trackIdOrPath)) return true;
    for (final t in _cachedTracks) {
      if (t.path == trackIdOrPath && _cachedFavorites.contains(t.id)) return true;
      if (t.id == trackIdOrPath && _cachedFavorites.contains(t.path)) return true;
    }
    final hashId = TrackNormalizer.canonicalizePath(trackIdOrPath).hashCode.toString();
    return _cachedFavorites.contains(hashId);
  }

  @override
  Future<Set<String>> getFavorites() async {
    if (!_isInitialized || _cachedFavorites.isEmpty) {
      _cachedFavorites = await _localDb.getFavorites();
    }
    return Set.unmodifiable(_cachedFavorites);
  }

  @override
  Future<void> saveCustomFolders(List<String> folders) async {
    _customFolderPaths = List.from(folders);
    await _localDb.saveCustomFolders(folders);
  }

  @override
  Future<List<String>> getCustomFolders() async {
    if (_customFolderPaths.isEmpty) {
      _customFolderPaths = await _localDb.getCustomFolders();
    }
    return List.from(_customFolderPaths);
  }

  @override
  Future<void> savePlaybackSession({
    required List<Track> playlist,
    required int currentIndex,
    required Duration position,
  }) async {
    final map = {
      'playlist': playlist.map((t) => t.path).toList(),
      'currentIndex': currentIndex,
      'positionMs': position.inMilliseconds,
    };
    await _localDb.savePlaybackSession(map);
  }

  @override
  Future<Map<String, dynamic>?> loadPlaybackSession() async {
    return _localDb.getPlaybackSession();
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _tracksController.close();
    await _albumsController.close();
    await _artistsController.close();
    await _foldersController.close();
    await _favoritesController.close();
  }

  /// Calculates and emits grouped Albums, Artists, Folders and Tracks
  void _emitDerivedEntities() {
    _tracksController.add(List.unmodifiable(_cachedTracks));

    // 1. Group Albums
    final Map<String, List<Track>> albumMap = {};
    for (final t in _cachedTracks) {
      final key = '${t.album.trim().toLowerCase()}_${t.artist.trim().toLowerCase()}';
      albumMap.putIfAbsent(key, () => []).add(t);
    }
    final albums = albumMap.entries.map((entry) {
      final first = entry.value.first;
      return Album(
        id: entry.key,
        name: first.album,
        artist: first.artist,
        year: first.year,
        artworkPath: first.artworkPath,
        tracks: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _albumsController.add(List.unmodifiable(albums));

    // 2. Group Artists
    final Map<String, List<Track>> artistMap = {};
    for (final t in _cachedTracks) {
      final key = t.artist.trim().toLowerCase();
      artistMap.putIfAbsent(key, () => []).add(t);
    }
    final artists = artistMap.entries.map((entry) {
      final first = entry.value.first;
      return Artist(
        id: entry.key,
        name: first.artist,
        tracks: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _artistsController.add(List.unmodifiable(artists));

    // 3. Group Folders
    final Map<String, List<Track>> folderMap = {};
    for (final t in _cachedTracks) {
      final parentDir = p.dirname(t.path);
      folderMap.putIfAbsent(parentDir, () => []).add(t);
    }
    final folders = folderMap.entries.map((entry) {
      return Folder(
        path: entry.key,
        name: p.basename(entry.key),
        tracks: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cachedFolders = folders;
    _foldersController.add(List.unmodifiable(folders));
  }

  /// Gathers candidate device directories based on platform
  Future<List<String>> _resolveCandidateDirectories() async {
    final List<String> paths = [];

    if (Platform.isAndroid) {
      const explicitPaths = [
        '/storage/emulated/0/snaptube/download/SnapTube Audio',
        '/storage/emulated/0/snaptube/download/Snaptube Audio',
        '/storage/emulated/0/snaptube/download',
        '/storage/emulated/0/Download/SnapTube Audio',
        '/storage/emulated/0/Download/Snaptube Audio',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Audio',
        '/sdcard/Download',
        '/sdcard/Music',
        '/storage/self/primary/Download',
        '/storage/self/primary/Music',
      ];

      for (final ep in explicitPaths) {
        if (Directory(ep).existsSync() && !paths.contains(ep)) {
          paths.add(ep);
        }
      }

      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final d in extDirs) {
            if (d.existsSync() && !paths.contains(d.path)) {
              paths.add(d.path);
            }
          }
        }
      } catch (_) {}
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final music = p.join(userProfile, 'Music');
        final downloads = p.join(userProfile, 'Downloads');
        if (Directory(music).existsSync() && !paths.contains(music)) paths.add(music);
        if (Directory(downloads).existsSync() && !paths.contains(downloads)) paths.add(downloads);
      }
    }

    try {
      final docs = await getApplicationDocumentsDirectory();
      if (docs.existsSync() && !paths.contains(docs.path)) {
        paths.add(docs.path);
      }
    } catch (_) {}

    for (final custom in _customFolderPaths) {
      if (Directory(custom).existsSync() && !paths.contains(custom)) {
        paths.add(custom);
      }
    }

    return paths;
  }
}
