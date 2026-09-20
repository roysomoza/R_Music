import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/platform/permission_handler_service.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/audio_player_repository_impl.dart';
import '../data/repositories/music_repository_impl.dart';
import '../domain/entities/track.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../presentation/mvi/player/player_effect.dart';
import '../presentation/mvi/player/player_intent.dart';
import '../presentation/mvi/player/player_store.dart';
import '../presentation/screens/player/expanded_player_screen.dart';
import '../services/music_repository.dart';
import '../widgets/player_dock.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'favorites_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicRepository _repository = MusicRepository();
  late final AudioPlayerRepositoryImpl _audioRepo;
  late final MusicRepositoryImpl _musicRepoImpl;
  late final PlayerStore _playerStore;

  List<TrackModel> _allTracks = [];
  List<FolderModel> _folders = [];
  List<TrackModel> _currentPlaylist = [];
  int _currentPlayingIndex = -1;
  Set<String> _favorites = {};
  bool _isLoading = false;
  Uri? _defaultArtUri;

  @override
  void initState() {
    super.initState();
    _audioRepo = AudioPlayerRepositoryImpl(player: _audioPlayer);
    _musicRepoImpl = MusicRepositoryImpl();
    _playerStore = PlayerStore(playerRepo: _audioRepo, musicRepo: _musicRepoImpl);

    _playerStore.effectStream.listen((effect) {
      if (effect is ShowToastEffect) {
        _showSnackBar(effect.message);
      } else if (effect is ShowErrorEffect) {
        _showSnackBar(effect.message);
      } else if (effect is SleepTimerExpiredEffect) {
        _showSnackBar('Temporizador de apagado completado. Reproducción pausada.');
      }
    });

    _initializeApp();

    // Native Lock Screen & Notification Listener
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null &&
          _currentPlaylist.isNotEmpty &&
          index >= 0 &&
          index < _currentPlaylist.length &&
          index != _currentPlayingIndex) {
        setState(() => _currentPlayingIndex = index);
        _savePlaybackState();
      }
    });
  }

  @override
  void dispose() {
    _playerStore.dispose();
    _audioRepo.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _prepareDefaultArtwork() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final artFile = File(p.join(docDir.path, 'r_music_cover.png'));
      if (!await artFile.exists()) {
        final byteData = await rootBundle.load('r_music_icono_full_new.png');
        await artFile.writeAsBytes(byteData.buffer.asUint8List());
      }
      _defaultArtUri = Uri.file(artFile.path);
    } catch (e) {
      debugPrint("Error preparing default artwork: $e");
    }
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      // 0. Request storage and notification permissions for Android 13-16 / HyperOS
      await PermissionHandlerService.requestStoragePermissions();
      await PermissionHandlerService.requestNotificationPermission();

      // 1. Prepare artwork for system notification
      await _prepareDefaultArtwork();

      // 2. Load favorites
      _favorites = await _repository.loadFavorites();

      // 3. Load cached tracks (deduplicates automatically)
      _allTracks = await _repository.loadCachedTracks();

      // 4. Load folders
      _folders = await _repository.loadFolders();

      // 5. Load last playback state
      final lastPlayback = await _repository.loadPlaybackState();
      if (lastPlayback != null) {
        final List<dynamic> paths = lastPlayback['playlist'] as List<dynamic>? ?? [];
        final int index = lastPlayback['currentIndex'] as int? ?? -1;

        final List<TrackModel> restoredPlaylist = [];
        for (var pStr in paths) {
          final path = pStr.toString();
          final found = _allTracks.firstWhere(
            (t) => t.path == path,
            orElse: () => TrackModel(
              id: path.hashCode.toString(),
              path: path,
              title: p.basenameWithoutExtension(path),
              artist: 'Artista Desconocido',
              dateAdded: DateTime.now(),
            ),
          );
          if (await File(found.path).exists()) {
            restoredPlaylist.add(found);
          }
        }

        final cleanRestored = _repository.deduplicateTracks(restoredPlaylist);

        if (cleanRestored.isNotEmpty) {
          final safeIndex = (index >= 0 && index < cleanRestored.length) ? index : 0;
          setState(() {
            _currentPlaylist = cleanRestored;
            _currentPlayingIndex = safeIndex;
          });

          try {
            final track = restoredPlaylist[index];
            await _audioPlayer.setAudioSource(
              AudioSource.uri(
                Uri.file(track.path),
                tag: MediaItem(
                  id: track.path,
                  title: track.title,
                  artist: track.artist,
                  album: track.album,
                  artUri: _defaultArtUri,
                ),
              ),
              preload: true,
            );
          } catch (e) {
            debugPrint("Error preloading audio on startup: $e");
          }
        }
      }

      if (_currentPlaylist.isEmpty && _allTracks.isNotEmpty) {
        _currentPlaylist = List.from(_allTracks);
      }

      // 6. Background rescan to detect new audio files
      _rescanLibrary(silent: _allTracks.isNotEmpty);
    } catch (e) {
      debugPrint("Error initializing app state: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rescanLibrary({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final updatedTracks = await _repository.scanAndSaveTracks();
      if (mounted) {
        setState(() {
          _allTracks = updatedTracks;
          if (_currentPlaylist.isEmpty && updatedTracks.isNotEmpty) {
            _currentPlaylist = List.from(updatedTracks);
          }
        });

        if (!silent) {
          _showSnackBar('Biblioteca actualizada: ${_allTracks.length} canciones únicas.');
        }
      }
    } catch (e) {
      if (!silent) _showSnackBar('Error al escanear pistas: $e');
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlaybackState() async {
    if (_currentPlaylist.isNotEmpty) {
      final paths = _currentPlaylist.map((t) => t.path).toList();
      await _repository.savePlaybackState(paths, _currentPlayingIndex);
    }
  }

  Future<void> _toggleFavorite(String path) async {
    setState(() {
      if (_favorites.contains(path)) {
        _favorites.remove(path);
      } else {
        _favorites.add(path);
      }
    });
    await _repository.saveFavorites(_favorites);
  }

  void _playTrack(List<TrackModel> playlist, int index) async {
    if (playlist.isEmpty || index < 0 || index >= playlist.length) return;

    try {
      setState(() {
        _currentPlaylist = playlist;
        _currentPlayingIndex = index;
      });

      final sources = playlist.map((track) {
        return AudioSource.uri(
          Uri.file(track.path),
          tag: MediaItem(
            id: track.path,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artUri: _defaultArtUri,
          ),
        );
      }).toList();

      await _audioRepo.stop();
      // ignore: deprecated_member_use
      await _audioPlayer.setAudioSource(
        // ignore: deprecated_member_use
        ConcatenatingAudioSource(children: sources),
        initialIndex: index,
      );
      await _audioRepo.play();
      await _savePlaybackState();

      // Synchronize MVI PlayerStore
      final currentModel = playlist[index];
      final domainTrack = Track(
        id: currentModel.id,
        path: currentModel.path,
        title: currentModel.title,
        artist: currentModel.artist,
        album: currentModel.album,
        duration: currentModel.duration,
        dateAdded: currentModel.dateAdded,
        fileSize: currentModel.fileSize,
        isFavorite: _favorites.contains(currentModel.path),
      );
      final domainQueue = playlist.map((t) => Track(
        id: t.id,
        path: t.path,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        dateAdded: t.dateAdded,
        fileSize: t.fileSize,
        isFavorite: _favorites.contains(t.path),
      )).toList();
      _playerStore.dispatch(PlayTrackIntent(domainTrack, queue: domainQueue, initialIndex: index));
    } catch (e) {
      _showSnackBar('Error al reproducir el archivo: $e');
      debugPrint("Playback error: $e");
    }
  }

  void _playNext() {
    _audioPlayer.seekToNext();
  }

  void _playPrevious() {
    _audioPlayer.seekToPrevious();
  }

  void _toggleShuffle() async {
    if (_currentPlaylist.isEmpty) return;
    final isEnabled = _audioPlayer.shuffleModeEnabled;
    await _audioPlayer.setShuffleModeEnabled(!isEnabled);
    if (!isEnabled) {
      await _audioPlayer.shuffle();
    }
  }

  void _playAll(List<TrackModel> playlist) {
    if (playlist.isNotEmpty) {
      final randomIndex = Random().nextInt(playlist.length);
      _playTrack(playlist, randomIndex);
      setState(() => _selectedIndex = 0);
    }
  }

  /// Direct manual file addition with instant database persistence & deduplication
  Future<void> _addCustomFilesOrFolder() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<TrackModel> newTracks = [];
        final now = DateTime.now();

        for (var file in result.files) {
          if (file.path != null) {
            final filePath = p.normalize(file.path!).replaceAll('\\', '/');
            final fileName = p.basenameWithoutExtension(filePath);
            final parentDir = p.basename(p.dirname(filePath));

            newTracks.add(TrackModel(
              id: filePath.hashCode.toString(),
              path: filePath,
              title: fileName,
              artist: parentDir.isNotEmpty ? parentDir : 'R Music',
              album: 'R Music',
              duration: Duration.zero,
              dateAdded: now,
              fileSize: file.size,
            ));
          }
        }

        if (newTracks.isNotEmpty) {
          final updatedTracks = await _repository.addManualTracks(newTracks);
          setState(() {
            _allTracks = updatedTracks;
            if (_currentPlaylist.isEmpty) {
              _currentPlaylist = List.from(updatedTracks);
            }
          });
          _showSnackBar('Agregadas canciones a la biblioteca (duplicados omitidos).');
        }
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar archivos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOLDER & TRACK ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _createFolder(String name) async {
    try {
      final updated = await _repository.createFolder(name);
      setState(() => _folders = updated);
      _showSnackBar('Carpeta "$name" creada.');
    } catch (e) {
      _showSnackBar('Error al crear carpeta: $e');
    }
  }

  Future<void> _renameFolder(String folderId, String newName) async {
    try {
      final updated = await _repository.renameFolder(folderId, newName);
      setState(() => _folders = updated);
      _showSnackBar('Carpeta renombrada a "$newName".');
    } catch (e) {
      _showSnackBar('Error al renombrar carpeta: $e');
    }
  }

  Future<void> _deleteFolder(String folderId) async {
    try {
      final updated = await _repository.deleteFolder(folderId);
      setState(() => _folders = updated);
      _showSnackBar('Carpeta eliminada.');
    } catch (e) {
      _showSnackBar('Error al eliminar carpeta: $e');
    }
  }

  Future<void> _addTracksToFolder(String folderId, List<String> trackPaths) async {
    try {
      final updated = await _repository.addTracksToFolder(folderId, trackPaths);
      setState(() => _folders = updated);
      _showSnackBar('Se agregaron ${trackPaths.length} canciones a la carpeta.');
    } catch (e) {
      _showSnackBar('Error al agregar canciones a la carpeta: $e');
    }
  }

  Future<void> _removeTrackFromFolder(String folderId, String trackPath) async {
    try {
      final updated = await _repository.removeTrackFromFolder(folderId, trackPath);
      setState(() => _folders = updated);
      _showSnackBar('Canción removida de la carpeta.');
    } catch (e) {
      _showSnackBar('Error al remover canción: $e');
    }
  }

  Future<void> _addToFolder(FolderModel folder, TrackModel track) async {
    if (folder.trackPaths.contains(track.path)) {
      _showSnackBar('"${track.title}" ya está en la carpeta "${folder.name}".');
      return;
    }
    await _addTracksToFolder(folder.id, [track.path]);
  }

  Future<void> _createAndAddToFolder(String name, TrackModel track) async {
    try {
      final updatedFolders = await _repository.createFolder(name);
      final created = updatedFolders.firstWhere((f) => f.name == name);
      final finalFolders = await _repository.addTracksToFolder(created.id, [track.path]);
      setState(() => _folders = finalFolders);
      _showSnackBar('Carpeta "$name" creada y canción agregada.');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _deleteTrack(TrackModel track, bool deletePhysical) async {
    try {
      final updatedTracks = await _repository.deleteTrack(
        track.path,
        deleteFileFromDisk: deletePhysical,
      );

      final updatedFavorites = await _repository.loadFavorites();
      final updatedFolders = await _repository.loadFolders();

      // Check current playing
      final isPlayingDeleted = _currentPlayingIndex >= 0 &&
          _currentPlayingIndex < _currentPlaylist.length &&
          _currentPlaylist[_currentPlayingIndex].path == track.path;

      final updatedPlaylist = _currentPlaylist.where((t) => t.path != track.path).toList();

      if (isPlayingDeleted) {
        if (updatedPlaylist.isEmpty) {
          await _audioPlayer.stop();
          _currentPlayingIndex = -1;
        } else {
          // Play next available or index 0
          final nextIndex = min(_currentPlayingIndex, updatedPlaylist.length - 1);
          _playTrack(updatedPlaylist, nextIndex);
        }
      } else {
        if (_currentPlayingIndex >= updatedPlaylist.length) {
          _currentPlayingIndex = updatedPlaylist.length - 1;
        }
      }

      setState(() {
        _allTracks = updatedTracks;
        _favorites = updatedFavorites;
        _folders = updatedFolders;
        _currentPlaylist = updatedPlaylist;
      });

      _showSnackBar(deletePhysical
          ? 'Canción y archivo eliminados correctamente.'
          : 'Canción eliminada de la biblioteca.');
    } catch (e) {
      _showSnackBar('Error al eliminar canción: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderSubtle),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = _currentPlayingIndex >= 0 && _currentPlayingIndex < _currentPlaylist.length
        ? _currentPlaylist[_currentPlayingIndex]
        : null;

    final favoriteTracks = _allTracks.where((t) => _favorites.contains(t.path)).toList();
    final isFav = currentTrack != null && _favorites.contains(currentTrack.path);

    final List<Widget> screens = [
      HomeScreen(
        audioPlayer: _audioPlayer,
        currentPlaylist: _currentPlaylist,
        currentPlayingIndex: _currentPlayingIndex,
        favorites: _favorites,
        folders: _folders,
        onPlayTrack: _playTrack,
        onNext: _playNext,
        onPrevious: _playPrevious,
        onToggleFavorite: _toggleFavorite,
        onShuffle: _toggleShuffle,
        onDeleteTrack: _deleteTrack,
        onAddToFolder: _addToFolder,
        onCreateAndAddToFolder: _createAndAddToFolder,
      ),
      LibraryScreen(
        tracks: _allTracks,
        folders: _folders,
        isLoading: _isLoading,
        favorites: _favorites,
        currentPlayingPath: currentTrack?.path,
        onPlayTrack: _playTrack,
        onToggleFavorite: _toggleFavorite,
        onRefresh: () => _rescanLibrary(silent: false),
        onAddCustomFolder: _addCustomFilesOrFolder,
        onCreateFolder: _createFolder,
        onRenameFolder: _renameFolder,
        onDeleteFolder: _deleteFolder,
        onAddTracksToFolder: _addTracksToFolder,
        onRemoveTrackFromFolder: _removeTrackFromFolder,
        onDeleteTrack: _deleteTrack,
        onAddToFolder: _addToFolder,
        onCreateAndAddToFolder: _createAndAddToFolder,
      ),
      FavoritesScreen(
        favoriteTracks: favoriteTracks,
        currentPlayingPath: currentTrack?.path,
        folders: _folders,
        onPlayAll: _playAll,
        onPlayTrack: (playlist, idx) => _playTrack(playlist, idx),
        onToggleFavorite: _toggleFavorite,
        onDeleteTrack: _deleteTrack,
        onAddToFolder: _addToFolder,
        onCreateAndAddToFolder: _createAndAddToFolder,
      ),
    ];

    final isWide = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Sidebar for Large Screens / Desktop
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppTheme.surface,
              indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'r_music_icono_60_new.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: AppTheme.accentNeonBlue),
                  label: Text('Inicio'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded, color: AppTheme.accentNeonBlue),
                  label: Text('Biblioteca'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded, color: AppTheme.favoriteRed),
                  label: Text('Favoritos'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: screens,
                  ),
                ),
                // FIXED / DOCKED PLAYER CONTROLS AT THE BOTTOM
                if (currentTrack != null)
                  PlayerDock(
                    store: _playerStore,
                    audioPlayer: _audioPlayer,
                    currentTrack: currentTrack,
                    isFavorite: isFav,
                    onNext: _playNext,
                    onPrevious: _playPrevious,
                    onToggleFavorite: () => _toggleFavorite(currentTrack.path),
                    onToggleShuffle: _toggleShuffle,
                    onExpandPlayer: () => ExpandedPlayerScreen.show(context, _playerStore),
                  ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar for Mobile Screens
      bottomNavigationBar: !isWide
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              backgroundColor: AppTheme.background,
              indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Biblioteca',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: 'Favoritos',
                ),
              ],
            )
          : null,
    );
  }
}
