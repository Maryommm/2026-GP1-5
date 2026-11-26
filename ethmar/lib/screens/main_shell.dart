import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/care_notifications.dart';
import '../services/farm_store.dart';
import '../widgets/main_bottom_bar.dart';
import '../widgets/page_routes.dart';
import 'chat_screen.dart';
import 'daily_tasks_screen.dart';
import 'home_screen.dart';
import 'virtual_farm_screen.dart';

/// The main tabs, in the order they appear on the bar.
enum _Tab { home, farm, chat }

/// Whether an on-screen keyboard is open, using [bottomInset] (the
/// keyboard's `MediaQuery.viewInsets.bottom`), so the bar can hide.
///
/// Only a real keyboard counts. With a physical keyboard attached (e.g. the
/// computer's keyboard on the emulator), Gboard shows only a thin toolbar
/// about 24 high. Hiding the bar for that would make it disappear with no
/// keyboard to type on. Phone keyboards are well over 150 high.
bool isKeyboardOpen(double bottomInset) => bottomInset >= keyboardMinHeight;

/// The smallest bottom inset that counts as an open keyboard (see
/// [isKeyboardOpen]).
const keyboardMinHeight = 100.0;

/// The main screens with the shared bottom bar: Home, Your Farm and Ask
/// Thamoor.
///
/// - Switching tabs shows the chosen screen in place. Nothing is pushed, so
///   screens don't pile up.
/// - Each tab is built the first time it's opened and then kept, so it
///   remembers its state (chat messages, farm view).
/// - Other screens are pushed on top of this shell, so they cover the bar.
///   Back returns here with the same tab selected.
/// - System Back on any other tab goes to Home. On Home it leaves the app.
/// - The bar hides while the on-screen keyboard is open (e.g. typing to
///   Thamoor), see [isKeyboardOpen].
/// - Tapping a care reminder opens Daily Tasks and closes any screen on top
///   of this shell.
/// - The streak is checked for missed days when this opens, when the app
///   comes back to the front, and at midnight if it stays open.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.username = ''});
  final String username;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
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
      // A reminder that was tapped before this screen existed (e.g. it started
      // the app, or the user had to sign in first).
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

  /// Checks the streak again right after midnight, when yesterday is over.
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
    Navigator.of(context).push(riseRoute(const DailyTasksScreen()));
  }

  _Tab _tab = _Tab.home;

  // Tabs opened so far. The others aren't built yet.
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
        _Tab.farm => const VirtualFarmScreen(),
        _Tab.chat => ChatScreen(username: widget.username),
      };

  /// The tabs as the bottom bar shows them.
  List<NavBarItem> _barItems() {
    final s = S.of(context);
    return [
      for (final tab in _Tab.values)
        switch (tab) {
          // Outline icons, and filled ones for the open tab. Thamoor's chat bubbles
          // are a little shorter, so they get a slightly bigger box.
          _Tab.home => NavBarItem(
            image: 'home_outline_icon',
            selectedImage: 'home_filled_icon',
            label: s.navHome,
            iconSize: 28,
          ),
          _Tab.farm => NavBarItem(
            image: 'your_farm_outline_icon',
            selectedImage: 'your_farm_filled_icon',
            label: s.navVirtualFarm,
            iconSize: 29,
          ),
          _Tab.chat => NavBarItem(
            image: 'ask_thamoor_outline_icon',
            selectedImage: 'ask_thamoor_filled_icon',
            label: s.navAskThamoor,
            iconSize: 31,
          ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Read here, above this shell's Scaffold, before the keyboard height is
    // removed.
    final keyboardOpen = isKeyboardOpen(MediaQuery.viewInsetsOf(context).bottom);
    return PopScope(
      canPop: _tab == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_Tab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in _Tab.values)
              // Hidden tabs keep their state but pause their animations.
              TickerMode(
                enabled: tab == _tab,
                child: _visited.contains(tab)
                    ? _page(tab)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : LabeledNavBar(
                items: _barItems(),
                currentIndex: _tab.index,
                onSelect: (i) => _select(_Tab.values[i]),
              ),
      ),
    );
  }
}
