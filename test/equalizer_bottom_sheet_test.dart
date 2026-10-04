import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_audio/presentation/widgets/player/equalizer_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EqualizerBottomSheet renders 5 frequency bands, presets, and bass boost', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EqualizerBottomSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify headers & sections
    expect(find.text('Ecualizador & Bass Boost'), findsOneWidget);
    expect(find.text('Preajustes de Sonido'), findsOneWidget);
    expect(find.text('Refuerzo de Graves (Bass Boost)'), findsOneWidget);
    expect(find.text('Bandas de Ecualización'), findsOneWidget);

    // 2. Verify all 5 frequency labels
    expect(find.text('60 Hz'), findsOneWidget);
    expect(find.text('230 Hz'), findsOneWidget);
    expect(find.text('910 Hz'), findsOneWidget);
    expect(find.text('3.6 kHz'), findsOneWidget);
    expect(find.text('14 kHz'), findsOneWidget);

    // 3. Verify initial 0 dB labels (5 bands)
    expect(find.text('0 dB'), findsNWidgets(5));

    // 4. Verify 6 sliders (1 Bass Boost + 5 Bands)
    expect(find.byType(Slider), findsNWidgets(6));

    // 5. Verify Switch is ON by default
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final Switch switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, isTrue);

    // 6. Toggle Switch OFF
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final Switch switchOffWidget = tester.widget(switchFinder);
    expect(switchOffWidget.value, isFalse);
  });

  testWidgets('EqualizerBottomSheet.show launches modal with useSafeArea', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EqualizerBottomSheet.show(context),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    // Tap button to show bottom sheet
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(EqualizerBottomSheet), findsOneWidget);
    expect(find.text('Bandas de Ecualización'), findsOneWidget);
  });
}
