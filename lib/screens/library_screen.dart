import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';
import '../widgets/track_options_sheet.dart';
import '../widgets/track_tile.dart';
import 'folder_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  final List<TrackModel> tracks;
  final List<FolderModel> folders;
  final bool isLoading;
  final Set<String> favorites;
  final String? currentPlayingPath;
  final Function(List<TrackModel>, int) onPlayTrack;
  final Function(String) onToggleFavorite;
  final VoidCallback onRefresh;
  final VoidCallback onAddCustomFolder;
  final Function(String name) onCreateFolder;
  final Function(String folderId, String newName) onRenameFolder;
  final Function(String folderId) onDeleteFolder;
  final Function(String folderId, List<String> trackPaths) onAddTracksToFolder;
  final Function(String folderId, String trackPath) onRemoveTrackFromFolder;
  final Function(TrackModel, bool deletePhysical) onDeleteTrack;
  final Function(FolderModel, TrackModel) onAddToFolder;
  final Function(String name, TrackModel) onCreateAndAddToFolder;

  const LibraryScreen({
    super.key,
    required this.tracks,
    required this.folders,
    required this.isLoading,
    required this.favorites,
    required this.currentPlayingPath,
    required this.onPlayTrack,
    required this.onToggleFavorite,
    required this.onRefresh,
    required this.onAddCustomFolder,
    required this.onCreateFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onAddTracksToFolder,
    required this.onRemoveTrackFromFolder,
    required this.onDeleteTrack,
    required this.onAddToFolder,
    required this.onCreateAndAddToFolder,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeSort = 'date'; // 'date', 'title', 'artist'
  int _selectedTabIndex = 0; // 0 = Canciones, 1 = Carpetas

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateBadge(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0 && dt.day == now.day) {
      return 'Hoy';
    } else if (diff.inDays <= 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  }

  /// Groups tracks by Date Added period
  Map<String, List<TrackModel>> _groupTracksByDate(List<TrackModel> trackList) {
    final Map<String, List<TrackModel>> groups = {
      'Recién Agregadas': [],
      'Esta Semana': [],
      'Este Mes': [],
      'Anteriores': [],
    };

    final now = DateTime.now();

    for (var track in trackList) {
      final diff = now.difference(track.dateAdded);
      if (diff.inDays <= 1 && track.dateAdded.day == now.day) {
        groups['Recién Agregadas']!.add(track);
      } else if (diff.inDays <= 7) {
        groups['Esta Semana']!.add(track);
      } else if (diff.inDays <= 30) {
        groups['Este Mes']!.add(track);
      } else {
        groups['Anteriores']!.add(track);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: AppTheme.accentNeonBlue),
            SizedBox(width: 10),
            Text(
              'Nueva Carpeta',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Nombre de la carpeta',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppTheme.surfaceCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                widget.onCreateFolder(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Crear', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(FolderModel folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded, color: AppTheme.accentNeonBlue),
                title: Text(folder.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text('${folder.trackPaths.length} canciones', style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              const Divider(color: AppTheme.borderSubtle, height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppTheme.accentNeonBlue),
                title: const Text('Renombrar carpeta', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameFolderDialog(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
                title: const Text('Eliminar carpeta', style: TextStyle(color: AppTheme.errorRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteFolder(folder.id);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameFolderDialog(FolderModel folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Text('Renombrar Carpeta', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nuevo nombre',
            filled: true,
            fillColor: AppTheme.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                widget.onRenameFolder(folder.id, newName);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // All tracks sorted according to active sort mode
    final allTracks = List<TrackModel>.from(widget.tracks);
    if (_activeSort == 'title') {
      allTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_activeSort == 'artist') {
      allTracks.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    } else {
      allTracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    }

    // Filter tracks by search query
    final List<TrackModel> filteredTracks = _searchQuery.isEmpty
        ? allTracks
        : allTracks.where((t) {
            final q = _searchQuery.toLowerCase();
            return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q);
          }).toList();

    final dateGroups = _groupTracksByDate(filteredTracks);

    // Filter folders by search query
    final filteredFolders = widget.folders.where((f) {
      final q = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Biblioteca',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Escanear música del dispositivo',
            icon: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentNeonBlue),
                  )
                : const Icon(Icons.sync_rounded, color: AppTheme.accentNeonBlue),
            onPressed: widget.isLoading ? null : widget.onRefresh,
          ),
          IconButton(
            tooltip: 'Agregar archivo o carpeta manualmente',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.textPrimary),
            onPressed: widget.onAddCustomFolder,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // ── TOGGLE SELECTOR: CANCIONES VS CARPETAS ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 10.0),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      // Canciones Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTabIndex = 0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: _selectedTabIndex == 0 ? AppTheme.neonBlueGradient : null,
                              color: _selectedTabIndex == 0 ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTabIndex == 0
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  size: 18,
                                  color: _selectedTabIndex == 0 ? Colors.white : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Canciones (${widget.tracks.length})',
                                  style: TextStyle(
                                    color: _selectedTabIndex == 0 ? Colors.white : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: _selectedTabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Carpetas Tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTabIndex = 1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: _selectedTabIndex == 1 ? AppTheme.neonBlueGradient : null,
                              color: _selectedTabIndex == 1 ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTabIndex == 1
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_rounded,
                                  size: 18,
                                  color: _selectedTabIndex == 1 ? Colors.white : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Carpetas (${widget.folders.length})',
                                  style: TextStyle(
                                    color: _selectedTabIndex == 1 ? Colors.white : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: _selectedTabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _selectedTabIndex == 0
                        ? 'Buscar por título, artista o Snaptube...'
                        : 'Buscar carpeta...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentNeonBlue, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                    ),
                  ),
                ),
              ),

              // Sort and filters bar (only for tracks tab)
              if (_selectedTabIndex == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredTracks.length} pistas indexadas',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          _buildSortChip('date', 'Fecha', Icons.calendar_today_rounded),
                          const SizedBox(width: 8),
                          _buildSortChip('title', 'A-Z', Icons.sort_by_alpha_rounded),
                        ],
                      ),
                    ],
                  ),
                )
              else
                // Carpetas Action Bar: Botón claramente visible "Crear carpeta"
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredFolders.length} carpetas creadas',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // PROMINENT BOTÓN "CREAR CARPETA"
                      ElevatedButton.icon(
                        onPressed: _showCreateFolderDialog,
                        icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                        label: const Text('Crear carpeta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(color: AppTheme.borderSubtle, height: 1),

              // ── MAIN CONTENT VIEW (CANCIONES OR CARPETAS) ──
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildTracksView(allTracks, filteredTracks, dateGroups)
                    : _buildFoldersView(filteredFolders),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRACKS VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTracksView(List<TrackModel> allTracks, List<TrackModel> filteredTracks, Map<String, List<TrackModel>> dateGroups) {
    if (widget.isLoading && widget.tracks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentNeonBlue),
            SizedBox(height: 16),
            Text(
              'Escaneando canciones en el dispositivo...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (filteredTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_off_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No se encontraron canciones coincidentes.'
                    : 'No se encontraron pistas de música.',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Usa el botón de escaneo o agrega canciones con el selector.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Escanear Dispositivo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _activeSort == 'date' && _searchQuery.isEmpty
          ? dateGroups.entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length)
          : filteredTracks.length,
      itemBuilder: (context, index) {
        if (_activeSort == 'date' && _searchQuery.isEmpty) {
          int runningCount = 0;
          for (var entry in dateGroups.entries) {
            if (index == runningCount) {
              return _buildDateGroupHeader(entry.key, entry.value.length);
            }
            runningCount++;
            if (index < runningCount + entry.value.length) {
              final trackIndex = index - runningCount;
              final track = entry.value[trackIndex];
              final isPlaying = widget.currentPlayingPath == track.path;
              final isFav = widget.favorites.contains(track.path);

              return TrackTile(
                track: track,
                isPlaying: isPlaying,
                isFavorite: isFav,
                dateBadge: _formatDateBadge(track.dateAdded),
                onTap: () {
                  final originalIndex = allTracks.indexOf(track);
                  final playIndex = originalIndex != -1 ? originalIndex : 0;
                  widget.onPlayTrack(allTracks, playIndex);
                },
                onToggleFavorite: () => widget.onToggleFavorite(track.path),
                onLongPress: () {
                  final originalIndex = allTracks.indexOf(track);
                  final playIndex = originalIndex != -1 ? originalIndex : 0;
                  TrackOptionsSheet.show(
                    context: context,
                    track: track,
                    isFavorite: isFav,
                    folders: widget.folders,
                    onPlayNow: () => widget.onPlayTrack(allTracks, playIndex),
                    onToggleFavorite: () => widget.onToggleFavorite(track.path),
                    onAddToFolder: (f) => widget.onAddToFolder(f, track),
                    onCreateAndAddToFolder: (name) => widget.onCreateAndAddToFolder(name, track),
                    onDeleteTrack: (deletePhysical) => widget.onDeleteTrack(track, deletePhysical),
                  );
                },
              );
            }
            runningCount += entry.value.length;
          }
          return const SizedBox.shrink();
        } else {
          final track = filteredTracks[index];
          final isPlaying = widget.currentPlayingPath == track.path;
          final isFav = widget.favorites.contains(track.path);
          final originalIndex = allTracks.indexOf(track);
          final playIndex = originalIndex != -1 ? originalIndex : index;

          return TrackTile(
            track: track,
            isPlaying: isPlaying,
            isFavorite: isFav,
            dateBadge: _formatDateBadge(track.dateAdded),
            onTap: () => widget.onPlayTrack(allTracks, playIndex),
            onToggleFavorite: () => widget.onToggleFavorite(track.path),
            onLongPress: () {
              TrackOptionsSheet.show(
                context: context,
                track: track,
                isFavorite: isFav,
                folders: widget.folders,
                onPlayNow: () => widget.onPlayTrack(allTracks, playIndex),
                onToggleFavorite: () => widget.onToggleFavorite(track.path),
                onAddToFolder: (f) => widget.onAddToFolder(f, track),
                onCreateAndAddToFolder: (name) => widget.onCreateAndAddToFolder(name, track),
                onDeleteTrack: (deletePhysical) => widget.onDeleteTrack(track, deletePhysical),
              );
            },
          );
        }
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOLDERS VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFoldersView(List<FolderModel> filteredFolders) {
    if (filteredFolders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHighlight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Icon(
                  Icons.create_new_folder_rounded,
                  size: 36,
                  color: AppTheme.accentNeonBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No se encontraron carpetas coincidentes.'
                    : 'Aún no tienes carpetas creadas.',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Organiza tus canciones por listas, géneros o estado de ánimo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showCreateFolderDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear primera carpeta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = filteredFolders[index];

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FolderDetailScreen(
                      folder: folder,
                      allTracks: widget.tracks,
                      favorites: widget.favorites,
                      currentPlayingPath: widget.currentPlayingPath,
                      allFolders: widget.folders,
                      onPlayTrack: widget.onPlayTrack,
                      onToggleFavorite: widget.onToggleFavorite,
                      onAddTracksToFolder: widget.onAddTracksToFolder,
                      onRemoveTrackFromFolder: widget.onRemoveTrackFromFolder,
                      onRenameFolder: widget.onRenameFolder,
                      onDeleteFolder: widget.onDeleteFolder,
                      onDeleteTrack: widget.onDeleteTrack,
                      onAddToFolder: widget.onAddToFolder,
                      onCreateAndAddToFolder: widget.onCreateAndAddToFolder,
                    ),
                  ),
                );
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showFolderOptions(folder);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Folder Icon with Neon Gradient Box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppTheme.neonBlueGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.folder_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Folder Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${folder.trackPaths.length} canciones',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Options 3-dots button
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                      onPressed: () => _showFolderOptions(folder),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateGroupHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppTheme.neonBlueGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.accentNeonBlue,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String key, String label, IconData icon) {
    final isSelected = _activeSort == key;
    return GestureDetector(
      onTap: () => setState(() => _activeSort = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.18) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.accentNeonBlue : AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentNeonBlue : AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
