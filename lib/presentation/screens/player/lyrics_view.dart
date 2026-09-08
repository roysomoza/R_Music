import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../../domain/entities/lyric_line.dart';
import '../../../domain/entities/track.dart';
import '../../mvi/player/player_intent.dart';
import '../../mvi/player/player_state.dart';
import '../../mvi/player/player_store.dart';

/// Interactive synchronized lyrics view adhering to AppTheme.
class LyricsView extends StatefulWidget {
  final PlayerStore store;

  const LyricsView({super.key, required this.store});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  String? _loadedTrackPath;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _checkAndLoadLyrics(widget.store.state.currentTrack);
  }

  Future<void> _checkAndLoadLyrics(Track? track) async {
    if (track == null) {
      if (mounted) setState(() => _lyrics = []);
      return;
    }

    if (_loadedTrackPath == track.path) return;
    _loadedTrackPath = track.path;

    // Search for companion .lrc file next to the audio file
    final lrcCandidate = p.setExtension(track.path, '.lrc');
    final directPath = track.lyricsPath ?? lrcCandidate;

    if (await File(directPath).exists()) {
      final parsed = await LrcParser.parseFile(directPath);
      if (mounted) setState(() => _lyrics = parsed);
    } else {
      if (mounted) setState(() => _lyrics = []);
    }
  }

  void _scrollToActiveIndex(int activeIndex) {
    if (activeIndex != _lastActiveIndex && _scrollController.hasClients && activeIndex >= 0) {
      _lastActiveIndex = activeIndex;
      final targetOffset = (activeIndex * 55.0) - 150.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerState>(
      valueListenable: widget.store.stateListenable,
      builder: (context, state, _) {
        if (state.currentTrack?.path != _loadedTrackPath) {
          _checkAndLoadLyrics(state.currentTrack);
        }

        if (_lyrics.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 48,
                  color: AppTheme.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay letras disponibles (.LRC)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final activeIndex = LrcParser.findActiveIndex(_lyrics, state.position);
        _scrollToActiveIndex(activeIndex);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          itemCount: _lyrics.length,
          itemBuilder: (context, index) {
            final line = _lyrics[index];
            final isActive = index == activeIndex;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                widget.store.dispatch(SeekIntent(line.time));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isActive ? 20 : 16,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                    color: isActive ? AppTheme.accentNeonBlue : AppTheme.textMuted,
                    shadows: isActive
                        ? [
                            Shadow(
                              color: AppTheme.accentNeonBlue.withValues(alpha: 0.6),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
