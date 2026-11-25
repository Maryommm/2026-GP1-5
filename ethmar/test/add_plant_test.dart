import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/crop_recommendation.dart' show CropCategory;
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/screens/add_plant_screen.dart';
import 'package:ethmar/screens/plant_details_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/services/network_errors.dart';
import 'package:ethmar/widgets/plant_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _AddPlantLauncher extends StatelessWidget {
  const _AddPlantLauncher({required this.savePlant});

  final SavePlant savePlant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open-add-plant'),
            onPressed: () => AddPlantScreen.open(context, savePlant: savePlant),
            child: const Text('Open add plant'),
          ),
        ),
      ),
    );
  }
}

class _PagePushObserver extends NavigatorObserver {
  int pagePushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute<dynamic>) pagePushes++;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String typedName(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  void resetFarmStore() {
    FarmStore.plants.value = const [];
    FarmStore.plantsLoaded.value = false;
    FarmStore.lands.value = 1;
    // Plant Details reads the growth timeline; tests have no Firebase.
    FarmStore.growthForTests = (_) => Stream.value(const []);
  }

  Future<_PagePushObserver> openAddPlant(
    WidgetTester tester,
    SavePlant savePlant,
  ) async {
    final observer = _PagePushObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: _AddPlantLauncher(savePlant: savePlant),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-add-plant')));
    await settle(tester);
    return observer;
  }

  Future<void> openSummary(WidgetTester tester) async {
    await tester.tap(find.text('Tomato'));
    await settle(tester);
    await tester.tap(find.text('Add plant'));
    await settle(tester);
    expect(find.text('Confirm'), findsOneWidget);
  }

  setUp(resetFarmStore);
  tearDown(resetFarmStore);

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

    await tester.ensureVisible(find.text('Other plants'));
    await tester.tap(find.text('Other plants'));
    await settle(tester);
    expect(find.text('Tomato'), findsNothing);

    await tester.tap(find.text('Unknown plant'));
    await settle(tester);
    expect(typedName(tester), isEmpty);
  });

  /// Opens step 2 for an unknown plant named "Moringa".
  Future<void> openUnknown(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Moringa');
    await settle(tester);
    await tester.tap(find.text('Add it as an unknown plant'));
    await settle(tester);
  }

  testWidgets('an unknown plant needs a category before saving', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AddPlantScreen(
          savePlant: (p) async {
            saves++;
            return p;
          },
        ),
      ),
    );
    await settle(tester);
    await openUnknown(tester);
    expect(find.byKey(const Key('unknownCategoryPicker')), findsOneWidget);

    await tester.ensureVisible(find.text('Add plant'));
    await tester.tap(find.text('Add plant'));
    await settle(tester);
    expect(find.text('Choose a category for your plant'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(saves, 0);
  });

  testWidgets('the chosen category is saved with the unknown plant', (
    tester,
  ) async {
    FarmPlant? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: AddPlantScreen(
          savePlant: (p) async => saved = p,
        ),
      ),
    );
    await settle(tester);
    await openUnknown(tester);

    final herb = find.byKey(const Key('unknownCategory_herb'));
    await tester.ensureVisible(herb);
    await tester.tap(herb);
    await settle(tester);
    await tester.ensureVisible(find.text('Add plant'));
    await tester.tap(find.text('Add plant'));
    await settle(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);

    expect(saved!.crop.id, unknownCropId);
    expect(saved!.category, CropCategory.herb);
    expect(saved!.toMap()['category'], 'herb');
  });

  testWidgets('catalog crops keep their own category, without a picker', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddPlantScreen()));
    await settle(tester);
    await tester.tap(find.text('Tomato'));
    await settle(tester);
    expect(find.byKey(const Key('unknownCategoryPicker')), findsNothing);
  });

  testWidgets('searching narrows the crops to matching names', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddPlantScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'toma');
    await settle(tester);
    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('Tomatillo'), findsOneWidget);
    expect(find.text('Cucumber'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await settle(tester);
    expect(find.text('Cucumber'), findsOneWidget);
  });

  testWidgets('a search with no match offers the unknown plant, named', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddPlantScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'Moringa tree');
    await settle(tester);
    expect(find.text('No crop called "Moringa tree" yet'), findsOneWidget);

    await tester.tap(find.text('Add it as an unknown plant'));
    await settle(tester);
    expect(find.text('Unknown plant'), findsOneWidget);
    expect(typedName(tester), 'Moringa tree');
  });

  testWidgets('a missing picture shows the default one', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlantPicture('assets/ethmar_crops/missing.png')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((i) => (i.image as AssetImage).assetName),
      contains(defaultPlantImage),
    );
  });

  testWidgets('a successful save opens exactly one details page', (
    tester,
  ) async {
    late FarmPlant saved;
    final observer = await openAddPlant(tester, (plant) async {
      saved = plant.placed(id: 'firestore-document-42', land: 0, square: 0);
      FarmStore.plants.value = [saved];
      FarmStore.plantsLoaded.value = true;
      return saved;
    });
    final pushesBeforeSaving = observer.pagePushes;
    await openSummary(tester);

    await tester.tap(find.text('Confirm'));
    await settle(tester);

    final details = tester.widget<PlantDetailsScreen>(
      find.byType(PlantDetailsScreen),
    );
    expect(details.plantId, 'firestore-document-42');
    expect(observer.pagePushes, pushesBeforeSaving + 1);

    await tester.pageBack();
    await settle(tester);
    expect(find.byKey(const ValueKey('open-add-plant')), findsOneWidget);
    expect(find.byType(AddPlantScreen), findsNothing);
  });

  testWidgets('canceling Add Plant does not save or open details', (
    tester,
  ) async {
    var saves = 0;
    final observer = await openAddPlant(tester, (plant) async {
      saves++;
      return plant.placed(id: 'should-not-exist', land: 0, square: 0);
    });
    final pushesAfterOpening = observer.pagePushes;

    await tester.pageBack();
    await settle(tester);

    expect(saves, 0);
    expect(observer.pagePushes, pushesAfterOpening);
    expect(find.byKey(const ValueKey('open-add-plant')), findsOneWidget);
    expect(find.byType(PlantDetailsScreen), findsNothing);
  });

  testWidgets('a failed save stays on Add Plant and does not open details', (
    tester,
  ) async {
    final observer = await openAddPlant(
      tester,
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      ),
    );
    final pushesBeforeSaving = observer.pagePushes;
    await openSummary(tester);

    await tester.tap(find.text('Confirm'));
    await settle(tester);

    expect(observer.pagePushes, pushesBeforeSaving);
    expect(find.byType(AddPlantScreen), findsOneWidget);
    expect(find.byType(PlantDetailsScreen), findsNothing);
    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('a save that times out says to check the connection, and the '
      'button can be pressed again', (tester) async {
    var tries = 0;
    await openAddPlant(tester, (_) async {
      tries++;
      throw serverTimedOut();
    });
    await openSummary(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);

    expect(find.byType(AddPlantScreen), findsOneWidget);
    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    // Not stuck loading: the button shows its label again.
    expect(find.text('Add plant'), findsOneWidget);
    expect(tries, 1);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('another failure doesn\'t blame the connection', (tester) async {
    await openAddPlant(tester, (_) async => throw StateError('refused'));
    await openSummary(tester);
    await tester.tap(find.text('Confirm'));
    await settle(tester);

    expect(find.text("Couldn't add the plant. Please try again."),
        findsOneWidget);
    expect(find.text("Couldn't save. Check your connection and try again."),
        findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a save result without an id does not open details', (
    tester,
  ) async {
    final observer = await openAddPlant(tester, (plant) async => plant);
    final pushesBeforeSaving = observer.pagePushes;
    await openSummary(tester);

    await tester.tap(find.text('Confirm'));
    await settle(tester);

    expect(observer.pagePushes, pushesBeforeSaving);
    expect(find.byType(PlantDetailsScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-add-plant')), findsOneWidget);
  });
}
