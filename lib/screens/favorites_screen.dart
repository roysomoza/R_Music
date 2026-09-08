import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';
import '../widgets/track_options_sheet.dart';
import '../widgets/track_tile.dart';

class FavoritesScreen extends StatefulWidget {
  final List<TrackModel> favoriteTracks;
  final String? currentPlayingPath;
  final List<FolderModel> folders;
  final Function(List<TrackModel>) onPlayAll;
  final Function(List<TrackModel>, int) onPlayTrack;
  final Function(String) onToggleFavorite;
  final Function(TrackModel, bool) onDeleteTrack;
  final Function(FolderModel, TrackModel) onAddToFolder;
  final Function(String, TrackModel) onCreateAndAddToFolder;

  const FavoritesScreen({
    super.key,
    required this.favoriteTracks,
    required this.currentPlayingPath,
    required this.folders,
    required this.onPlayAll,
    required this.onPlayTrack,
    required this.onToggleFavorite,
    required this.onDeleteTrack,
    required this.onAddToFolder,
    required this.onCreateAndAddToFolder,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFavorites = widget.favoriteTracks.where((track) {
      final q = _searchQuery.toLowerCase();
      return track.title.toLowerCase().contains(q) || track.artist.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Tus Favoritos',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Header Hero Section with Play All
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      // Heart Badge Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.favoriteRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.favoriteRed.withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            color: AppTheme.favoriteRed,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Count Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Canciones Favoritas',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.favoriteTracks.length} canciones guardadas',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Play All Button with Neon Glow
                      ElevatedButton.icon(
                        onPressed: filteredFavorites.isNotEmpty
                            ? () => widget.onPlayAll(filteredFavorites)
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text(
                          'Reproducir',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar within favorites
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar en tus favoritos...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.favoriteRed, size: 22),
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
                      borderSide: const BorderSide(color: AppTheme.favoriteRed, width: 1.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // List of Favorite Songs
              Expanded(
                child: filteredFavorites.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.favorite_border_rounded,
                                size: 64,
                                color: AppTheme.textMuted.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No hay favoritos que coincidan con la búsqueda.'
                                    : 'Aún no tienes canciones favoritas.',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Toca el corazón en cualquier canción para guardarla aquí.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredFavorites.length,
                        itemBuilder: (context, index) {
                          final track = filteredFavorites[index];
                          final isPlaying = widget.currentPlayingPath == track.path;

                          return TrackTile(
                            track: track,
                            isPlaying: isPlaying,
                            isFavorite: true,
                            index: index + 1,
                            onTap: () => widget.onPlayTrack(filteredFavorites, index),
                            onToggleFavorite: () => widget.onToggleFavorite(track.path),
                            onLongPress: () {
                              TrackOptionsSheet.show(
                                context: context,
                                track: track,
                                isFavorite: true,
                                folders: widget.folders,
                                onPlayNow: () => widget.onPlayTrack(filteredFavorites, index),
                                onToggleFavorite: () => widget.onToggleFavorite(track.path),
                                onAddToFolder: (f) => widget.onAddToFolder(f, track),
                                onCreateAndAddToFolder: (name) => widget.onCreateAndAddToFolder(name, track),
                                onDeleteTrack: (deletePhysical) => widget.onDeleteTrack(track, deletePhysical),
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
