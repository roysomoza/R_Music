import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/folder_dto.dart';
import '../../models/track_dto.dart';

/// Offline-first local storage service handling persistent caching for tracks,
/// folders, favorites, and playback state.
class LocalDatabase {
  static const String _tracksDbFile = 'tracks_db.json';
  static const String _foldersDbFile = 'scanned_folders.json';
  static const String _favoritesDbFile = 'favorites_db.json';
  static const String _customFoldersDbFile = 'custom_folders.json';
  static const String _playbackSessionFile = 'playback_state.json';

  Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, fileName));
  }

  /// Loads tracks from persistent local storage
  Future<List<TrackDto>> getTracks() async {
    try {
      final file = await _getFile(_tracksDbFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((j) => TrackDto.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading tracks from local database: $e');
      return [];
    }
  }

  /// Saves tracks to local persistent storage atomically
  Future<void> saveTracks(List<TrackDto> tracks) async {
    try {
      final file = await _getFile(_tracksDbFile);
      final jsonList = tracks.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('Error saving tracks to local database: $e');
    }
  }

  /// Loads folder entities
  Future<List<FolderDto>> getFolders() async {
    try {
      final file = await _getFile(_foldersDbFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((j) => FolderDto.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading folders: $e');
      return [];
    }
  }

  /// Saves folder entities
  Future<void> saveFolders(List<FolderDto> folders) async {
    try {
      final file = await _getFile(_foldersDbFile);
      final jsonList = folders.map((f) => f.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('Error saving folders: $e');
    }
  }

  /// Loads favorite track IDs
  Future<Set<String>> getFavorites() async {
    try {
      final file = await _getFile(_favoritesDbFile);
      if (!await file.exists()) return {};

      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => e.toString()).toSet();
    } catch (e) {
      debugPrint('Error reading favorites: $e');
      return {};
    }
  }

  /// Saves favorite track IDs
  Future<void> saveFavorites(Set<String> favorites) async {
    try {
      final file = await _getFile(_favoritesDbFile);
      await file.writeAsString(jsonEncode(favorites.toList()), flush: true);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  /// Loads user-selected custom folder paths
  Future<List<String>> getCustomFolders() async {
    try {
      final file = await _getFile(_customFoldersDbFile);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('Error reading custom folders: $e');
      return [];
    }
  }

  /// Saves user-selected custom folder paths
  Future<void> saveCustomFolders(List<String> folders) async {
    try {
      final file = await _getFile(_customFoldersDbFile);
      await file.writeAsString(jsonEncode(folders), flush: true);
    } catch (e) {
      debugPrint('Error saving custom folders: $e');
    }
  }

  /// Loads playback state (playlist, currentIndex, positionMs)
  Future<Map<String, dynamic>?> getPlaybackSession() async {
    try {
      final file = await _getFile(_playbackSessionFile);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      return jsonDecode(content) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error reading playback session: $e');
      return null;
    }
  }

  /// Saves playback session
  Future<void> savePlaybackSession(Map<String, dynamic> state) async {
    try {
      final file = await _getFile(_playbackSessionFile);
      await file.writeAsString(jsonEncode(state), flush: true);
    } catch (e) {
      debugPrint('Error saving playback session: $e');
    }
  }
}
