import 'dart:async';

import 'package:flutter/material.dart';

import '../app_layout.dart';
import '../l10n/app_strings.dart';
import '../services/care_notifications.dart';
import '../services/farm_store.dart';
import '../widgets/main_bottom_bar.dart';
import '../widgets/page_routes.dart';
import 'chat_screen.dart';
import 'daily_tasks_screen.dart';
import 'home_screen.dart';
import 'virtual_farm_screen.dart';

/// The main screens.
enum _Tab { home, dailyTasks, farm, chat }

/// The main screens with the shared bottom bar: Home, Your Farm (the big
/// button in the middle) and Ask Thamoor; or, with [useClassicLayout], the
/// four tabs Home, Daily Tasks, Virtual Farm and Ask Thamoor.
///
/// - Switching tabs shows the chosen screen in place; nothing is pushed, so
///   no duplicate screens pile up.
/// - Each tab is built the first time it is opened and then kept, so it
///   remembers its state (chat messages, task ticks, farm view).
/// - Secondary screens are pushed on the app's navigator above this shell,
///   so they cover the bar; Back returns here with the same tab selected.
/// - System Back on any other tab goes to Home; on Home it leaves the app
///   as before.
/// - The bar hides while the keyboard is open (e.g. typing to Thamoor).
/// - Tapping a care reminder opens Daily Tasks (as a tab, or above Home),
///   closing any screen pushed above this shell.
/// - The streak is checked for missed days when this opens, whenever the
///   app comes back to the front, and at midnight if it stays open.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.username = ''});
  final String username;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// The tabs, in bar order.
  static const _tabs = useClassicLayout
      ? [_Tab.home, _Tab.dailyTasks, _Tab.farm, _Tab.chat]
      : [_Tab.home, _Tab.farm, _Tab.chat];

  /// How far the farm button rises above the bar; the pages keep this much
  /// room at the bottom so it never covers their content.
  static const _buttonRise = FarmCenterButton.rise;

  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    _checkStreak();
    _lifecycle = AppLifecycleListener(onResume: _checkStreak);
    _scheduleMidnightCheck();
    CareNotifications.openDailyTasks.addListener(_onReminderTapped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A reminder tapped before this screen existed (e.g. it started the
      // app, or the user had to sign in first).
      _onReminderTapped();
      CareNotifications.askPermissions();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _midnight?.cancel();
    CareNotifications.openDailyTasks.removeListener(_onReminderTapped);
    super.dispose();
  }

  /// Checks the streak again just after midnight, when yesterday is over.
  void _scheduleMidnightCheck() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      _checkStreak();
      _scheduleMidnightCheck();
    });
  }

  Future<void> _checkStreak() async {
    try {
      await FarmStore.checkStreak();
    } catch (e) {
      // Offline or signed out: it's checked again next time.
      debugPrint('Could not check the streak: $e');
    }
  }

  void _onReminderTapped() {
    if (!mounted || !CareNotifications.openDailyTasks.value) return;
    CareNotifications.openDailyTasks.value = false;
    final shell = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == shell);
    if (useClassicLayout) {
      _select(_Tab.dailyTasks);
    } else {
      Navigator.of(context).push(riseRoute(const DailyTasksScreen()));
    }
  }

  _Tab _tab = _Tab.home;

  // Tabs opened so far; the others aren't built yet.
  final _visited = <_Tab>{_Tab.home};

  void _select(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _page(_Tab tab) => switch (tab) {
        _Tab.home => HomeScreen(username: widget.username),
        _Tab.dailyTasks => const DailyTasksScreen(asTab: true),
        _Tab.farm => const VirtualFarmScreen(),
        _Tab.chat => ChatScreen(username: widget.username),
      };

  /// The tabs as the labeled and pill bars show them. [pills] sizes the
  /// pictures for the pill bar's bigger circles.
  List<NavBarItem> _barItems({required bool pills}) {
    final s = S.of(context);
    return [
      for (final tab in _tabs)
        switch (tab) {
          _Tab.home => NavBarItem(
            image: 'ethmar_homepage_icon',
            label: s.navHome,
            iconSize: pills ? 28 : 26,
          ),
          _Tab.farm => NavBarItem(
            image: 'ethmar_add_plant_icon',
            label: s.navVirtualFarm,
            tinted: false,
            // The picture has empty space around it.
            iconSize: pills ? 46 : 40,
          ),
          _Tab.chat => NavBarItem(
            image: 'ethmar_chatbot_icon',
            label: s.navAskThamoor,
            // Wide, detailed drawing.
            iconSize: pills ? 38 : 34,
          ),
          _Tab.dailyTasks => NavBarItem(
            image: 'ethmar_tasks_icon',
            label: s.navDailyTasks,
          ),
        },
    ];
  }

  /// The bottom bar for [style]; null is the classic design's bar.
  Widget _bar(NavBarStyle? style) {
    final index = _tabs.indexOf(_tab);
    void onSelect(int i) => _select(_tabs[i]);
    return switch (style) {
      null => MainBottomBar(currentIndex: index, onSelect: onSelect),
      NavBarStyle.labeled => LabeledNavBar(
        items: _barItems(pills: false),
        currentIndex: index,
        onSelect: onSelect,
      ),
      NavBarStyle.pills => PillNavBar(
        items: _barItems(pills: true),
        currentIndex: index,
        onSelect: onSelect,
      ),
      NavBarStyle.centerButton => FarmCenterBottomBar(
        homeSelected: _tab == _Tab.home,
        chatSelected: _tab == _Tab.chat,
        onHome: () => _select(_Tab.home),
        onChat: () => _select(_Tab.chat),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Read here, above this shell's Scaffold, so the keyboard height hasn't
    // been removed yet.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final style = useClassicLayout ? null : navBarStyle;
    final pills = style == NavBarStyle.pills;
    final showButton = style == NavBarStyle.centerButton && !keyboardOpen;
    return PopScope(
      canPop: _tab == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_Tab.home);
      },
      child: Scaffold(
        // The pill bar floats: the page runs behind it, and the Scaffold
        // adds the bar's height to the page's bottom padding.
        extendBody: pills,
        body: Builder(
          // Inside the Scaffold, where the bar's height is already taken
          // off: add the part of the farm button that rises above the bar,
          // so pages that respect the bottom safe area stay clear of it.
          builder: (context) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: showButton
                  ? media.copyWith(
                      padding: media.padding.copyWith(
                        bottom: media.padding.bottom + _buttonRise,
                      ),
                    )
                  : media,
              child: IndexedStack(
                index: _tabs.indexOf(_tab),
                children: [
                  for (final tab in _tabs)
                    // Hidden tabs keep their state but pause their animations.
                    TickerMode(
                      enabled: tab == _tab,
                      child: _visited.contains(tab)
                          ? _page(tab)
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: showButton
            ? FarmCenterButton(
                selected: _tab == _Tab.farm,
                onTap: () => _select(_Tab.farm),
              )
            : null,
        floatingActionButtonLocation: FarmCenterButton.location,
        bottomNavigationBar: keyboardOpen ? null : _bar(style),
      ),
    );
  }
}
