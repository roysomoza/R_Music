import 'package:path/path.dart' as p;
import '../../models/track_model.dart';

/// Central utility for cleaning audio metadata, filtering junk download tags,
/// and generating strong deduplication keys.
class TrackNormalizer {
  // ──────────────────────────────────────────────────────────────────────────
  // PRECOMPILED STATIC REGEXPS (Eliminates GC allocation churn in tight loops)
  // ──────────────────────────────────────────────────────────────────────────
  static final RegExp _fileExtensionRegex = RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg|opus)$', caseSensitive: false);
  static final RegExp _webRipPrefixRegex = RegExp(r'^(y2mate(\.is|\.com)?|snaptube|tubemate|vidmate)\s*[-_ ]*\s*', caseSensitive: false);
  static final RegExp _leadingTrackNumberRegex = RegExp(r'^\d+[\.\-_ ]+\s*');
  static final RegExp _downloadNoiseBracketRegex = RegExp(r'\s*[\(\[][^\)\]]*(mp3|kbps|\d+k|\d+p|snaptube|official|video|audio|lyrics?|remaster|live|en vivo|hq|hd|remix|edit|clip|letra|copia|copy|\d+)[^\)\]]*[\)\]]\s*', caseSensitive: false);
  static final RegExp _trailingDownloadNoiseRegex = RegExp(r'[-_ ]+(mp3|kbps|\d+k|\d+kbps|\d+p|snaptube|_snaptube|official|audio|video|lyrics?|remaster|live|hq|hd)+$', caseSensitive: false);
  static final RegExp _copySuffixRegex = RegExp(r'[-_]+(copia|copy|\d+)$', caseSensitive: false);
  static final RegExp _standaloneNoiseRegex = RegExp(r'\b(official video|official audio|official music video|video oficial|audio oficial|lyric video|snaptube|_snaptube|\bdownload\b|full audio|con letra)\b', caseSensitive: false);
  static final RegExp _alphanumericOnlyRegex = RegExp(r'[^a-z0-9]');
  static final RegExp _numericOnlyRegex = RegExp(r'^\d+$');
  static final RegExp _multiWhitespaceRegExp = RegExp(r'\s+');
  static final RegExp _edgePunctuationRegExp = RegExp(r'^[-_ ]+|[-_ ]+$');

  /// Strips accents and diacritics to ensure identical matches (e.g. Canción -> Cancion)
  static String removeDiacritics(String str) {
    // Fast path: if purely ASCII, diacritics are guaranteed not present
    bool hasNonAscii = false;
    for (int i = 0; i < str.length; i++) {
      if (str.codeUnitAt(i) > 127) {
        hasNonAscii = true;
        break;
      }
    }
    if (!hasNonAscii) return str;

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
    clean = clean.replaceAll(_fileExtensionRegex, '');

    // 2. Strip web rip prefixes & channel watermarks (e.g. "y2mate.com - ", "snaptube - ")
    clean = clean.replaceAll(_webRipPrefixRegex, '');

    // 3. Strip leading track numbers (e.g. "01. ", "01 - ", "1 - ")
    clean = clean.replaceAll(_leadingTrackNumberRegex, '');

    // 4. Remove text inside parentheses or brackets containing download/bitrate noise or copies:
    clean = clean.replaceAll(_downloadNoiseBracketRegex, ' ');

    // 5. Remove trailing unparenthesized download junk e.g. _160k, -160k, _snaptube, -snaptube, _320kbps
    clean = clean.replaceAll(_trailingDownloadNoiseRegex, '');

    // 6. Remove trailing underscore/hyphen copies e.g. _1, -1, _copy, -copia
    clean = clean.replaceAll(_copySuffixRegex, '');

    // 7. Remove standalone noise words/phrases
    clean = clean.replaceAll(_standaloneNoiseRegex, ' ');

    // 8. Remove artist prefix if "Artist - Title" exists in the title itself
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2 && parts.last.trim().isNotEmpty) {
        clean = parts.sublist(1).join(' - ').trim();
      }
    }

    // 9. Remove diacritics / accents
    clean = removeDiacritics(clean);

    // 10. Convert to lowercase
    clean = clean.toLowerCase();

    // 11. Keep only alphanumeric characters (removes spaces, underscores, punctuation)
    final alphanumeric = clean.replaceAll(_alphanumericOnlyRegex, '');

    return alphanumeric.isNotEmpty ? alphanumeric : clean.trim();
  }

  /// Normalizes an artist name for comparison, returning empty string for generic/unknown placeholders
  static String normalizeArtist(String rawArtist) {
    var clean = rawArtist.trim();
    clean = removeDiacritics(clean).toLowerCase();
    final alphanumeric = clean.replaceAll(_alphanumericOnlyRegex, '');

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
        _numericOnlyRegex.hasMatch(alphanumeric)) {
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
    clean = clean.replaceAll(_fileExtensionRegex, '');

    // Strip web rip prefixes
    clean = clean.replaceAll(_webRipPrefixRegex, '');
    clean = clean.replaceAll(_leadingTrackNumberRegex, '');

    // Strip parenthesized / bracketed downloader junk & copy numbers
    clean = clean.replaceAll(_downloadNoiseBracketRegex, ' ');

    // Strip trailing download junk
    clean = clean.replaceAll(_trailingDownloadNoiseRegex, '');

    // Strip trailing underscore/hyphen copies e.g. _1, -1, _copy, -copia
    clean = clean.replaceAll(_copySuffixRegex, '');

    // Strip standalone noise words
    clean = clean.replaceAll(_standaloneNoiseRegex, ' ');

    // Strip "Artist - " prefix if present in the title
    if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      if (parts.length >= 2 && parts.last.trim().isNotEmpty) {
        clean = parts.sublist(1).join(' - ').trim();
      }
    }

    // Clean extra whitespace and punctuation at ends
    clean = clean.replaceAll(_multiWhitespaceRegExp, ' ').trim();
    clean = clean.replaceAll(_edgePunctuationRegExp, '');

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

    if (durationSeconds > 0) {
      return '${normalizedTitle}_$durationSeconds';
    }

    final normalizedArt = artist != null ? normalizeArtist(artist) : '';
    if (normalizedArt.isNotEmpty) {
      return '${normalizedArt}_$normalizedTitle';
    }

    return normalizedTitle;
  }

  /// Canonicalizes Android storage paths (/sdcard/ and /storage/self/primary/ -> /storage/emulated/0/)
  /// and normalizes path separators uniformly.
  static String canonicalizePath(String rawPath) {
    var norm = p.normalize(rawPath).replaceAll('\\', '/').trim();
    if (norm.startsWith('/sdcard/')) {
      norm = '/storage/emulated/0/${norm.substring(8)}';
    } else if (norm.startsWith('/storage/self/primary/')) {
      norm = '/storage/emulated/0/${norm.substring(22)}';
    }
    return norm;
  }

  /// Returns true if the artist string is missing, generic, or purely numeric (e.g. timestamp).
  static bool isInvalidOrGenericArtist(String? artist) {
    if (artist == null || artist.trim().isEmpty) return true;
    return normalizeArtist(artist).isEmpty;
  }

  /// Returns true if the file or title corresponds to a voice note, audio recording, or non-music file.
  static bool isNonMusic(String path, [String? title]) {
    final lowerPath = path.toLowerCase();
    final lowerTitle = (title ?? '').toLowerCase();
    return lowerPath.contains('ptt-') ||
        lowerTitle.contains('ptt-') ||
        lowerPath.contains('aud-2') ||
        lowerTitle.contains('aud-2') ||
        lowerPath.endsWith('.opus') ||
        lowerTitle.contains('resident evil 3 item');
  }

  /// Comprehensive search matcher for audio tracks.
  /// Matches a search query across track title, artist, album, and filename.
  /// Strips diacritics/accents (e.g. "Ruben" matches "Rubén") and ensures all query
  /// tokens/words are present across the track's combined metadata.
  static bool matchesSearch(TrackModel track, String rawQuery) {
    final cleanQuery = rawQuery.trim();
    if (cleanQuery.isEmpty) return true;

    final normalizedQuery = removeDiacritics(cleanQuery).toLowerCase();
    // Split by whitespace and common punctuation, keeping non-empty alphanumeric tokens
    final tokens = normalizedQuery
        .split(RegExp(r'[\s,\-_/]+'))
        .map((t) => t.replaceAll(RegExp(r'[^\w\d]'), '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;

    final rawTarget = '${track.title} ${track.artist} ${track.album} ${p.basenameWithoutExtension(track.path)}';
    final target = removeDiacritics(rawTarget).toLowerCase();

    return tokens.every((token) => target.contains(token));
  }
}
