import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../core/theme/app_theme.dart';
import '../models/track_model.dart';
import '../presentation/mvi/player/player_intent.dart';
import '../presentation/mvi/player/player_state.dart' as mvi;
import '../presentation/mvi/player/player_store.dart';
import '../presentation/screens/player/expanded_player_screen.dart';
import '../presentation/widgets/player/equalizer_bottom_sheet.dart';
import '../presentation/widgets/player/sleep_timer_dialog.dart';

/// Docked bottom player adhering to AppTheme with strict 60/120 FPS performance
/// and MVI reactive architecture support.
class PlayerDock extends StatelessWidget {
  final PlayerStore? store;
  final AudioPlayer? audioPlayer;
  final TrackModel? currentTrack;
  final bool isFavorite;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleShuffle;
  final VoidCallback? onExpandPlayer;

  const PlayerDock({
    super.key,
    this.store,
    this.audioPlayer,
    this.currentTrack,
    this.isFavorite = false,
    this.onNext,
    this.onPrevious,
    this.onToggleFavorite,
    this.onToggleShuffle,
    this.onExpandPlayer,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (store != null) {
      return ValueListenableBuilder<mvi.PlayerState>(
        valueListenable: store!.stateListenable,
        builder: (context, state, _) {
          final track = state.currentTrack;
          if (track == null) return const SizedBox.shrink();

          return _buildContainer(
            context,
            title: track.title,
            artist: track.artist,
            artworkPath: track.artworkPath,
            position: state.position,
            duration: state.duration,
            isPlaying: state.isPlaying,
            isBuffering: state.isBuffering,
            isShuffle: state.isShuffle,
            isFav: track.isFavorite,
            isSleepTimerActive: state.isSleepTimerActive,
            onSeek: (pos) => store!.dispatch(SeekIntent(pos)),
            onPlayPause: () => store!.dispatch(const PlayPauseIntent()),
            onNext: () => store!.dispatch(const SkipToNextIntent()),
            onPrevious: () => store!.dispatch(const SkipToPreviousIntent()),
            onToggleShuffle: () => store!.dispatch(const ToggleShuffleIntent()),
            onToggleFavorite: () => store!.dispatch(const ToggleFavoriteCurrentIntent()),
            onOpenSleepTimer: () => SleepTimerDialog.show(context, store!),
            onOpenEqualizer: () => EqualizerBottomSheet.show(context),
            onExpand: onExpandPlayer ?? () => ExpandedPlayerScreen.show(context, store!),
          );
        },
      );
    }

    // Fallback mode for legacy screens
    if (currentTrack == null || audioPlayer == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Duration>(
      stream: audioPlayer!.positionStream,
      builder: (context, snapPos) {
        final pos = snapPos.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: audioPlayer!.durationStream,
          builder: (context, snapDur) {
            final dur = snapDur.data ?? Duration.zero;
            return StreamBuilder<PlayerState>(
              stream: audioPlayer!.playerStateStream,
              builder: (context, snapState) {
                final pState = snapState.data;
                final isPlaying = pState?.playing ?? false;
                final isBuffering = pState?.processingState == ProcessingState.buffering ||
                    pState?.processingState == ProcessingState.loading;

                return _buildContainer(
                  context,
                  title: currentTrack!.title,
                  artist: currentTrack!.artist,
                  artworkPath: null,
                  position: pos,
                  duration: dur,
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  isShuffle: audioPlayer!.shuffleModeEnabled,
                  isFav: isFavorite,
                  isSleepTimerActive: false,
                  onSeek: (p) => audioPlayer!.seek(p),
                  onPlayPause: isPlaying ? audioPlayer!.pause : audioPlayer!.play,
                  onNext: onNext ?? () {},
                  onPrevious: onPrevious ?? () {},
                  onToggleShuffle: onToggleShuffle ?? () {},
                  onToggleFavorite: onToggleFavorite ?? () {},
                  onOpenSleepTimer: null,
                  onOpenEqualizer: () => EqualizerBottomSheet.show(context),
                  onExpand: onExpandPlayer,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContainer(
    BuildContext context, {
    required String title,
    required String artist,
    required String? artworkPath,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required bool isBuffering,
    required bool isShuffle,
    required bool isFav,
    required bool isSleepTimerActive,
    required ValueChanged<Duration> onSeek,
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleFavorite,
    required VoidCallback? onOpenSleepTimer,
    required VoidCallback onOpenEqualizer,
    required VoidCallback? onExpand,
  }) {
    final maxVal = duration.inMilliseconds.toDouble();
    final currVal = position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive Slider Bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                activeTrackColor: AppTheme.accentNeonBlue,
                inactiveTrackColor: AppTheme.borderSubtle,
                thumbColor: AppTheme.electricCyan,
              ),
              child: Slider(
                value: currVal,
                max: maxVal > 0 ? maxVal : 1.0,
                onChanged: maxVal > 0 ? (_) {} : null,
                onChangeEnd: maxVal > 0
                    ? (val) => onSeek(Duration(milliseconds: val.toInt()))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onOpenSleepTimer != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onOpenSleepTimer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bedtime_outlined,
                                  size: 13,
                                  color: isSleepTimerActive
                                      ? AppTheme.accentNeonBlue
                                      : AppTheme.textMuted,
                                ),
                                if (isSleepTimerActive) const SizedBox(width: 4),
                                if (isSleepTimerActive)
                                  const Text(
                                    'ACTIVO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentNeonBlue,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onOpenEqualizer,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          child: Icon(
                            Icons.equalizer_rounded,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Track Details + Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
              child: Row(
                children: [
                  // Album Art Thumbnail (with embedded ID3 cache support)
                  GestureDetector(
                    onTap: onExpand,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (artworkPath != null && File(artworkPath).existsSync())
                            ? Image.file(
                                File(artworkPath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'r_music_icono_60_new.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'r_music_icono_60_new.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Artist
                  Expanded(
                    child: GestureDetector(
                      onTap: onExpand,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Controls Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shuffle
                      IconButton(
                        iconSize: 20,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: isShuffle ? AppTheme.accentNeonBlue : AppTheme.textMuted,
                        ),
                        onPressed: onToggleShuffle,
                      ),

                      // Previous
                      IconButton(
                        iconSize: 28,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: AppTheme.textPrimary,
                        onPressed: onPrevious,
                      ),

                      // Play/Pause
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.neonBlueGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: isBuffering
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : IconButton(
                                iconSize: isPlaying ? 26 : 28,
                                icon: Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: onPlayPause,
                              ),
                      ),

                      // Next
                      IconButton(
                        iconSize: 28,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppTheme.textPrimary,
                        onPressed: onNext,
                      ),

                      // Favorite
                      IconButton(
                        iconSize: 22,
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? AppTheme.favoriteRed : AppTheme.textMuted,
                        ),
                        onPressed: onToggleFavorite,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
