import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import '../core/utils/track_normalizer.dart';
import '../models/track_model.dart';

/// Represents the source or hierarchy level that resolved a track's metadata.
enum ResolutionLevel {
  none,
  tagValidation,      // Level 1
  filenameHeuristics, // Level 2
  localRulesCatalog,  // Level 3
  externalApi,        // Level 4
}

/// Result of resolving a single track's metadata.
class ResolvedMetadata {
  final String title;
  final String artist;
  final ResolutionLevel level;
  final bool changed;

  const ResolvedMetadata({
    required this.title,
    required this.artist,
    required this.level,
    required this.changed,
  });
}

/// Service that executes a 4-level cascading resolution pipeline to clean,
/// detect, and restore real artist names from numeric timestamps or generic tags.
class MetadataResolutionService {
  static const String _rulesAssetPath = 'assets/metadata/artist_signature_rules.json';

  static final RegExp _numericTimestampRegExp = RegExp(r'^\d{8,}$');
  static final RegExp _cacheFilePickerRegExp = RegExp(r'/cache/file_picker/\d{8,}/');
  static final RegExp _filenameNoiseTokensRegExp = RegExp(
    r'\s*[\(\[][^\)\]]*(mp3|kbps|\d+k|\d+p|snaptube|official|video|audio|lyrics?|remaster|live)[^\)\]]*[\)\]]\s*',
    caseSensitive: false,
  );
  static final RegExp _separatorRegExp = RegExp(r'\s+[-–—_]\s+');
  static final RegExp _leadingNumberRegExp = RegExp(r'^\d+[\.\-_ ]+\s*');
  static final RegExp _multiSpaceRegExp = RegExp(r'\s+');
  static final RegExp _inlineFlagRegExp = RegExp(r'\(\?[a-zA-Z]+\)');

