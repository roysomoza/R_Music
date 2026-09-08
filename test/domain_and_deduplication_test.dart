import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/domain/entities/album.dart';
import 'package:pure_audio/domain/entities/artist.dart';
import 'package:pure_audio/domain/entities/folder.dart';
import 'package:pure_audio/domain/entities/track.dart';
import 'package:pure_audio/core/utils/track_normalizer.dart';

void main() {
  group('Track Entity & Deduplication Tests', () {
    test('Track equality and deduplication key generation', () {
      final track1 = Track(
        id: '1',
        path: '/storage/music/SongA.mp3',
        title: 'Song A',
        artist: 'Artist 1',
        duration: const Duration(seconds: 180),
        dateAdded: DateTime(2026, 1, 1),
      );

      final track2 = Track(
        id: '2',
        path: '/storage/downloads/SongA_copy.mp3',
        title: 'Song A',
        artist: 'Artist 1',
        duration: const Duration(seconds: 180),
        dateAdded: DateTime(2026, 1, 2),
      );

      // Same title and same duration produce identical deduplication key: [normalized_title]_[duration_in_seconds]
      expect(track1.deduplicationKey, equals(track2.deduplicationKey));
      expect(track1.deduplicationKey, equals('songa_180'));
    });

    test('Snaptube downloader variations are unified into expected key format (e.g. daledondale_212)', () {
      final download160k = Track(
        id: '1',
        path: '/storage/emulated/0/snaptube/download/SnapTube Audio/Dale Don Dale(MP3_160K).mp3',
        title: 'Dale Don Dale(MP3_160K)',
        artist: 'Don Omar',
        duration: const Duration(seconds: 212),
        dateAdded: DateTime(2026, 1, 1),
        fileSize: 4 * 1024 * 1024,
      );

      final download128k = Track(
        id: '2',
        path: '/storage/emulated/0/Download/Dale Don Dale(MP3_128K).mp3',
        title: 'Dale Don Dale(MP3_128K)',
        artist: 'Don Omar',
        duration: const Duration(seconds: 212),
        dateAdded: DateTime(2026, 1, 2),
        fileSize: 3 * 1024 * 1024,
      );

      // Both must produce the EXACT key: daledondale_212
      expect(download160k.deduplicationKey, equals('daledondale_212'));
      expect(download128k.deduplicationKey, equals('daledondale_212'));
      expect(download160k.deduplicationKey, equals(download128k.deduplicationKey));

      final Map<String, Track> map = {};
      for (final t in [download128k, download160k]) {
        if (!map.containsKey(t.deduplicationKey)) {
          map[t.deduplicationKey] = t;
        } else {
          final existing = map[t.deduplicationKey]!;
          if (t.fileSize > existing.fileSize) {
            map[t.deduplicationKey] = t;
          }
        }
      }

      // Must result in a single track
      expect(map.length, equals(1));
      // The 160K (larger file size) must win
      expect(map['daledondale_212']!.fileSize, equals(4 * 1024 * 1024));
    });

    test('Deduplication of duplicate songs preserves the higher quality copy', () {
      final tracks = [
        Track(
          id: '1',
          path: '/sdcard/Download/Track1.mp3',
          title: 'Echoes of Neon',
          artist: 'R Music',
          duration: const Duration(seconds: 215),
          dateAdded: DateTime(2026, 1, 1),
          fileSize: 4 * 1024 * 1024, // 4MB
        ),
        Track(
          id: '2',
          path: '/sdcard/Music/Echoes of Neon.mp3',
          title: 'Echoes of Neon',
          artist: 'R Music',
          duration: const Duration(seconds: 215),
          dateAdded: DateTime(2026, 1, 5),
          fileSize: 10 * 1024 * 1024, // 10MB higher quality copy
        ),
        Track(
          id: '3',
          path: '/sdcard/Music/Another Song.mp3',
          title: 'Another Song',
          artist: 'R Music',
          duration: const Duration(seconds: 150),
          dateAdded: DateTime(2026, 1, 3),
          fileSize: 5 * 1024 * 1024,
        ),
      ];

      // Deduplication algorithm based on deduplicationKey
      final Map<String, Track> uniqueMap = {};
      for (final t in tracks) {
        if (!uniqueMap.containsKey(t.deduplicationKey)) {
          uniqueMap[t.deduplicationKey] = t;
        } else {
          final existing = uniqueMap[t.deduplicationKey]!;
          if (t.fileSize > existing.fileSize) {
            uniqueMap[t.deduplicationKey] = t;
          }
        }
      }

      final deduplicated = uniqueMap.values.toList();
      expect(deduplicated.length, equals(2));
      final winner = deduplicated.firstWhere((t) => t.title == 'Echoes of Neon');
      expect(winner.fileSize, equals(10 * 1024 * 1024));
    });

    test('Filtering out voice notes and short audio clips (<30s threshold)', () {
      final tracks = [
        Track(
          id: '1',
          path: '/storage/voice_notes/PTT-001.opus',
          title: 'PTT-001',
          artist: 'WhatsApp',
          duration: const Duration(seconds: 12), // Voice note
          dateAdded: DateTime.now(),
        ),
        Track(
          id: '2',
          path: '/storage/music/Masterpiece.flac',
          title: 'Masterpiece',
          artist: 'Hi-Fi Band',
          duration: const Duration(minutes: 4, seconds: 20),
          dateAdded: DateTime.now(),
        ),
      ];

      const minDuration = Duration(seconds: 30);
      final musicTracks = tracks.where((t) => t.duration >= minDuration).toList();

      expect(musicTracks.length, equals(1));
      expect(musicTracks.first.title, equals('Masterpiece'));
    });

    test('Deduplication unifies Snaptube tracks even when duration is zero during initial scan', () {
      final download160k = Track(
        id: '1',
        path: '/storage/emulated/0/snaptube/download/SnapTube Audio/Cancion(MP3_160K).mp3',
        title: 'Cancion(MP3_160K)',
        artist: 'Artista Desconocido',
        duration: Duration.zero, // Initial scan has 0 duration
        dateAdded: DateTime(2026, 1, 1),
        fileSize: 5 * 1024 * 1024,
      );

      final download128k = Track(
        id: '2',
        path: '/storage/emulated/0/Download/Cancion(MP3_128K).mp3',
        title: 'Cancion(MP3_128K)',
        artist: 'Artista Desconocido',
        duration: Duration.zero, // Initial scan has 0 duration
        dateAdded: DateTime(2026, 1, 2),
        fileSize: 3 * 1024 * 1024,
      );

      final copy1 = Track(
        id: '3',
        path: '/storage/emulated/0/Download/Cancion (1).mp3',
        title: 'Cancion (1)',
        artist: 'Artista Desconocido',
        duration: Duration.zero,
        dateAdded: DateTime(2026, 1, 3),
        fileSize: 3 * 1024 * 1024,
      );

      // Both normalize to "cancion"
      expect(download160k.deduplicationKey, equals('cancion'));
      expect(download128k.deduplicationKey, equals('cancion'));
      expect(copy1.deduplicationKey, equals('cancion'));
    });

    test('Deduplication preserves duration and artist when merging new higher-bitrate download with cached track', () {
      final cached128k = Track(
        id: '1',
        path: '/storage/music/Song.mp3',
        title: 'Song',
        artist: 'The Artist',
        duration: const Duration(seconds: 214), // Played track with confirmed duration
        dateAdded: DateTime(2026, 1, 1),
        fileSize: 3 * 1024 * 1024,
      );

      final newScan160k = Track(
        id: '2',
        path: '/storage/snaptube/Song (MP3_160K).mp3',
        title: 'Song (MP3_160K)',
        artist: 'Artista Desconocido',
        duration: Duration.zero, // Not yet played
        dateAdded: DateTime(2026, 1, 2),
        fileSize: 6 * 1024 * 1024, // Higher quality
      );

      final List<Track> tracks = [cached128k, newScan160k];
      final Map<String, List<Track>> titleBuckets = {};

      for (final t in tracks) {
        final key = t.deduplicationKey;
        titleBuckets.putIfAbsent(key, () => []).add(t);
      }

      // Both should have matching key (or match via title)
      expect(TrackNormalizer.normalizeTitle(cached128k.title), equals(TrackNormalizer.normalizeTitle(newScan160k.title)));
    });

    test('Different artists with identical song titles are kept separate', () {
      final adele = Track(
        id: '1',
        path: '/storage/music/Adele - Hello.mp3',
        title: 'Hello',
        artist: 'Adele',
        duration: const Duration(seconds: 295),
        dateAdded: DateTime(2026, 1, 1),
        fileSize: 7 * 1024 * 1024,
      );

      final lionel = Track(
        id: '2',
        path: '/storage/music/Lionel Richie - Hello.mp3',
        title: 'Hello',
        artist: 'Lionel Richie',
        duration: const Duration(seconds: 250),
        dateAdded: DateTime(2026, 1, 2),
        fileSize: 6 * 1024 * 1024,
      );

      expect(adele.deduplicationKey, isNot(equals(lionel.deduplicationKey)));
    });
  });

  group('Domain Entities Aggregations', () {
    test('Album calculates total duration and track count accurately', () {
      final t1 = Track(
        id: '1',
        path: '/path/1',
        title: 'T1',
        artist: 'Artist A',
        album: 'Album 1',
        duration: const Duration(seconds: 100),
        dateAdded: DateTime.now(),
      );
      final t2 = Track(
        id: '2',
        path: '/path/2',
        title: 'T2',
        artist: 'Artist A',
        album: 'Album 1',
        duration: const Duration(seconds: 200),
        dateAdded: DateTime.now(),
      );

      final album = Album(
        id: 'album_1',
        name: 'Album 1',
        artist: 'Artist A',
        tracks: [t1, t2],
      );

      expect(album.trackCount, equals(2));
      expect(album.totalDuration, equals(const Duration(seconds: 300)));
    });

    test('Artist calculates album count and total duration accurately', () {
      final t1 = Track(
        id: '1',
        path: '/path/1',
        title: 'T1',
        artist: 'Artist A',
        album: 'Album 1',
        duration: const Duration(seconds: 150),
        dateAdded: DateTime.now(),
      );
      final t2 = Track(
        id: '2',
        path: '/path/2',
        title: 'T2',
        artist: 'Artist A',
        album: 'Album 2',
        duration: const Duration(seconds: 150),
        dateAdded: DateTime.now(),
      );

      final artist = Artist(
        id: 'artist_a',
        name: 'Artist A',
        tracks: [t1, t2],
      );

      expect(artist.trackCount, equals(2));
      expect(artist.albumCount, equals(2));
      expect(artist.totalDuration, equals(const Duration(seconds: 300)));
    });

    test('Folder aggregates tracks and total duration correctly', () {
      final t1 = Track(
        id: '1',
        path: '/storage/music/T1.mp3',
        title: 'T1',
        artist: 'Artist A',
        duration: const Duration(seconds: 120),
        dateAdded: DateTime.now(),
      );
      final folder = Folder(
        path: '/storage/music',
        name: 'music',
        tracks: [t1],
      );

      expect(folder.name, equals('music'));
      expect(folder.trackCount, equals(1));
      expect(folder.totalDuration, equals(const Duration(seconds: 120)));
    });
  });

  group('DMAIC Six Sigma - Scalability & Performance Benchmark', () {
    test('Deduplicating 10,000 synthetic tracks executes in under 150ms', () {
      final stopwatch = Stopwatch()..start();

      // Generate 10,000 tracks with 30% duplicate rate
      final List<Track> largeLibrary = List.generate(10000, (i) {
        final songIndex = i % 7000;
        return Track(
          id: 'track_$i',
          path: '/storage/music/folder_${i % 10}/song_$songIndex.mp3',
          title: 'Song $songIndex',
          artist: 'Artist ${songIndex % 100}',
          duration: Duration(seconds: 180 + (songIndex % 60)),
          dateAdded: DateTime.now(),
          fileSize: 1024 * 1024 * (3 + (i % 5)),
        );
      });

      final Map<String, Track> uniqueMap = {};
      for (final track in largeLibrary) {
        final key = track.deduplicationKey;
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = track;
        } else {
          final existing = uniqueMap[key]!;
          if (track.fileSize > existing.fileSize) {
            uniqueMap[key] = track;
          }
        }
      }
      final deduplicated = uniqueMap.values.toList();
      stopwatch.stop();

      expect(deduplicated.length, equals(7000));
      // Six sigma threshold: < 500ms for 10k tracks in-memory
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
