import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/screens/add_plant_screen.dart';
import 'package:ethmar/widgets/plant_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String typedName(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  testWidgets('choosing a crop suggests its name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddPlantScreen()));
    await settle(tester);

    await tester.tap(find.text('Tomato'));
    await settle(tester);
    expect(typedName(tester), 'Tomato');
  });

  testWidgets('the unknown plant is offered, and the user names it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddPlantScreen()));
    await settle(tester);

    await tester.ensureVisible(find.text('Other crops'));
    await tester.tap(find.text('Other crops'));
    await settle(tester);
    expect(find.text('Tomato'), findsNothing);

    await tester.tap(find.text('Unknown plant'));
    await settle(tester);
    expect(typedName(tester), isEmpty);
  });

  testWidgets('a missing picture shows the default one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlantPicture('assets/ethmar_crops/missing.png')),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((i) => (i.image as AssetImage).assetName),
      contains(defaultPlantImage),
    );
  });
}
