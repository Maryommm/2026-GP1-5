import 'package:flutter/material.dart';

import '../widgets/main_bottom_bar.dart';
import 'chat_screen.dart';
import 'daily_tasks_screen.dart';
import 'home_screen.dart';
import 'virtual_farm_screen.dart';

/// The four main screens (Home, Daily Tasks, Virtual Farm, Ask Thamoor)
/// with the shared bottom bar.
///
/// - Switching tabs shows the chosen screen in place; nothing is pushed, so
///   no duplicate screens pile up.
/// - Each tab is built the first time it is opened and then kept, so it
///   remembers its state (chat messages, task ticks, farm view).
/// - Secondary screens are pushed on the app's navigator above this shell,
///   so they cover the bar; Back returns here with the same tab selected.
/// - System Back on Daily Tasks, Virtual Farm or Ask Thamoor goes to Home;
///   on Home it leaves the app as before.
/// - The bar hides while the keyboard is open (e.g. typing to Thamoor).
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.username = ''});
  final String username;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _home = 0;

  int _tab = _home;

  // Tabs opened so far; the others aren't built yet.
  final _visited = <int>{_home};

  void _select(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _page(int tab) => switch (tab) {
        0 => HomeScreen(username: widget.username),
        1 => const DailyTasksScreen(),
        2 => const VirtualFarmScreen(),
        _ => ChatScreen(username: widget.username),
      };

  @override
  Widget build(BuildContext context) {
    // Read here, above this shell's Scaffold, so the keyboard height hasn't
    // been removed yet.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _tab == _home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < 4; i++)
              // Hidden tabs keep their state but pause their animations.
              TickerMode(
                enabled: i == _tab,
                child: _visited.contains(i)
                    ? _page(i)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : MainBottomBar(currentIndex: _tab, onSelect: _select),
      ),
    );
  }
}
