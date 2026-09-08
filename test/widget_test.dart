import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PureAudioApp());
    expect(find.byType(PureAudioApp), findsOneWidget);
  });
}
