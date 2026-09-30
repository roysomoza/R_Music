import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/models/folder_model.dart';
import 'package:pure_audio/models/track_model.dart';
import 'package:pure_audio/screens/folder_detail_screen.dart';

void main() {
  testWidgets('FolderDetailScreen toggles favorite heart icon optimistically', (tester) async {
    final testTrack = TrackModel(
      id: 'track_123',
      path: '/storage/music/MySong.mp3',
      title: 'My Song',
      artist: 'Artist Test',
      duration: const Duration(seconds: 180),
      dateAdded: DateTime.now(),
    );

    final folder = FolderModel(
      id: 'folder_1',
      name: 'Rock Classics',
      createdAt: DateTime.now(),
      trackPaths: [testTrack.path],
    );

    String? toggledTrackId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderDetailScreen(
            folder: folder,
            allTracks: [testTrack],
            favorites: const {},
            currentPlayingPath: null,
            allFolders: [folder],
            onPlayTrack: (_, _) {},
            onToggleFavorite: (id) {
              toggledTrackId = id;
            },
            onAddTracksToFolder: (_, _) {},
            onRemoveTrackFromFolder: (_, _) {},
            onRenameFolder: (_, _) {},
            onDeleteFolder: (_) {},
            onDeleteTrack: (_, _) {},
            onAddToFolder: (_, _) {},
            onCreateAndAddToFolder: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initially NOT favorite: shows favorite_border_rounded
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);

    // 2. Tap favorite button
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    // 3. Optimistic update: instantly turns into favorite_rounded (red heart)
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(toggledTrackId, equals('track_123'));

    // 4. Tap favorite button again
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();

    // 5. Reverts to favorite_border_rounded
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });
}
