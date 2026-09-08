import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'theme/app_theme.dart';

class LockScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final ValueNotifier<File?> currentFileNotifier;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const LockScreen({
    super.key,
    required this.audioPlayer,
    required this.currentFileNotifier,
    required this.onNext,
    required this.onPrevious,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ValueListenableBuilder<File?>(
            valueListenable: currentFileNotifier,
            builder: (context, currentFile, _) {
              final title = currentFile != null
                  ? p.basenameWithoutExtension(currentFile.path)
                  : 'Sin canción';
              final artist = currentFile != null
                  ? p.basename(p.dirname(currentFile.path))
                  : 'R Music';

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.70),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada + Título (1 sola línea) + Artista debajo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
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
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Barra de progreso con acento azul neón
                    StreamBuilder<Duration>(
                      stream: audioPlayer.positionStream,
                      builder: (context, posSnap) {
                        final position = posSnap.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: audioPlayer.durationStream,
                          builder: (context, durSnap) {
                            final duration = durSnap.data ?? Duration.zero;
                            final maxMs = duration.inMilliseconds.toDouble();
                            final curMs = position.inMilliseconds
                                .toDouble()
                                .clamp(0.0, maxMs > 0 ? maxMs : 1.0);

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 0),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 0),
                                    activeTrackColor: AppTheme.accentNeonBlue,
                                    inactiveTrackColor: AppTheme.borderSubtle,
                                  ),
                                  child: Slider(
                                    value: curMs,
                                    max: maxMs > 0 ? maxMs : 1.0,
                                    onChanged: maxMs > 0
                                        ? (v) => audioPlayer.seek(
                                            Duration(milliseconds: v.toInt()))
                                        : null,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Controles: Anterior | Play/Pause | Siguiente
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: AppTheme.textPrimary,
                          onPressed: currentFile != null ? onPrevious : null,
                        ),

                        const SizedBox(width: 20),

                        // Play / Pause con degradado azul neón
                        StreamBuilder<PlayerState>(
                          stream: audioPlayer.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            final proc = snapshot.data?.processingState;
                            final isPlaying =
                                playing && proc != ProcessingState.completed;

                            return GestureDetector(
                              onTap: currentFile != null
                                  ? (isPlaying
                                      ? audioPlayer.pause
                                      : audioPlayer.play)
                                  : null,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.neonBlueGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 20),

                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.skip_next_rounded),
                          color: AppTheme.textPrimary,
                          onPressed: currentFile != null ? onNext : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
