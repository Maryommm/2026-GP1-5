import 'package:ethmar/models/crop_recommendation.dart';
import 'package:ethmar/screens/crop_recommendation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

CropRecommendation _crop(int i) => CropRecommendation(
      name: BiText('Crop $i', 'محصول $i'),
      category: CropCategory.vegetable,
      band: MatchBand.good,
      bestMonths: const [10],
      minTemp: 15,
      maxTemp: 30,
      waterNeed: const ['medium'],
    );

const _conditions = GrowingConditions(
  city: BiText('Riyadh', 'الرياض'),
  month: 10,
  tempLow: 21,
  tempHigh: 35,
  rainMm: 0,
);

// The screen's entrance animations run for a few hundred milliseconds.
// pumpAndSettle can't be used: the loading bar never stops by itself.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('scrolling to the end asks for the next page by offset',
      (tester) async {
    final offsets = <int>[];
    final first = CropRecommendationResult(
      conditions: _conditions,
      crops: [for (var i = 0; i < 5; i++) _crop(i)],
      total: 8,
    );

    await tester.pumpWidget(MaterialApp(
      home: CropRecommendationScreen(
        load: (setup) async {
          expect(
            setup,
            const GrowingSetup(
              planting: Planting.pot,
              sunlight: Sunlight.partial,
              water: Watering.medium,
            ),
          );
          return first;
        },
        loadMore: (result, loaded) async {
          expect(result, same(first));
          offsets.add(loaded);
          return [for (var i = loaded; i < result.total; i++) _crop(i)];
        },
      ),
    ));
    await _settle(tester);

    // Nothing loads until the user answers the three questions.
    for (final answer in ['In a pot', 'Partial sun', 'Medium']) {
      expect(find.text('Crop 0'), findsNothing);
      await tester.tap(find.text(answer));
      await _settle(tester);
    }
    expect(find.text('Crop 0'), findsOneWidget);
    expect(find.text('Crop 7'), findsNothing);

    // Scroll the list to its bottom: the next page loads from offset 5.
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await _settle(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await _settle(tester);

    expect(offsets, [5]);
    expect(find.text('Crop 7'), findsOneWidget);

    // Everything is loaded now, so further scrolling asks for nothing.
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await _settle(tester);
    expect(offsets, [5]);
  });
}
