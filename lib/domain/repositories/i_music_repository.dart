import '../entities/album.dart';
import '../entities/artist.dart';
import '../entities/folder.dart';
import '../entities/track.dart';

/// Contract for the Offline-First Music Repository.
/// Acts as the Single Source of Truth (SSOT) exposing reactive streams.
abstract class IMusicRepository {
  /// Reactive stream of all deduplicated and filtered tracks
  Stream<List<Track>> get tracksStream;

  /// Reactive stream of albums grouped from tracks
  Stream<List<Album>> get albumsStream;

  /// Reactive stream of artists grouped from tracks
  Stream<List<Artist>> get artistsStream;

  /// Reactive stream of physical music folders
  Stream<List<Folder>> get foldersStream;

  /// Reactive stream of favorite track IDs
  Stream<Set<String>> get favoritesStream;

  /// Initializes local cache and streams
  Future<void> initialize();

  /// Executes background storage scan, heuristic filtering, and deduplication
  Future<List<Track>> scanAndIndexStorage({
    List<String>? customPaths,
    bool forceFullScan = false,
  });

  /// Toggles favorite status for a given track
  Future<void> toggleFavorite(String trackId);

  /// Checks if a track is marked as favorite
  Future<bool> isFavorite(String trackId);

  /// Retrieves current favorite track IDs
  Future<Set<String>> getFavorites();

  /// Saves custom user-selected folder paths to scan
  Future<void> saveCustomFolders(List<String> folders);

  /// Loads custom user-selected folder paths
  Future<List<String>> getCustomFolders();

  /// Persists current player queue and index for session restoration
  Future<void> savePlaybackSession({
    required List<Track> playlist,
    required int currentIndex,
    required Duration position,
  });

  /// Loads last recorded playback session
  Future<Map<String, dynamic>?> loadPlaybackSession();

  /// Releases resources and closes reactive streams
  Future<void> dispose();
}
