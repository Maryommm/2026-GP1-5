import 'package:ethmar/models/crop_catalog.dart';
import 'package:ethmar/models/farm_plant.dart';
import 'package:ethmar/models/task_log.dart';
import 'package:ethmar/screens/daily_tasks_screen.dart';
import 'package:ethmar/services/farm_store.dart';
import 'package:ethmar/widgets/main_bottom_bar.dart';
import 'package:ethmar/widgets/today_tasks_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// A plant watered every day at [hour]:[minute].
FarmPlant _plant(String id, String name, int hour, int minute) => FarmPlant(
  id: id,
  crop: cropCatalog.first,
  name: name,
  irrigation: CareSchedule(Repeat.everyDay, TimeOfDay(hour: hour, minute: minute)),
  plantedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showCard(WidgetTester tester, {List<String> done = const []}) async {
    FarmStore.taskLogForTests = (date) =>
        Stream.value(TaskLog(date: date, completed: done));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: TodayTasksCard())),
      ),
    );
    await tester.pump();
  }

  tearDown(() {
    FarmStore.plants.value = const [];
    FarmStore.taskLogForTests = null;
  });

  group("Today's Tasks card", () {
    setUp(() {
      FarmStore.plants.value = [
        _plant('b', 'Basil', 23, 59),
        _plant('a', 'Mint', 0, 0),
      ];
    });

    testWidgets('shows only the progress, not the tasks themselves', (
      tester,
    ) async {
      await showCard(tester);

      expect(find.text("Today's Tasks"), findsOneWidget);
      // The numbers are wrapped in direction marks (see homeTasksDoneOf).
      expect(find.textContaining(RegExp(r'0/2\W* completed')), findsOneWidget);
      expect(find.textContaining('Mint'), findsNothing);
      expect(find.textContaining('Basil'), findsNothing);
    });

    testWidgets('counts the ticked tasks', (tester) async {
      await showCard(tester, done: [TaskLog.irrigationTaskId('a')]);
      expect(find.textContaining(RegExp(r'1/2\W* completed')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('a green tick once every task is done', (tester) async {
      await showCard(
        tester,
        done: [TaskLog.irrigationTaskId('a'), TaskLog.irrigationTaskId('b')],
      );
      expect(find.textContaining(RegExp(r'2/2\W* completed')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('the whole card opens Daily Tasks', (tester) async {
      await showCard(tester);

      await tester.tap(find.byType(TodayTasksCard));
      // Daily Tasks keeps animating, so wait for the page transition only.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DailyTasksScreen), findsOneWidget);
    });
  });

  testWidgets("Today's Tasks card without scheduled plants", (tester) async {
    await showCard(tester);

    expect(find.text("Today's Tasks"), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(find.text('No tasks today'), findsOneWidget);
  });

  testWidgets('the labeled bar names every tab, and reports taps', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LabeledNavBar(
            items: const [
              NavBarItem(image: 'ethmar_homepage_icon', label: 'Home'),
              NavBarItem(
                image: 'ethmar_add_plant_icon',
                label: 'Your Farm',
                tinted: false,
              ),
              NavBarItem(image: 'ethmar_chatbot_icon', label: 'Ask Thamoor'),
            ],
            currentIndex: 0,
            onSelect: taps.add,
          ),
        ),
      ),
    );

    for (final label in ['Home', 'Your Farm', 'Ask Thamoor']) {
      expect(find.text(label), findsOneWidget);
    }
    // A bottom bar may be as tall as the screen; it must stay a bar.
    expect(tester.getSize(find.byType(LabeledNavBar)).height, lessThan(110));
    await tester.tap(find.text('Ask Thamoor'));
    await tester.tap(find.text('Your Farm'));
    expect(taps, [2, 1]);
  });

  testWidgets('the labeled bar: filled icon for the open tab, no highlight', (
    tester,
  ) async {
    var open = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: LabeledNavBar(
              items: const [
                NavBarItem(
                  image: 'home_outline_icon',
                  selectedImage: 'home_filled_icon',
                  label: 'Home',
                ),
                NavBarItem(
                  image: 'your_farm_outline_icon',
                  selectedImage: 'your_farm_filled_icon',
                  label: 'Your Farm',
                ),
                NavBarItem(
                  image: 'ask_thamoor_outline_icon',
                  selectedImage: 'ask_thamoor_filled_icon',
                  label: 'Ask Thamoor',
                ),
              ],
              currentIndex: open,
              onSelect: (i) => setState(() => open = i),
            ),
          ),
        ),
      ),
    );

    // The pictures on screen (offstage ones are skipped by finders).
    Set<String> shown() => {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as AssetImage).assetName
            .replaceAll('assets/images/', '')
            .replaceAll('_icon.png', ''),
    };

    expect(shown(), {'home_filled', 'your_farm_outline', 'ask_thamoor_outline'});
    await tester.tap(find.text('Ask Thamoor'));
    await tester.pump();
    expect(shown(), {'home_outline', 'your_farm_outline', 'ask_thamoor_filled'});

    // Nothing coloured behind any tab.
    final bar = find.byType(LabeledNavBar);
    for (final box in tester.widgetList<Container>(
      find.descendant(of: bar, matching: find.byType(Container)),
    )) {
      expect(box.decoration, isNull);
      expect(box.color, isNull);
    }
    expect(
      find.descendant(of: bar, matching: find.byType(AnimatedContainer)),
      findsNothing,
    );
  });

  testWidgets('the labeled bar mirrors its tab order in Arabic', (
    tester,
  ) async {
    Future<Map<String, double>> tabXs(TextDirection direction) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              bottomNavigationBar: LabeledNavBar(
                items: const [
                  NavBarItem(image: 'ethmar_homepage_icon', label: 'Home'),
                  NavBarItem(
                    image: 'ethmar_add_plant_icon',
                    label: 'Your Farm',
                    tinted: false,
                  ),
                  NavBarItem(
                    image: 'ethmar_chatbot_icon',
                    label: 'Ask Thamoor',
                  ),
                ],
                currentIndex: 0,
                onSelect: taps.add,
              ),
            ),
          ),
        ),
      );
      // Each tab still reports its own index, whichever side it is on.
      await tester.tap(find.text('Ask Thamoor'));
      expect(taps, [2]);
      return {
        for (final label in ['Home', 'Your Farm', 'Ask Thamoor'])
          label: tester.getCenter(find.text(label)).dx,
      };
    }

    final ltr = await tabXs(TextDirection.ltr);
    expect(ltr['Home']!, lessThan(ltr['Your Farm']!));
    expect(ltr['Your Farm']!, lessThan(ltr['Ask Thamoor']!));

    final rtl = await tabXs(TextDirection.rtl);
    expect(rtl['Home']!, greaterThan(rtl['Your Farm']!));
    expect(rtl['Your Farm']!, greaterThan(rtl['Ask Thamoor']!));
  });

  testWidgets('the pill bar names only the open tab, and reports taps', (
    tester,
  ) async {
    var open = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            extendBody: true,
            bottomNavigationBar: PillNavBar(
              items: const [
                NavBarItem(image: 'ethmar_homepage_icon', label: 'Home'),
                NavBarItem(
                  image: 'ethmar_add_plant_icon',
                  label: 'Your Farm',
                  tinted: false,
                ),
                NavBarItem(image: 'ethmar_chatbot_icon', label: 'Ask Thamoor'),
              ],
              currentIndex: open,
              onSelect: (i) => setState(() => open = i),
            ),
          ),
        ),
      ),
    );

    double widthOf(String label) => tester
        .getSize(
          find.descendant(
            of: find.byTooltip(label),
            matching: find.byType(AnimatedContainer),
          ).first,
        )
        .width;

    expect(widthOf('Home'), greaterThan(widthOf('Your Farm')));

    await tester.tap(find.byTooltip('Your Farm'));
    await tester.pumpAndSettle();
    expect(open, 1);
    expect(widthOf('Your Farm'), greaterThan(widthOf('Home')));
    expect(widthOf('Home'), 56);
  });

  testWidgets('the bar and the farm button report their taps', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: FarmCenterButton(
            selected: false,
            onTap: () => taps.add('farm'),
          ),
          floatingActionButtonLocation: FarmCenterButton.location,
          bottomNavigationBar: FarmCenterBottomBar(
            homeSelected: true,
            chatSelected: false,
            onHome: () => taps.add('home'),
            onChat: () => taps.add('chat'),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('My Farm'));
    await tester.tap(find.byTooltip('Ask Thamoor'));
    await tester.tap(find.byTooltip('Home'));
    expect(taps, ['farm', 'chat', 'home']);

    // The farm button rises above the bar, and is centred on it.
    final button = tester.getRect(find.byType(FarmCenterButton));
    final bar = tester.getRect(find.byType(FarmCenterBottomBar));
    expect(button.top, closeTo(bar.top - FarmCenterButton.rise, 1));
    expect(button.center.dx, closeTo(bar.center.dx, 1));
  });
}
