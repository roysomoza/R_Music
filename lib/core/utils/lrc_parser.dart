import 'dart:io';
import '../../domain/entities/lyric_line.dart';

/// High-performance parser for Synchronized Lyrics (.LRC) files.
class LrcParser {
  static final RegExp _lrcLinePattern = RegExp(r'^\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)$');

  /// Parses raw LRC string content into sorted [LyricLine]s.
  static List<LyricLine> parseString(String lrcContent) {
    final List<LyricLine> lines = [];
    final rawLines = lrcContent.split('\n');

    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final match = _lrcLinePattern.firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final subStr = match.group(3) ?? '0';
        final millis = subStr.length == 2
            ? (int.tryParse(subStr) ?? 0) * 10
            : (int.tryParse(subStr) ?? 0);

        final text = (match.group(4) ?? '').trim();
        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );

        lines.add(LyricLine(time: timestamp, text: text));
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  /// Parses a local .LRC file if it exists.
  static Future<List<LyricLine>> parseFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      return parseString(content);
    } catch (_) {
      return [];
    }
  }

  /// Finds the active line index given current playback [position].
  static int findActiveIndex(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) return -1;

    for (var i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].time) {
        return i;
      }
    }
    return 0;
  }
}
