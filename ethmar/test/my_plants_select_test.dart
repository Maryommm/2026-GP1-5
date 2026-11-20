import 'package:ethmar/data/sample_plants.dart';
import 'package:ethmar/screens/my_plants_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// The ids deleted so far. A delete takes the plant off the farm, as
  /// Firestore does.
  late List<String> deleted;

  setUp(() {
    deleted = [];
    FarmStore.deleteForTests = (id) async {
      deleted.add(id);
      FarmStore.plants.value = [
        for (final p in FarmStore.plants.value)
          if (p.id != id) p,
      ];
    };
  });

  tearDown(() {
    FarmStore.plants.value = const [];
    FarmStore.deleteForTests = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openScreen(WidgetTester tester) async {
    // Tall enough that every plant card is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FarmStore.plants.value = samplePlants;
    await tester.pumpWidget(const MaterialApp(home: MyPlantsScreen()));
    await settle(tester);
  }

  Finder box(String id) => find.byKey(Key('selectPlant_$id'));
  final first = samplePlants[0];
  final second = samplePlants[1];

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('the select button shows a box next to every plant', (
    tester,
  ) async {
    await openScreen(tester);
    expect(find.byType(Checkbox), findsNothing);

    await tap(tester, find.byKey(const Key('selectPlants')));
    expect(find.byType(Checkbox), findsNWidgets(samplePlants.length));
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('ticked plants are deleted after confirming', (tester) async {
    await openScreen(tester);
    await tap(tester, find.byKey(const Key('selectPlants')));

    // Tapping the card or the box both tick it.
    await tap(tester, find.text(first.name));
    await tap(tester, box(second.id!));
    expect(find.text('2 selected'), findsOneWidget);

    await tap(tester, find.byKey(const Key('deleteSelected')));
    expect(find.text('Delete 2 plants?'), findsOneWidget);
    await tap(tester, find.byKey(const Key('confirmDeletePlants')));

    expect(deleted, unorderedEquals([first.id, second.id]));
    expect(find.text(first.name), findsNothing);
    expect(find.text(second.name), findsNothing);
    expect(find.text(samplePlants[2].name), findsOneWidget);
    // Back to the normal list.
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('cancelling the dialog deletes nothing', (tester) async {
    await openScreen(tester);
    await tap(tester, find.byKey(const Key('selectPlants')));
    await tap(tester, box(first.id!));
    await tap(tester, find.byKey(const Key('deleteSelected')));
    // The dialog's Cancel, not the header's.
    await tap(
      tester,
      find.descendant(of: find.byType(Dialog), matching: find.text('Cancel')),
    );

    expect(deleted, isEmpty);
    expect(find.text(first.name), findsOneWidget);
    // Still selecting, with the same plant ticked.
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('select all ticks every plant; nothing ticked hides delete', (
    tester,
  ) async {
    await openScreen(tester);
    await tap(tester, find.byKey(const Key('selectPlants')));

    // Nothing ticked: no Delete button.
    expect(find.byKey(const Key('deleteSelected')), findsNothing);
    await tap(tester, box(first.id!));
    expect(find.byKey(const Key('deleteSelected')), findsOneWidget);
    await tap(tester, box(first.id!));
    expect(find.byKey(const Key('deleteSelected')), findsNothing);

    await tap(tester, find.text('Select all'));
    expect(find.text('${samplePlants.length} selected'), findsOneWidget);
    await tap(tester, find.text('Deselect all'));
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('cancel leaves select mode; tapping a plant no longer ticks it', (
    tester,
  ) async {
    await openScreen(tester);
    await tap(tester, find.byKey(const Key('selectPlants')));
    await tap(tester, box(first.id!));
    await tap(tester, find.byKey(const Key('cancelSelecting')));

    expect(find.byType(Checkbox), findsNothing);
    expect(deleted, isEmpty);
    // Selecting again starts with nothing ticked.
    await tap(tester, find.byKey(const Key('selectPlants')));
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('a failed delete says so', (tester) async {
    FarmStore.deleteForTests = (_) async => throw Exception('offline');
    await openScreen(tester);
    await tap(tester, find.byKey(const Key('selectPlants')));
    await tap(tester, box(first.id!));
    await tap(tester, find.byKey(const Key('deleteSelected')));
    await tap(tester, find.byKey(const Key('confirmDeletePlants')));

    expect(
      find.text(
        "Couldn't delete some plants. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    // Let the message go away before the test ends.
    await tester.pump(const Duration(seconds: 10));
  });
}
