import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioMetadataResult {
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? durationMs;
  final String? artworkPath;

  const AudioMetadataResult({
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.durationMs,
    this.artworkPath,
  });
}

/// Datasource for extracting ID3/Metadata tags and embedded artworks.
class Id3ReaderDatasource {
  Directory? _artworkCacheDir;

  Future<Directory> _getArtworkCacheDir() async {
    if (_artworkCacheDir != null) return _artworkCacheDir!;
    final baseDir = await getApplicationSupportDirectory();
    final artDir = Directory(p.join(baseDir.path, 'artworks'));
    if (!await artDir.exists()) {
      await artDir.create(recursive: true);
    }
    _artworkCacheDir = artDir;
    return artDir;
  }

  /// Safely reads metadata tags from an audio file.
  /// If artwork exists, it is saved into a local cache file for high-performance rendering.
  Future<AudioMetadataResult> readMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const AudioMetadataResult();
      }

      final tag = await AudioTags.read(filePath);
      if (tag == null) {
        return const AudioMetadataResult();
      }

      String? artworkPath;
      if (tag.pictures.isNotEmpty) {
        try {
          final firstPic = tag.pictures.first;
          final Uint8List bytes = firstPic.bytes;
          if (bytes.isNotEmpty) {
            final cacheDir = await _getArtworkCacheDir();
            final artFile = File(p.join(cacheDir.path, '${filePath.hashCode}.png'));
            if (!await artFile.exists() || (await artFile.length()) == 0) {
              await artFile.writeAsBytes(bytes);
            }
            artworkPath = artFile.path;
          }
        } catch (e) {
          debugPrint('Error saving artwork for $filePath: $e');
        }
      }

      final durationSec = tag.duration;
      final durationMs = durationSec != null && durationSec > 0 ? durationSec * 1000 : null;

      return AudioMetadataResult(
        title: tag.title?.trim().isNotEmpty == true ? tag.title!.trim() : null,
        artist: tag.trackArtist?.trim().isNotEmpty == true
            ? tag.trackArtist!.trim()
            : (tag.albumArtist?.trim().isNotEmpty == true ? tag.albumArtist!.trim() : null),
        album: tag.album?.trim().isNotEmpty == true ? tag.album!.trim() : null,
        genre: tag.genre?.trim().isNotEmpty == true ? tag.genre!.trim() : null,
        year: tag.year,
        durationMs: durationMs,
        artworkPath: artworkPath,
      );
    } catch (e) {
      debugPrint('Error reading ID3 tags for $filePath: $e');
      return const AudioMetadataResult();
    }
  }
}
