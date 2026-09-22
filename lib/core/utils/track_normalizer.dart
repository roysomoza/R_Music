import 'package:path/path.dart' as p;

/// Central utility for cleaning audio metadata, filtering junk download tags,
/// and generating strong deduplication keys.
class TrackNormalizer {
  /// Strips accents and diacritics to ensure identical matches (e.g. Canción -> Cancion)
  static String removeDiacritics(String str) {
    const withAccents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutAccents = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withAccents.length; i++) {
      str = str.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return str;
  }

  /// Normalizes a track title by stripping noise from downloaders (e.g. Snaptube, YouTube, Telegram)
  /// and returning a clean alphanumeric representation for deduplication.
  static String normalizeTitle(String rawTitle) {
    var clean = rawTitle.trim();

    // 1. Strip file extensions if present
    clean = clean.replaceAll(
      RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg|opus)$', caseSensitive: false),
      '',
    );

    // 2. Strip web rip prefixes & channel watermarks (e.g. "y2mate.com - ", "snaptube - ")
    clean = clean.replaceAll(
      RegExp(r'^(y2mate(\.is|\.com)?|snaptube|tubemate|vidmate)\s*[-_ ]*\s*', caseSensitive: false),
      '',
    );

    // 3. Strip leading track numbers (e.g. "01. ", "01 - ", "1 - ")
    clean = clean.replaceAll(RegExp(r'^\d+[\.\-_ ]+\s*'), '');

    // 4. Remove text inside parentheses or brackets containing download/bitrate noise or copies:
    // e.g. (MP3_160K), (MP3_128K), [MP3], (128kbps), (Official Video), (Snaptube), [HQ], (1), (2), (1080p), etc.
    clean = clean.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(mp3|kbps|\d+k|\d+p|snaptube|official|video|audio|lyrics?|remaster|live|en vivo|hq|hd|remix|edit|clip|letra|copia|copy|\d+)[^\)\]]*[\)\]]\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // 5. Remove trailing unparenthesized download junk e.g. _160k, -160k, _snaptube, -snaptube, _320kbps
    clean = clean.replaceAll(
      RegExp(
        r'[-_ ]+(mp3|kbps|\d+k|\d+kbps|\d+p|snaptube|_snaptube|official|audio|video|lyrics?|remaster|live|hq|hd)+$',
        caseSensitive: false,
      ),
      '',
    );

    // 6. Remove trailing underscore/hyphen copies e.g. _1, -1, _copy, -copia
    clean = clean.replaceAll(
      RegExp(
        r'[-_]+(copia|copy|\d+)$',
        caseSensitive: false,
      ),
      '',
    );

    // 6. Remove standalone noise words/phrases
    clean = clean.replaceAll(
      RegExp(
        r'\b(official video|official audio|official music video|video oficial|audio oficial|lyric video|snaptube|_snaptube|\bdownload\b|full audio|con letra)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // 7. Remove artist prefix if "Artist - Title" exists in the title itself
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2 && parts.last.trim().isNotEmpty) {
        clean = parts.sublist(1).join(' - ').trim();
      }
    }

    // 8. Remove diacritics / accents
    clean = removeDiacritics(clean);

    // 9. Convert to lowercase
    clean = clean.toLowerCase();

    // 10. Keep only alphanumeric characters (removes spaces, underscores, punctuation)
    // e.g. "Dale Don Dale" -> "daledondale"
    final alphanumeric = clean.replaceAll(RegExp(r'[^a-z0-9]'), '');

    return alphanumeric.isNotEmpty ? alphanumeric : clean.trim();
  }

  /// Normalizes an artist name for comparison, returning empty string for generic/unknown placeholders
  static String normalizeArtist(String rawArtist) {
    var clean = rawArtist.trim();
    clean = removeDiacritics(clean).toLowerCase();
    final alphanumeric = clean.replaceAll(RegExp(r'[^a-z0-9]'), '');

    const genericArtists = {
      'artistadesconocido',
      'unknownartist',
      'rmusic',
      'unknown',
      'snaptube',
      'snaptubeaudio',
      'download',
      'downloads',
      'music',
      'musica',
      'audio',
      'bluetooth',
    };

    // Treat empty, generic placeholders, and pure numeric timestamps (e.g. 1782076663328) as empty/unknown
    if (genericArtists.contains(alphanumeric) ||
        alphanumeric.isEmpty ||
        RegExp(r'^\d+$').hasMatch(alphanumeric)) {
      return '';
    }
    return alphanumeric;
  }

  /// Extracts a clean display title (preserving spaces and capital letters but removing Snaptube/bitrate junk)
  static String cleanDisplayTitle(String rawTitle, String filePath) {
    var clean = rawTitle.trim();
    if (clean.isEmpty) {
      clean = p.basenameWithoutExtension(filePath);
    }

    // Strip extension
    clean = clean.replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg|opus)$', caseSensitive: false), '');

    // Strip web rip prefixes
    clean = clean.replaceAll(RegExp(r'^(y2mate(\.is|\.com)?|snaptube|tubemate|vidmate)\s*[-_ ]*\s*', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'^\d+[\.\-_ ]+\s*'), '');

    // Strip parenthesized / bracketed downloader junk & copy numbers
    clean = clean.replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(mp3|kbps|\d+k|\d+p|snaptube|official|video|audio|lyrics?|remaster|live|en vivo|hq|hd|remix|edit|clip|letra|copia|copy|\d+)[^\)\]]*[\)\]]\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // Strip trailing download junk
    clean = clean.replaceAll(
      RegExp(
        r'[-_ ]+(mp3|kbps|\d+k|\d+kbps|\d+p|snaptube|_snaptube|official|audio|video|lyrics?|remaster|live|hq|hd)+$',
        caseSensitive: false,
      ),
      '',
    );

    // Strip trailing underscore/hyphen copies e.g. _1, -1, _copy, -copia
    clean = clean.replaceAll(
      RegExp(
        r'[-_]+(copia|copy|\d+)$',
        caseSensitive: false,
      ),
      '',
    );

    // Strip standalone noise words
    clean = clean.replaceAll(
      RegExp(
        r'\b(official video|official audio|official music video|video oficial|audio oficial|lyric video|snaptube|_snaptube|full audio|con letra)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Strip "Artist - " prefix if present in the title
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2 && parts.last.trim().isNotEmpty) {
        clean = parts.sublist(1).join(' - ').trim();
      }
    }

    // Clean extra whitespace and punctuation at ends
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'^[-_ ]+|[-_ ]+$'), '');

    return clean.isNotEmpty ? clean : p.basenameWithoutExtension(filePath);
  }

  /// Generates the strong deduplication key: [normalized_title]_[duration_in_seconds]
  /// or [normalized_artist]_[normalized_title] if duration is not yet available.
  /// NEVER appends unique random path hashes so identical audio files always match.
  static String generateDeduplicationKey({
    required String title,
    required int durationSeconds,
    String? artist,
    String? fallbackPath,
  }) {
    var effectiveTitle = title.trim();
    if (effectiveTitle.isEmpty && fallbackPath != null && fallbackPath.isNotEmpty) {
      effectiveTitle = p.basenameWithoutExtension(fallbackPath);
    }

    final normalizedTitle = normalizeTitle(effectiveTitle);
    final normalizedArt = artist != null ? normalizeArtist(artist) : '';

    if (durationSeconds > 0) {
      return '${normalizedTitle}_$durationSeconds';
    }

    if (normalizedArt.isNotEmpty) {
      return '${normalizedArt}_$normalizedTitle';
    }

    return normalizedTitle;
  }
}