  Map<String, dynamic>? _cachedRules;
  DateTime _lastExternalRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _throttleQueue = Future.value();
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  /// Loads and caches rules from assets in memory.
  Future<Map<String, dynamic>> loadRules() async {
    if (_cachedRules != null) return _cachedRules!;
    try {
      final jsonString = await rootBundle.loadString(_rulesAssetPath);
      final decoded = jsonDecode(jsonString);
      _cachedRules = (decoded as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    } catch (e) {
      debugPrint("Warning: Could not load artist signature rules from asset: $e");
      _cachedRules = <String, dynamic>{
        'id_to_artist': <String, dynamic>{},
        'title_signatures': <String, dynamic>{},
        'regex_rules': <dynamic>[],
      };
    }
    return _cachedRules!;
  }

  /// Sets in-memory rules directly (e.g. for unit testing without asset bundle).
  void setRulesForTesting(Map rules) {
    _cachedRules = rules.cast<String, dynamic>();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BATCH ISOLATE RESOLUTION (Off UI Thread - Single Isolate Transaction)
  // ──────────────────────────────────────────────────────────────────────────

  /// Resolves a full list of [TrackModel]s in a single batch Isolate.
  /// Only spawns an isolate if there are unresolved tracks.
  /// Returns the updated list with corrected artists and cleaned titles.
  Future<List<TrackModel>> resolveBatch(List<TrackModel> tracks) async {
    if (tracks.isEmpty) return tracks;

    // Fast main-thread check: do any tracks actually need resolution?
    final needsWork = tracks.any((t) =>
        TrackNormalizer.isInvalidOrGenericArtist(t.artist) ||
        _containsNumericTimestamp(t.path, t.artist));

    if (!needsWork) {
      return tracks;
    }

    final rules = await loadRules();

    // Prepare serializable payload for the Isolate
    final tracksPayload = tracks.map((t) => {
      'id': t.id,
      'path': t.path,
      'title': t.title,
      'artist': t.artist,
      'album': t.album,
      'durationMs': t.duration.inMilliseconds,
      'dateAdded': t.dateAdded.toIso8601String(),
      'fileSize': t.fileSize,
    }).toList();

    final params = {
      'tracks': tracksPayload,
      'rules': rules,
    };

    // Execute in a single isolate
    final List<dynamic> resolvedPayloads = await compute(_batchResolutionWorker, params);

    // Reconstruct updated TrackModels
    final Map<String, Map<String, dynamic>> resolvedMap = {
      for (var r in resolvedPayloads) r['path'] as String: r as Map<String, dynamic>
    };

    final List<TrackModel> result = [];
    for (final track in tracks) {
      final updated = resolvedMap[track.path];
      if (updated != null && updated['changed'] == true) {
        result.add(track.copyWith(
          title: updated['title'] as String,
          artist: updated['artist'] as String,
        ));
      } else {
        result.add(track);
      }
    }

    return result;
  }

  static bool _containsNumericTimestamp(String path, String artist) {
    if (_numericTimestampRegExp.hasMatch(artist.trim())) return true;
    return _cacheFilePickerRegExp.hasMatch(path);
  }

  /// Top-level or static worker function executed inside the Background Isolate.
  static List<Map<String, dynamic>> _batchResolutionWorker(Map<dynamic, dynamic> params) {
    final rawTracks = (params['tracks'] as List?)?.cast<dynamic>() ?? [];
    final rules = (params['rules'] as Map?)?.cast<String, dynamic>() ?? {};

    final idToArtist = (rules['id_to_artist'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final titleSignatures = (rules['title_signatures'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final regexRules = (rules['regex_rules'] as List?)?.cast<dynamic>() ?? <dynamic>[];

    final List<Map<String, dynamic>> results = [];

    for (final raw in rawTracks) {
      final trackMap = (raw as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final path = trackMap['path'] as String? ?? '';
      final currentTitle = trackMap['title'] as String? ?? '';
      final currentArtist = trackMap['artist'] as String? ?? '';

      // Skip non-music (voice notes, .opus, etc.)
      if (TrackNormalizer.isNonMusic(path, currentTitle)) {
        continue;
      }

      final resolved = _resolveSingleSync(
        path: path,
        title: currentTitle,
        artist: currentArtist,
        idToArtist: idToArtist,
        titleSignatures: titleSignatures,
        regexRules: regexRules,
      );

      results.add({
        'path': path,
        'title': resolved.title,
        'artist': resolved.artist,
        'level': resolved.level.index,
        'changed': resolved.changed,
      });
    }

    return results;
  }

  /// Synchronous cascading resolver executed inside the worker isolate.
  static ResolvedMetadata _resolveSingleSync({
    required String path,
    required String title,
    required String artist,
    required Map<String, dynamic> idToArtist,
    required Map<String, dynamic> titleSignatures,
    required List<dynamic> regexRules,
  }) {
    final canonicalPath = TrackNormalizer.canonicalizePath(path);
    final cleanTitle = TrackNormalizer.cleanDisplayTitle(title, canonicalPath);

    // ────────────────────────────────────────────────────────────────────────
    // LEVEL 1: Tag Validation
    // ────────────────────────────────────────────────────────────────────────
    if (!TrackNormalizer.isInvalidOrGenericArtist(artist)) {
      // Current artist tag is already valid and non-numeric
      return ResolvedMetadata(
        title: cleanTitle,
        artist: artist.trim(),
        level: ResolutionLevel.tagValidation,
        changed: (cleanTitle != title),
      );
    }

    // ────────────────────────────────────────────────────────────────────────
    // LEVEL 2: Filename Heuristics ('Artist - Title', 'Artist ft. Other - Title')
    // ────────────────────────────────────────────────────────────────────────
    final fileName = p.basenameWithoutExtension(canonicalPath);
    final fromFilename = _extractArtistFromFilename(fileName);
    if (fromFilename != null) {
      final extractedArtist = fromFilename['artist']!;
      final extractedTitle = fromFilename['title']!;

      if (!TrackNormalizer.isInvalidOrGenericArtist(extractedArtist)) {
        return ResolvedMetadata(
          title: extractedTitle.isNotEmpty ? extractedTitle : cleanTitle,
          artist: extractedArtist,
          level: ResolutionLevel.filenameHeuristics,
          changed: true,
        );
      }
    }

    // ────────────────────────────────────────────────────────────────────────
    // LEVEL 3: Local Rules Catalog (ID timestamps, Title signatures, Regex)
    // ────────────────────────────────────────────────────────────────────────
    // 3a. Check numeric ID in artist string or in path directory
    final rawArtistTrim = artist.trim();
    if (idToArtist.containsKey(rawArtistTrim)) {
      return ResolvedMetadata(
        title: cleanTitle,
        artist: idToArtist[rawArtistTrim] as String,
        level: ResolutionLevel.localRulesCatalog,
        changed: true,
      );
    }

    for (final entry in idToArtist.entries) {
      final id = entry.key;
      final targetArtist = entry.value as String;
      if (canonicalPath.contains(id)) {
        return ResolvedMetadata(
          title: cleanTitle,
          artist: targetArtist,
          level: ResolutionLevel.localRulesCatalog,
          changed: true,
        );
      }
    }

    // 3b. Check normalized title against title signatures
    final normTitleKey = TrackNormalizer.normalizeTitle(cleanTitle.isNotEmpty ? cleanTitle : fileName);
    if (titleSignatures.containsKey(normTitleKey)) {
      return ResolvedMetadata(
        title: cleanTitle,
        artist: titleSignatures[normTitleKey] as String,
        level: ResolutionLevel.localRulesCatalog,
        changed: true,
      );
    }

    // 3c. Check regex pattern rules
    for (final ruleObj in regexRules) {
      if (ruleObj is Map) {
        final ruleMap = ruleObj.cast<String, dynamic>();
        final pattern = ruleMap['pattern'] as String?;
        final targetArtist = ruleMap['artist'] as String?;
        if (pattern != null && targetArtist != null) {
          try {
            final cleanPattern = pattern.replaceAll(_inlineFlagRegExp, '');
            final reg = RegExp(cleanPattern, caseSensitive: false);
            if (reg.hasMatch(cleanTitle) || reg.hasMatch(canonicalPath)) {
              return ResolvedMetadata(
                title: cleanTitle,
                artist: targetArtist,
                level: ResolutionLevel.localRulesCatalog,
                changed: true,
              );
            }
          } catch (_) {}
        }
      }
    }

    // Fallback: If unresolved, assign 'Artista Desconocido' instead of a numeric timestamp
    final finalArtist = TrackNormalizer.isInvalidOrGenericArtist(artist)
        ? 'Artista Desconocido'
        : artist.trim();

    return ResolvedMetadata(
      title: cleanTitle,
      artist: finalArtist,
      level: ResolutionLevel.none,
      changed: (finalArtist != artist || cleanTitle != title),
    );
  }

  /// Extracts artist and title candidates from standard filename separators.
  static Map<String, String>? _extractArtistFromFilename(String rawFileName) {
    // Clean download tokens e.g. (MP3_160K), (Official Video)
    var name = rawFileName.replaceAll(_filenameNoiseTokensRegExp, ' ').trim();

    // Look for separators: " - ", " – ", " — ", or " _ "
    final separatorMatch = _separatorRegExp.firstMatch(name);
    if (separatorMatch != null) {
      final artistCandidate = name.substring(0, separatorMatch.start).trim();
      final titleCandidate = name.substring(separatorMatch.end).trim();

      if (artistCandidate.isNotEmpty && titleCandidate.isNotEmpty) {
        return {
          'artist': _cleanArtistName(artistCandidate),
          'title': TrackNormalizer.cleanDisplayTitle(titleCandidate, ''),
        };
      }
    }

    return null;
  }

  /// Cleans noise words from extracted artist candidate
  static String _cleanArtistName(String raw) {
    var clean = raw.trim();
    // Strip leading track numbers
    clean = clean.replaceAll(_leadingNumberRegExp, '');
    // Clean extra spaces
    clean = clean.replaceAll(_multiSpaceRegExp, ' ').trim();
    return clean;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEVEL 4: EXTERNAL API ON-DEMAND (Throttled <= 1 req/sec)
  // ──────────────────────────────────────────────────────────────────────────

  /// Asynchronously queries iTunes Search API for a single track on demand.
  /// Throttled to maximum 1 request per second to respect rate limits.
  /// Serialized through a queue to prevent race conditions from concurrent callers.
  Future<String?> resolveOnlineThrottled(String trackTitle, [String? artistHint]) {
    final completer = Completer<String?>();
    _throttleQueue = _throttleQueue.then((_) async {
      try {
        final result = await _executeThrottledQuery(trackTitle, artistHint);
        completer.complete(result);
      } catch (e) {
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<String?> _executeThrottledQuery(String trackTitle, [String? artistHint]) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastExternalRequestTime);
    if (elapsed < const Duration(seconds: 1)) {
      await Future.delayed(const Duration(seconds: 1) - elapsed);
    }
    _lastExternalRequestTime = DateTime.now();

    try {
      final cleanTitle = TrackNormalizer.cleanDisplayTitle(trackTitle, '');
      final query = Uri.encodeComponent(
        artistHint != null && artistHint.isNotEmpty
            ? '$artistHint $cleanTitle'
            : cleanTitle,
      );

      final url = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1');
      final request = await _httpClient.getUrl(url).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
        final json = jsonDecode(body);
        if (json is Map) {
          final results = json['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = (results.first as Map?)?.cast<String, dynamic>();
            final artistName = first?['artistName'] as String?;
            if (artistName != null && artistName.trim().isNotEmpty) {
              return artistName.trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("External metadata query failed for '$trackTitle': $e");
    }

    return null;
  }
}
