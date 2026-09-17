import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';
import '../widgets/track_options_sheet.dart';
import '../widgets/track_tile.dart';

class FolderDetailScreen extends StatefulWidget {
  final FolderModel folder;
  final List<TrackModel> allTracks;
  final Set<String> favorites;
  final String? currentPlayingPath;
  final List<FolderModel> allFolders;
  final Function(List<TrackModel>, int) onPlayTrack;
  final Function(String) onToggleFavorite;
  final Function(String folderId, List<String> trackPaths) onAddTracksToFolder;
  final Function(String folderId, String trackPath) onRemoveTrackFromFolder;
  final Function(String folderId, String newName) onRenameFolder;
  final Function(String folderId) onDeleteFolder;
  final Function(TrackModel, bool deletePhysical) onDeleteTrack;
  final Function(FolderModel, TrackModel) onAddToFolder;
  final Function(String name, TrackModel) onCreateAndAddToFolder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
    required this.allTracks,
    required this.favorites,
    required this.currentPlayingPath,
    required this.allFolders,
    required this.onPlayTrack,
    required this.onToggleFavorite,
    required this.onAddTracksToFolder,
    required this.onRemoveTrackFromFolder,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onDeleteTrack,
    required this.onAddToFolder,
    required this.onCreateAndAddToFolder,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrackModel> _getFolderTracks() {
    final Map<String, TrackModel> map = {
      for (var t in widget.allTracks) t.path: t
    };

    final List<TrackModel> tracks = [];
    for (var path in widget.folder.trackPaths) {
      if (map.containsKey(path)) {
        tracks.add(map[path]!);
      }
    }
    return tracks;
  }

  void _openAddTracksModal() {
    final currentPaths = widget.folder.trackPaths.toSet();
    final availableTracks = widget.allTracks.where((t) => !currentPaths.contains(t.path)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final Set<String> selectedPaths = {};
        String modalSearch = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredAvailable = availableTracks.where((t) {
              final q = modalSearch.toLowerCase();
              return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Agregar canciones',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Seleccionadas: ${selectedPaths.length}',
                              style: const TextStyle(
                                color: AppTheme.accentNeonBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: selectedPaths.isNotEmpty
                              ? () {
                                  Navigator.pop(ctx);
                                  widget.onAddTracksToFolder(
                                    widget.folder.id,
                                    selectedPaths.toList(),
                                  );
                                  setState(() {});
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: TextField(
                      onChanged: (val) => setModalState(() => modalSearch = val),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar canciones para agregar...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentNeonBlue, size: 20),
                        filled: true,
                        fillColor: AppTheme.surfaceCard,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
                  ),

                  const Divider(color: AppTheme.borderSubtle, height: 1),

                  // List of Tracks to Add
                  Expanded(
                    child: filteredAvailable.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                availableTracks.isEmpty
                                    ? 'Todas las canciones de la biblioteca ya están en esta carpeta.'
                                    : 'No se encontraron coincidencias.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredAvailable.length,
                            itemBuilder: (context, index) {
                              final track = filteredAvailable[index];
                              final isSelected = selectedPaths.contains(track.path);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: AppTheme.primaryBlue,
                                checkColor: Colors.white,
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                secondary: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceHighlight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.music_note_rounded, color: AppTheme.accentNeonBlue, size: 20),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedPaths.add(track.path);
                                    } else {
                                      selectedPaths.remove(track.path);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.folder.name);
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
                widget.onRenameFolder(widget.folder.id, newName);
                setState(() {});
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

  void _confirmDeleteFolder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Text('Eliminar Carpeta', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w700)),
        content: Text(
          '¿Deseas eliminar la carpeta "${widget.folder.name}"? Las canciones no se borrarán de tu biblioteca.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDeleteFolder(widget.folder.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderTracks = _getFolderTracks();
    final filteredTracks = folderTracks.where((t) {
      final q = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
            color: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderSubtle),
            ),
            onSelected: (val) {
              if (val == 'rename') {
                _showRenameDialog();
              } else if (val == 'delete') {
                _confirmDeleteFolder();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: AppTheme.accentNeonBlue, size: 20),
                    SizedBox(width: 10),
                    Text('Renombrar', style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                    SizedBox(width: 10),
                    Text('Eliminar carpeta', style: TextStyle(color: AppTheme.errorRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Hero Header Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: AppTheme.neonBlueGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.folder_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${folderTracks.length} canciones en la carpeta',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons Row (Play All + Add Tracks)
                      Row(
                        children: [
                          // Play All Button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: filteredTracks.isNotEmpty
                                  ? () {
                                      final originalIndex = folderTracks.indexOf(filteredTracks.first);
                                      final playIndex = originalIndex != -1 ? originalIndex : 0;
                                      widget.onPlayTrack(folderTracks, playIndex);
                                    }
                                  : null,
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text(
                                'Reproducir',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // CLEARLY VISIBLE "Agregar canciones" BUTTON
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openAddTracksModal,
                              icon: const Icon(Icons.add_rounded, color: AppTheme.accentNeonBlue, size: 22),
                              label: const Text(
                                'Agregar canciones',
                                style: TextStyle(
                                  color: AppTheme.accentNeonBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Search inside folder
              if (folderTracks.length > 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar en esta carpeta...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentNeonBlue, size: 20),
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
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderSubtle),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // List of Songs in Folder
              Expanded(
                child: filteredTracks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No hay canciones que coincidan con la búsqueda.'
                                    : 'Esta carpeta está vacía.',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Presiona el botón "Agregar canciones" para sumar tus pistas favoritas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _openAddTracksModal,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Agregar canciones ahora'),
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
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = filteredTracks[index];
                          final isPlaying = widget.currentPlayingPath == track.path;
                          final isFav = widget.favorites.contains(track.path);
                          final originalIndex = folderTracks.indexOf(track);
                          final playIndex = originalIndex != -1 ? originalIndex : index;

                          return TrackTile(
                            track: track,
                            isPlaying: isPlaying,
                            isFavorite: isFav,
                            index: index + 1,
                            onTap: () => widget.onPlayTrack(folderTracks, playIndex),
                            onToggleFavorite: () => widget.onToggleFavorite(track.path),
                            onLongPress: () {
                              TrackOptionsSheet.show(
                                context: context,
                                track: track,
                                isFavorite: isFav,
                                folders: widget.allFolders,
                                currentFolderId: widget.folder.id,
                                onPlayNow: () => widget.onPlayTrack(folderTracks, playIndex),
                                onToggleFavorite: () => widget.onToggleFavorite(track.path),
                                onAddToFolder: (f) => widget.onAddToFolder(f, track),
                                onCreateAndAddToFolder: (name) => widget.onCreateAndAddToFolder(name, track),
                                onRemoveFromCurrentFolder: () {
                                  widget.onRemoveTrackFromFolder(widget.folder.id, track.path);
                                  setState(() {});
                                },
                                onDeleteTrack: (deletePhysical) {
                                  widget.onDeleteTrack(track, deletePhysical);
                                  setState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
