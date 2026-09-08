import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../mvi/player/player_intent.dart';
import '../../mvi/player/player_store.dart';

/// Modal dialog for setting and managing the Sleep Timer.
class SleepTimerDialog extends StatelessWidget {
  final PlayerStore store;

  const SleepTimerDialog({super.key, required this.store});

  static Future<void> show(BuildContext context, PlayerStore store) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SleepTimerDialog(store: store),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: store.stateListenable,
      builder: (context, state, _) {
        final isActive = state.isSleepTimerActive;
        final remaining = state.sleepTimerRemaining ?? Duration.zero;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bedtime_rounded, color: AppTheme.accentNeonBlue, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Temporizador de Apagado',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentNeonBlue.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _formatDuration(remaining),
                        style: const TextStyle(
                          color: AppTheme.accentNeonBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick timer options
              _buildOption(
                context,
                title: '15 minutos',
                duration: const Duration(minutes: 15),
              ),
              _buildOption(
                context,
                title: '30 minutos',
                duration: const Duration(minutes: 30),
              ),
              _buildOption(
                context,
                title: '45 minutos',
                duration: const Duration(minutes: 45),
              ),
              _buildOption(
                context,
                title: '60 minutos (1 hora)',
                duration: const Duration(minutes: 60),
              ),
              if (state.duration > Duration.zero)
                _buildOption(
                  context,
                  title: 'Al finalizar la canción actual',
                  duration: state.duration - state.position,
                ),

              if (isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text(
                      'Cancelar Temporizador',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    onPressed: () {
                      store.dispatch(const CancelSleepTimerIntent());
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required Duration duration,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
        tileColor: AppTheme.surfaceElevated,
        leading: const Icon(Icons.timer_outlined, color: AppTheme.accentNeonBlue, size: 20),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        onTap: () {
          store.dispatch(SetSleepTimerIntent(duration));
          Navigator.pop(context);
        },
      ),
    );
  }
}
