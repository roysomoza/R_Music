import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';

class TrackOptionsSheet {
  static Future<void> show({
    required BuildContext context,
    required TrackModel track,
    required bool isFavorite,
    required List<FolderModel> folders,
    String? currentFolderId,
    required VoidCallback onPlayNow,
    required VoidCallback onToggleFavorite,
    required Function(FolderModel) onAddToFolder,
    required Function(String name) onCreateAndAddToFolder,
    VoidCallback? onRemoveFromCurrentFolder,
    required Function(bool deletePhysicalFile) onDeleteTrack,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Track Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 10,
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: AppTheme.borderSubtle, height: 20),
                ),

                // Actions List
                _buildActionTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: AppTheme.accentNeonBlue,
                  title: 'Reproducir ahora',
                  onTap: () {
                    Navigator.pop(ctx);
                    onPlayNow();
                  },
                ),

                _buildActionTile(
                  icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconColor: isFavorite ? AppTheme.favoriteRed : AppTheme.textPrimary,
                  title: isFavorite ? 'Quitar de Favoritos' : 'Agregar a Favoritos',
                  onTap: () {
                    Navigator.pop(ctx);
                    onToggleFavorite();
                  },
                ),

                _buildActionTile(
                  icon: Icons.create_new_folder_rounded,
                  iconColor: AppTheme.accentNeonBlue,
                  title: 'Agregar a carpeta existente',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFolderPicker(
                      context: context,
                      folders: folders,
                      track: track,
                      onAddToFolder: onAddToFolder,
                      onCreateAndAddToFolder: onCreateAndAddToFolder,
                    );
                  },
                ),

                if (currentFolderId != null && onRemoveFromCurrentFolder != null)
                  _buildActionTile(
                    icon: Icons.folder_delete_rounded,
                    iconColor: Colors.orangeAccent,
                    title: 'Quitar de esta carpeta',
                    onTap: () {
                      Navigator.pop(ctx);
                      onRemoveFromCurrentFolder();
                    },
                  ),

                _buildActionTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppTheme.errorRed,
                  title: 'Eliminar canción',
                  textColor: AppTheme.errorRed,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteTrack(context, track, onDeleteTrack);
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color textColor = AppTheme.textPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  /// Folder Picker Modal
  static void _showFolderPicker({
    required BuildContext context,
    required List<FolderModel> folders,
    required TrackModel track,
    required Function(FolderModel) onAddToFolder,
    required Function(String name) onCreateAndAddToFolder,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seleccionar Carpeta',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreateFolderDialog(
                            context: context,
                            onCreateFolder: (name) => onCreateAndAddToFolder(name),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, color: AppTheme.accentNeonBlue, size: 20),
                        label: const Text(
                          'Nueva',
                          style: TextStyle(color: AppTheme.accentNeonBlue, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.borderSubtle, height: 1),
                Expanded(
                  child: folders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 50, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No tienes carpetas creadas aún',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showCreateFolderDialog(
                                      context: context,
                                      onCreateFolder: (name) => onCreateAndAddToFolder(name),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Crear primera carpeta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: folders.length,
                          itemBuilder: (context, index) {
                            final folder = folders[index];
                            final alreadyContains = folder.trackPaths.contains(track.path);

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: const Icon(Icons.folder_rounded, color: AppTheme.accentNeonBlue, size: 22),
                              ),
                              title: Text(
                                folder.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${folder.trackPaths.length} canciones',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              trailing: alreadyContains
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceHighlight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Ya agregada',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                              onTap: () {
                                Navigator.pop(ctx);
                                onAddToFolder(folder);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Create Folder Dialog
  static void _showCreateFolderDialog({
    required BuildContext context,
    required Function(String name) onCreateFolder,
  }) {
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
            Text('Nueva Carpeta', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Nombre de la carpeta (ej. Rock, Favoritas...)',
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
                onCreateFolder(name);
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

  /// Confirm Delete Track Dialog
  static void _confirmDeleteTrack(
    BuildContext context,
    TrackModel track,
    Function(bool deletePhysicalFile) onDeleteTrack,
  ) {
    bool deletePhysical = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.borderSubtle),
            ),
            title: const Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed),
                SizedBox(width: 10),
                Text(
                  'Eliminar canción',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Estás seguro de que deseas eliminar "${track.title}" de tu reproductor?',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setDialogState(() => deletePhysical = !deletePhysical),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: deletePhysical,
                          activeColor: AppTheme.errorRed,
                          onChanged: (val) => setDialogState(() => deletePhysical = val ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'Eliminar también el archivo físico del almacenamiento',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onDeleteTrack(deletePhysical);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }
}
