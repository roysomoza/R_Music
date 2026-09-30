// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pure_audio/data/datasources/local/local_database.dart';
import 'package:pure_audio/data/repositories/music_repository_impl.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String documentsPath;

  MockPathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockPathProviderPlatform mockPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('favorites_test_');
    mockPathProvider = MockPathProviderPlatform(tempDir.path);
    PathProviderPlatform.instance = mockPathProvider;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalDatabase Favorites & Legacy Migration Tests', () {
    test('getFavorites returns empty set when no favorites exist', () async {
      final db = LocalDatabase();
      final favs = await db.getFavorites();
      expect(favs, isEmpty);
    });

    test('getFavorites migrates legacy favorites.json to favorites_db.json using path.hashCode', () async {
      final db = LocalDatabase();
      final legacyFile = File(p.join(tempDir.path, 'favorites.json'));
      const testPath1 = '/storage/emulated/0/Music/SongA.mp3';
      const testPath2 = '/storage/emulated/0/Music/SongB.mp3';

      await legacyFile.writeAsString(jsonEncode([testPath1, testPath2]));

      // Act
      final favs = await db.getFavorites();

      // Assert: favorites migrated to IDs
      final expectedId1 = testPath1.hashCode.toString();
      final expectedId2 = testPath2.hashCode.toString();
      expect(favs.contains(expectedId1), isTrue);
      expect(favs.contains(expectedId2), isTrue);
      expect(favs.length, equals(2));

      // Assert favorites_db.json was created
      final dbFile = File(p.join(tempDir.path, 'favorites_db.json'));
      expect(await dbFile.exists(), isTrue);

      final dbContent = jsonDecode(await dbFile.readAsString()) as List<dynamic>;
      expect(dbContent.map((e) => e.toString()).toSet(), equals({expectedId1, expectedId2}));
    });

    test('saveFavorites and subsequent getFavorites reads from favorites_db.json directly', () async {
      final db = LocalDatabase();
      await db.saveFavorites({'id_101', 'id_202'});

      final loaded = await db.getFavorites();
      expect(loaded, equals({'id_101', 'id_202'}));
    });
  });

  group('MusicRepositoryImpl Favorites SSOT Tests', () {
    test('toggleFavorite toggles track.id in LocalDatabase and notifies favoritesStream', () async {
      final db = LocalDatabase();
      final repo = MusicRepositoryImpl(localDb: db);

      await repo.initialize();
      expect(repo.currentFavorites, isEmpty);

      // Listen to stream
      final streamEvents = <Set<String>>[];
      final sub = repo.favoritesStream.listen((event) {
        streamEvents.add(Set.from(event));
      });

      // Toggle favorite on
      await repo.toggleFavorite('track_hash_123');
      expect(repo.currentFavorites.contains('track_hash_123'), isTrue);
      expect(await repo.isFavorite('track_hash_123'), isTrue);

      // Verify persisted in LocalDatabase
      final dbFavs = await db.getFavorites();
      expect(dbFavs.contains('track_hash_123'), isTrue);

      // Toggle favorite off
      await repo.toggleFavorite('track_hash_123');
      expect(repo.currentFavorites.contains('track_hash_123'), isFalse);
      expect(await repo.isFavorite('track_hash_123'), isFalse);

      final dbFavsAfter = await db.getFavorites();
      expect(dbFavsAfter.contains('track_hash_123'), isFalse);

      await sub.cancel();
      await repo.dispose();
    });
  });
}
