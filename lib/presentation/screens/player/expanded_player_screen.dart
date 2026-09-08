import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import '../../../core/theme/app_theme.dart';
import '../../../domain/repositories/i_audio_player_repository.dart';
import '../../mvi/player/player_intent.dart';
import '../../mvi/player/player_state.dart';
import '../../mvi/player/player_store.dart';
import '../../widgets/player/equalizer_bottom_sheet.dart';
import '../../widgets/player/sleep_timer_dialog.dart';
import 'lyrics_view.dart';

/// Full-screen expanded player adhering strictly to AppTheme design language.
class ExpandedPlayerScreen extends StatefulWidget {
  final PlayerStore store;

  const ExpandedPlayerScreen({super.key, required this.store});

  static Future<void> show(BuildContext context, PlayerStore store) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, anim1, anim2) => FadeTransition(
          opacity: anim1,
          child: ExpandedPlayerScreen(store: store),
        ),
      ),
    );
  }

  @override
  State<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends State<ExpandedPlayerScreen> {
  bool _showLyrics = false;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ValueListenableBuilder<PlayerState>(
          valueListenable: widget.store.stateListenable,
          builder: (context, state, _) {
            final track = state.currentTrack;
            if (track == null) {
              return const Center(
                child: Text('Sin reproducción activa', style: TextStyle(color: AppTheme.textMuted)),
              );
            }

            final maxVal = state.duration.inMilliseconds.toDouble();
            final currVal = state.position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                children: [
                  // Top navigation bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                        color: AppTheme.textPrimary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        _showLyrics ? 'LETRAS SINCRONIZADAS' : 'REPRODUCIENDO AHORA',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _showLyrics ? Icons.music_note_rounded : Icons.lyrics_rounded,
                              size: 22,
                              color: _showLyrics ? AppTheme.accentNeonBlue : AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() => _showLyrics = !_showLyrics),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 22),
                            color: AppTheme.textSecondary,
                            onPressed: () => EqualizerBottomSheet.show(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),

                  // Center: Album Artwork or Synchronized Lyrics View
                  Expanded(
                    flex: 8,
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _showLyrics ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: (track.artworkPath != null && File(track.artworkPath!).existsSync())
                                ? Image.file(
                                    File(track.artworkPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Image.asset(
                                      'r_music_icono_full_new.png',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'r_music_icono_full_new.png',
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                      secondChild: Center(
                        child: Container(
                          height: 340,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
                          ),
                          child: LyricsView(store: widget.store),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),

                  // Track Info & Favorite Heart
                  Row(
                    children: [
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
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        iconSize: 28,
                        icon: Icon(
                          track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: track.isFavorite ? AppTheme.favoriteRed : AppTheme.textMuted,
                        ),
                        onPressed: () => widget.store.dispatch(const ToggleFavoriteCurrentIntent()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Slider & Timers
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4.0,
                      activeTrackColor: AppTheme.accentNeonBlue,
                      inactiveTrackColor: AppTheme.borderSubtle,
                      thumbColor: AppTheme.electricCyan,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                    ),
                    child: Slider(
                      value: currVal,
                      max: maxVal > 0 ? maxVal : 1.0,
                      onChanged: maxVal > 0
                          ? (val) => widget.store.dispatch(SeekIntent(Duration(milliseconds: val.toInt())))
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(state.position),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          _formatDuration(state.duration),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transport Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle
                      IconButton(
                        iconSize: 24,
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: state.isShuffle ? AppTheme.accentNeonBlue : AppTheme.textMuted,
                        ),
                        onPressed: () => widget.store.dispatch(const ToggleShuffleIntent()),
                      ),

                      // Previous
                      IconButton(
                        iconSize: 38,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: AppTheme.textPrimary,
                        onPressed: () => widget.store.dispatch(const SkipToPreviousIntent()),
                      ),

                      // Play/Pause Center Neon Button
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.neonBlueGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: state.isBuffering
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.0,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : IconButton(
                                iconSize: state.isPlaying ? 34 : 38,
                                icon: Icon(
                                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => widget.store.dispatch(const PlayPauseIntent()),
                              ),
                      ),

                      // Next
                      IconButton(
                        iconSize: 38,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: AppTheme.textPrimary,
                        onPressed: () => widget.store.dispatch(const SkipToNextIntent()),
                      ),

                      // Repeat Mode
                      IconButton(
                        iconSize: 24,
                        icon: Icon(
                          state.repeatMode == RepeatMode.one
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: state.repeatMode != RepeatMode.off
                              ? AppTheme.accentNeonBlue
                              : AppTheme.textMuted,
                        ),
                        onPressed: () => widget.store.dispatch(const CycleRepeatModeIntent()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bottom extras: Sleep Timer & Equalizer quick icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: state.isSleepTimerActive
                              ? AppTheme.accentNeonBlue
                              : AppTheme.textSecondary,
                        ),
                        icon: const Icon(Icons.bedtime_outlined, size: 18),
                        label: Text(
                          state.isSleepTimerActive
                              ? 'Timer: ${_formatDuration(state.sleepTimerRemaining ?? Duration.zero)}'
                              : 'Temporizador',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => SleepTimerDialog.show(context, widget.store),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                        ),
                        icon: const Icon(Icons.equalizer_rounded, size: 18),
                        label: const Text(
                          'Ecualizador',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => EqualizerBottomSheet.show(context),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
