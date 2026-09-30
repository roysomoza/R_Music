import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/core/utils/track_normalizer.dart';
import 'package:pure_audio/models/track_model.dart';
import 'package:pure_audio/services/metadata_resolution_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MetadataResolutionService service;

  final sampleRules = {
    'id_to_artist': {
      '1782076663328': 'Don Omar',
      '1783598752259': 'Rubén Blades & Willie Colón',
      '1782076674758': 'Héctor & Tito',
    },
    'title_signatures': {
      'monaco': 'Bad Bunny',
      'algomegustadeti': 'Wisin & Yandel ft. Chris Brown & T-Pain',
      'myspace': 'Don Omar ft. Wisin & Yandel',
      'felina': 'Héctor & Tito',
    },
    'regex_rules': [
      {
        'pattern': r'(?i)reuni[oó]n de los vaqueros',
        'artist': 'Wisin & Yandel',
      },
      {
        'pattern': r'(?i)hard to say i.*m sorry',
        'artist': 'Chicago',
      }
    ],
  };

  setUp(() {
    service = MetadataResolutionService();
    service.setRulesForTesting(sampleRules);
  });

  group('MetadataResolutionService - Level 1: Tag Validation', () {
    test('Valid artist name is preserved without alteration', () async {
      final track = TrackModel(
        id: '1',
        path: '/storage/emulated/0/Music/song.mp3',
        title: 'Song Title',
        artist: 'Michael Jackson',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Michael Jackson'));
    });

    test('Generic artists (Snaptube, Artista Desconocido, 0) are flagged as invalid', () {
      expect(TrackNormalizer.isInvalidOrGenericArtist('Artista Desconocido'), isTrue);
      expect(TrackNormalizer.isInvalidOrGenericArtist('Snaptube'), isTrue);
      expect(TrackNormalizer.isInvalidOrGenericArtist('1782076663328'), isTrue);
      expect(TrackNormalizer.isInvalidOrGenericArtist(''), isTrue);
      expect(TrackNormalizer.isInvalidOrGenericArtist('Coldplay'), isFalse);
    });
  });

  group('MetadataResolutionService - Level 2: Filename Heuristics', () {
    test('Extracts Artist - Title from filename when tags are generic', () async {
      final track = TrackModel(
        id: '2',
        path: '/storage/emulated/0/Download/Queen - Bohemian Rhapsody(MP3_160K).mp3',
        title: 'Queen - Bohemian Rhapsody(MP3_160K)',
        artist: 'Artista Desconocido',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Queen'));
      expect(result.first.title, contains('Bohemian Rhapsody'));
    });

    test('Extracts artist with em-dash or en-dash separators', () async {
      final track = TrackModel(
        id: '3',
        path: '/storage/emulated/0/Download/Soda Stereo – De Música Ligera.mp3',
        title: 'De Música Ligera',
        artist: 'Unknown',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Soda Stereo'));
      expect(result.first.title, equals('De Música Ligera'));
    });
  });

  group('MetadataResolutionService - Level 3: Rules Catalog & Timestamps', () {
    test('Resolves numeric timestamp ID in artist field to real artist', () async {
      final track = TrackModel(
        id: '4',
        path: '/storage/emulated/0/Music/Dale Don Dale(MP3_160K).mp3',
        title: 'Dale Don Dale',
        artist: '1782076663328',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Don Omar'));
    });

    test('Resolves numeric timestamp ID located in path directory', () async {
      final track = TrackModel(
        id: '5',
        path: '/data/user/0/com.example.pure_audio/cache/file_picker/1783598752259/Plástico(MP3_160K).mp3',
        title: 'Plástico',
        artist: 'Artista Desconocido',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Rubén Blades & Willie Colón'));
    });

    test('Resolves title signature for tracks with missing ID3 (e.g. MONACO -> Bad Bunny)', () async {
      final track = TrackModel(
        id: '6',
        path: '/storage/emulated/0/snaptube/download/SnapTube Audio/MONACO(MP3_160K).mp3',
        title: 'MONACO',
        artist: 'Artista Desconocido',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Bad Bunny'));
    });

    test('Resolves regex pattern rules (e.g. Reunión De Los Vaqueros -> Wisin & Yandel)', () async {
      final track = TrackModel(
        id: '7',
        path: '/storage/emulated/0/snaptube/download/SnapTube Audio/La Reunión De Los Vaqueros(MP3_160K).mp3',
        title: 'La Reunión De Los Vaqueros',
        artist: 'Artista Desconocido',
        dateAdded: DateTime.now(),
      );

      final result = await service.resolveBatch([track]);
      expect(result.first.artist, equals('Wisin & Yandel'));
    });
  });

  group('MetadataResolutionService - Batch Performance & Isolate', () {
    test('Resolves multiple tracks in a single batch call efficiently', () async {
      final tracks = [
        TrackModel(
          id: '10',
          path: '/storage/emulated/0/Music/Felina(MP3_160K).mp3',
          title: 'Felina',
          artist: '1782076674758',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '11',
          path: '/storage/emulated/0/Music/My Space(MP3_160K).mp3',
          title: 'My Space',
          artist: 'Artista Desconocido',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '12',
          path: '/storage/emulated/0/Music/Algo Me Gusta De Ti.mp3',
          title: 'Algo Me Gusta De Ti',
          artist: 'Unknown',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '13',
          path: '/storage/emulated/0/Music/Proper Track.mp3',
          title: 'Proper Track',
          artist: 'Eminem',
          dateAdded: DateTime.now(),
        ),
      ];

      final stopwatch = Stopwatch()..start();
      final resolved = await service.resolveBatch(tracks);
      stopwatch.stop();

      expect(resolved.length, equals(4));
      expect(resolved[0].artist, equals('Héctor & Tito'));
      expect(resolved[1].artist, equals('Don Omar ft. Wisin & Yandel'));
      expect(resolved[2].artist, equals('Wisin & Yandel ft. Chris Brown & T-Pain'));
      expect(resolved[3].artist, equals('Eminem'));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('Leaves already-clean list untouched with zero overhead', () async {
      final cleanTracks = [
        TrackModel(
          id: '20',
          path: '/storage/emulated/0/Music/Track1.mp3',
          title: 'Track 1',
          artist: 'Artist A',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '21',
          path: '/storage/emulated/0/Music/Track2.mp3',
          title: 'Track 2',
          artist: 'Artist B',
          dateAdded: DateTime.now(),
        ),
      ];

      final stopwatch = Stopwatch()..start();
      final result = await service.resolveBatch(cleanTracks);
      stopwatch.stop();

      expect(result.first.artist, equals('Artist A'));
      expect(result.last.artist, equals('Artist B'));
      // Immediate return on main thread without isolate overhead
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });

  group('MetadataResolutionService - Hardening & Concurrency Tests', () {
    test('Dynamic Map<dynamic, dynamic> rules do not trigger TypeError in resolveBatch', () async {
      final dynamicService = MetadataResolutionService();
      // Raw Map<dynamic, dynamic> with nested Map<dynamic, dynamic>
      final dynamicRules = <dynamic, dynamic>{
        'id_to_artist': <dynamic, dynamic>{
          '1782076663328': 'Don Omar',
        },
        'title_signatures': <dynamic, dynamic>{
          'monaco': 'Bad Bunny',
        },
        'regex_rules': <dynamic>[
          <dynamic, dynamic>{
            'pattern': r'(?i)reuni[oó]n de los vaqueros',
            'artist': 'Wisin & Yandel',
          },
        ],
      };

      dynamicService.setRulesForTesting(dynamicRules);

      final tracks = [
        TrackModel(
          id: '101',
          path: '/storage/emulated/0/Music/song1.mp3',
          title: 'Dale Don Dale',
          artist: '1782076663328',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '102',
          path: '/storage/emulated/0/Music/song2.mp3',
          title: 'MONACO',
          artist: 'Artista Desconocido',
          dateAdded: DateTime.now(),
        ),
        TrackModel(
          id: '103',
          path: '/storage/emulated/0/Music/song3.mp3',
          title: 'La Reunión De Los Vaqueros',
          artist: '0',
          dateAdded: DateTime.now(),
        ),
      ];

      // Verifies Isolate execution does not crash with TypeError
      final resolved = await dynamicService.resolveBatch(tracks);
      expect(resolved.length, equals(3));
      expect(resolved[0].artist, equals('Don Omar'));
      expect(resolved[1].artist, equals('Bad Bunny'));
      expect(resolved[2].artist, equals('Wisin & Yandel'));
    });

    test('Concurrent calls to resolveOnlineThrottled do not crash and respect throttling queue', () async {
      final stopwatch = Stopwatch()..start();

      // Launch 3 concurrent requests simultaneously
      final f1 = service.resolveOnlineThrottled('NonExistentTrackAlpha_9999');
      final f2 = service.resolveOnlineThrottled('NonExistentTrackBeta_9999');
      final f3 = service.resolveOnlineThrottled('NonExistentTrackGamma_9999');

      final results = await Future.wait([f1, f2, f3]);
      stopwatch.stop();

      // Verifies no uncaught exceptions/crashes
      expect(results.length, equals(3));

      // Verifies rate limiting: serialized queue forces >= 1000ms delay between consecutive requests
      // 3 queued requests must take at least 1900ms total
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(1900));
    });
  });
}
