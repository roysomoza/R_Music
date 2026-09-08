import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';

class TrackTile extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;
  final String? dateBadge;
  final int? index;

  const TrackTile({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.onLongPress,
    this.onOptionsTap,
    this.dateBadge,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isPlaying ? AppTheme.surfaceCard : AppTheme.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? AppTheme.primaryBlue.withValues(alpha: 0.7) : AppTheme.borderSubtle,
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (onLongPress != null) {
              onLongPress!();
            } else if (onOptionsTap != null) {
              onOptionsTap!();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Row(
              children: [
                // Music Icon / Index / Equalizer with Neon Glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPlaying ? AppTheme.primaryBlue : AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isPlaying
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isPlaying
                        ? const Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white,
                            size: 24,
                          )
                        : (index != null
                            ? Text(
                                '$index',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: AppTheme.accentNeonBlue,
                                size: 22,
                              )),
                  ),
                ),
                const SizedBox(width: 14),

                // Title (Single Line strict) & Artist (Immediate 2nd Line)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying ? AppTheme.accentNeonBlue : AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          if (dateBadge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHighlight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: Text(
                                dateBadge!,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Favorite Button
                IconButton(
                  iconSize: 22,
                  splashRadius: 20,
                  tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? AppTheme.favoriteRed : AppTheme.textMuted,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onToggleFavorite();
                  },
                ),

                // Options Menu / Long Press helper button
                IconButton(
                  iconSize: 20,
                  splashRadius: 20,
                  tooltip: 'Opciones',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (onOptionsTap != null) {
                      onOptionsTap!();
                    } else if (onLongPress != null) {
                      onLongPress!();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
