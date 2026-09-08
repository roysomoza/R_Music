import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/folder_model.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';
import '../widgets/track_options_sheet.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final List<TrackModel> currentPlaylist;
  final int currentPlayingIndex;
  final Set<String> favorites;
  final List<FolderModel> folders;
  final Function(List<TrackModel>, int) onPlayTrack;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(String) onToggleFavorite;
  final VoidCallback onShuffle;
  final Function(TrackModel, bool) onDeleteTrack;
  final Function(FolderModel, TrackModel) onAddToFolder;
  final Function(String, TrackModel) onCreateAndAddToFolder;

  const HomeScreen({
    super.key,
    required this.audioPlayer,
    required this.currentPlaylist,
    required this.currentPlayingIndex,
    required this.favorites,
    required this.folders,
    required this.onPlayTrack,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleFavorite,
    required this.onShuffle,
    required this.onDeleteTrack,
    required this.onAddToFolder,
    required this.onCreateAndAddToFolder,
  });

  @override
  Widget build(BuildContext context) {
    final currentTrack = currentPlayingIndex >= 0 && currentPlayingIndex < currentPlaylist.length
        ? currentPlaylist[currentPlayingIndex]
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Row(
          children: [
            // Official Modern Neon Logo
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'r_music_icono_60_new.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(text: 'R ', style: TextStyle(color: AppTheme.accentNeonBlue)),
                  TextSpan(text: 'MUSIC', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero Now Playing Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 550;
                        return Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Official Album Art Container with Full New Logo
                            Container(
                              width: isWide ? 180 : 200,
                              height: isWide ? 180 : 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      'r_music_icono_full_new.png',
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.borderSubtle),
                                        ),
                                        child: const Text(
                                          'HI-RES',
                                          style: TextStyle(
                                            color: AppTheme.accentNeonBlue,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isWide) const SizedBox(width: 28) else const SizedBox(height: 20),

                            // Track Info & Quick Stats
                            Expanded(
                              flex: isWide ? 1 : 0,
                              child: Column(
                                crossAxisAlignment:
                                    isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      'REPRODUCIENDO AHORA',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppTheme.accentNeonBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // STRICT SINGLE LINE TITLE
                                  Text(
                                    currentTrack != null ? currentTrack.title : 'Selecciona una canción',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: isWide ? TextAlign.left : TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // STRICT ARTIST ON IMMEDIATE LINE BELOW
                                  Text(
                                    currentTrack != null
                                        ? currentTrack.artist
                                        : 'Explora la biblioteca para comenzar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: isWide ? TextAlign.left : TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Active Playlist Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Cola de Reproducción',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${currentPlaylist.length}',
                              style: const TextStyle(
                                color: AppTheme.accentNeonBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Playlist Items or Empty State
              if (currentPlaylist.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.queue_music_rounded, size: 54, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay canciones en la cola de reproducción',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Selecciona una canción en la pestaña Biblioteca para escuchar',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = currentPlaylist[index];
                      final isPlaying = index == currentPlayingIndex;
                      final isTrackFav = favorites.contains(track.path);

                      return TrackTile(
                        track: track,
                        isPlaying: isPlaying,
                        isFavorite: isTrackFav,
                        index: index + 1,
                        onTap: () => onPlayTrack(currentPlaylist, index),
                        onToggleFavorite: () => onToggleFavorite(track.path),
                        onLongPress: () {
                          TrackOptionsSheet.show(
                            context: context,
                            track: track,
                            isFavorite: isTrackFav,
                            folders: folders,
                            onPlayNow: () => onPlayTrack(currentPlaylist, index),
                            onToggleFavorite: () => onToggleFavorite(track.path),
                            onAddToFolder: (f) => onAddToFolder(f, track),
                            onCreateAndAddToFolder: (name) => onCreateAndAddToFolder(name, track),
                            onDeleteTrack: (deletePhysical) => onDeleteTrack(track, deletePhysical),
                          );
                        },
                      );
                    },
                    childCount: currentPlaylist.length,
                  ),
                ),

              // Bottom Spacing for Fixed Player Dock
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
