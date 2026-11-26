import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit, RenderProxyBox;

import '../l10n/app_strings.dart';
import '../models/farm_stats.dart';
import '../models/streak.dart' show streakBrokenByMissedTasks;
import '../services/daily_slogan_service.dart';
import '../services/farm_store.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_logo.dart';
import '../widgets/page_routes.dart';
import '../widgets/today_tasks_card.dart';
import '../widgets/user_avatar.dart';
import 'agri_map_screen.dart';
import 'crop_recommendation_screen.dart';
import 'leaderboard_screen.dart';
import 'leaf_scan_screen.dart';
import 'profile_screen.dart';

/// The Home screen: logo and avatar on top, then the greeting, the weather
/// card, a card with Today's Tasks (opens Daily Tasks) and the streak, and
/// the Ethmar Services section (a Crop Recommendations card and three tiles:
/// Agricultural Places, Check Your Plant, Leaderboard). Plants are added
/// from Your Farm.
///
/// It is the first tab of MainShell, which draws the bottom bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.username = ''});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background picture: fills the screen without stretching and stays in
          // place while the content scrolls over it.
          Positioned.fill(
            child: Image.asset(
              'assets/images/ethmar_home_background.jpeg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            bottom: false,
            child: ScrollConfiguration(
              // Normal scrolling, but no stretch effect when pulling past the edges.
              behavior:
                  ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: LayoutBuilder(
                builder: (context, viewport) {
                  // One side margin for everything, so all sections line up.
                  final padding = EdgeInsetsDirectional.fromSTEB(
                    24,
                    8,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  );
                  return SingleChildScrollView(
                    padding: padding,
                    // At least as tall as the screen. If the content is shorter, the extra
                    // space is split: half above the greeting and half at the bottom. If it's
                    // taller (small screen or large text), the page just scrolls.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (viewport.maxHeight - padding.vertical)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Both use the shared username, so they update as soon as it changes
                          // (e.g. after Edit Profile).
                          ValueListenableBuilder<String>(
                            valueListenable: currentUsername,
                            builder: (context, savedName, _) => _TopBar(
                                username:
                                    savedName.isEmpty ? username : savedName),
                          ),
                          _content(),
                          // The bottom half of the extra space.
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Everything below the top bar.
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Entrance(
          child: ValueListenableBuilder<String>(
            valueListenable: currentUsername,
            builder: (context, savedName, _) => _Greeting(
                username:
                    savedName.isEmpty ? username : savedName),
          ),
        ),
        const SizedBox(height: 16),
        const Entrance(
          delay: Duration(milliseconds: 100),
          child: _WeatherCard(),
        ),
        const SizedBox(height: 12),
        // Tells the user once when a missed day ends the streak.
        const _StreakLostAlert(),
        Entrance(
          delay: const Duration(milliseconds: 150),
          // Its height is shared with the Crop Recommendations card.
          child: _ReportHeight(
            onHeight: (height) => _tasksCardHeight.value = height,
            child: const _TasksAndStreak(),
          ),
        ),
        const SizedBox(height: 20),
        const Entrance(
          delay: Duration(milliseconds: 200),
          child: _ExploreSection(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar: logo on the start side, avatar on the end side
// (Row swaps them automatically in Arabic).
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const EthmarLogo(width: 110),
        _ProfileAvatarButton(username: username),
      ],
    );
  }
}

/// The user's avatar. Tapping it opens the Profile screen.
class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.of(context).profile,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context)
            .push(riseRoute(ProfileScreen(username: username))),
        // A green ring like on Profile around the 44px avatar. The ring also makes
        // the tap area bigger than 48px.
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            color: AppColors.forest,
            shape: BoxShape.circle,
          ),
          child: const UserAvatar(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting: "Good evening," + the username, and a hand-written slogan.
// ---------------------------------------------------------------------------

class _Greeting extends StatelessWidget {
  const _Greeting({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? s.homeGoodMorning
        : hour < 17
            ? s.homeGoodAfternoon
            : s.homeGoodEvening;
    // The three lines are close together as one block. The name has the same
    // line height in both languages (with room for Arabic marks), so the page
    // doesn't move when switching language.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: AppText.label(context).copyWith(height: 1.2),
        ),
        Text(
          username.isEmpty ? s.homeFriend : username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.title(context).copyWith(height: 1.3),
          strutStyle: const StrutStyle(
            fontSize: 30,
            height: 1.3,
            forceStrutHeight: true,
          ),
        ),
        const SizedBox(height: 2),
        const _DailySlogan(),
      ],
    );
  }
}

/// Today's slogan (one of three, picked once per day by
/// [dailySloganService]).
///
/// Its space is as tall as the longest of the three slogans in the current
/// language, so the page below doesn't move when the slogan changes. With
/// large text the slogan can wrap to more lines and the space grows.
class _DailySlogan extends StatefulWidget {
  const _DailySlogan();

  @override
  State<_DailySlogan> createState() => _DailySloganState();
}

class _DailySloganState extends State<_DailySlogan>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  // The last measurement, reused until the width, language or text size
  // changes.
  ({double width, String locale, TextScaler scaler, TextDirection direction})?
      _measuredFor;
  double _reservedHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dailySloganService.refresh();
    _scheduleMidnightRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: the day may have changed.
    if (state == AppLifecycleState.resumed) {
      dailySloganService.refresh();
      _scheduleMidnightRefresh();
    }
  }

  /// Checks again right after the next midnight, while Home is open.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final justAfterMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    _midnightTimer = Timer(justAfterMidnight.difference(now), () {
      dailySloganService.refresh();
      _scheduleMidnightRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// The height of the tallest slogan, laid out exactly like the visible
  /// text (same style, direction, text size, language and width).
  double _tallestSloganHeight(
      S s, TextStyle style, double width, BuildContext context) {
    final locale = Localizations.localeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final key = (
      width: width,
      locale: locale.toLanguageTag(),
      scaler: scaler,
      direction: direction,
    );
    if (key == _measuredFor) return _reservedHeight;

    var tallest = 0.0;
    for (var i = 0; i < sloganCount; i++) {
      final painter = TextPainter(
        text: TextSpan(text: s.homeSlogan(i), style: style),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
      )..layout(maxWidth: width);
      if (painter.height > tallest) tallest = painter.height;
      painter.dispose();
    }
    _measuredFor = key;
    _reservedHeight = tallest;
    return tallest;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Near-black instead of brown, so it's easy to read on the background.
    final style = AppText.accent(context, size: 18, color: AppColors.textPrimary)
        .copyWith(height: 1.25);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: BoxConstraints(
          minHeight:
              _tallestSloganHeight(s, style, constraints.maxWidth, context),
        ),
        // Aligned to the top, so a shorter slogan stays right under the name.
        alignment: AlignmentDirectional.topStart,
        child: ValueListenableBuilder<int?>(
          valueListenable: dailySloganIndex,
          // Empty (but already the right size) until the slogan is loaded, so
          // nothing jumps.
          builder: (context, index, _) => index == null
              ? const SizedBox.shrink()
              : Text(s.homeSlogan(index), style: style),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather card (prototype for now): a weather picture with Thamoor on the
// right, and the location, temperature and weather on the left. It uses
// left/right (not start/end) so it looks the same in Arabic and English.
// ---------------------------------------------------------------------------

// The weather states (UI only, no real data yet).
enum _Weather { sunny, cloudy, rainy, windy, cold }

class _WeatherLook {
  const _WeatherLook(this.icon, this.image, this.prototypeTempC);
  final IconData icon;

  /// Weather picture in assets/images/ (without .png).
  final String image;

  /// The temperature shown for now.
  /// TODO(weather-api): replace with the real temperature.
  final int prototypeTempC;
}

// TODO(weather-api): Replace prototype weather values (state + temperature)
//   with real OpenWeather API data.
// TODO(weather-mapping): Map real API weather conditions to Sunny, Cloudy,
//   Rainy, Windy, or Cold (and pick the matching illustration).
const _weatherLooks = {
  _Weather.sunny:
      _WeatherLook(Icons.wb_sunny_outlined, 'ethmar_sunny_day', 32),
  _Weather.cloudy: _WeatherLook(Icons.cloud_outlined, 'ethmar_cloudy_day', 26),
  _Weather.rainy:
      _WeatherLook(Icons.water_drop_outlined, 'ethmar_rainy_day', 18),
  _Weather.windy: _WeatherLook(Icons.air_rounded, 'ethmar_windy_day', 24),
  _Weather.cold: _WeatherLook(Icons.ac_unit_rounded, 'ethmar_cold_day', 8),
};

// The weather shown for now. Change it to see another state (sunny /
// cloudy / rainy / windy / cold).
// TODO(weather-api): Replace with the current weather from the API.
const _prototypeWeather = _Weather.sunny;

/// How far across the card (from the left) the weather details can go, so
/// they don't cover Thamoor on the right.
const _weatherInfoSafeWidth = 0.55;

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final look = _weatherLooks[_prototypeWeather]!;
    // The weather pictures are 3:1 with a thin white band above and below.
    // The card is a bit wider (3.6:1), so "cover" fills it and only trims the
    // white band; the picture is never stretched. The rounded corners also
    // hide the white corners in the pictures.
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 3.6,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/${look.image}.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Weather details on the left (in both languages), centred vertically.
              // They never cover Thamoor, and shrink to fit if large text makes them too
              // tall.
              Positioned(
                left: 16,
                top: 10,
                bottom: 10,
                width: constraints.maxWidth * _weatherInfoSafeWidth - 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // Long names still wrap inside the safe width.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          constraints.maxWidth * _weatherInfoSafeWidth - 16,
                    ),
                    child: const _WeatherInfo(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The location on top (biggest text), then the temperature and weather
/// next to each other. Long names wrap instead of being cut off, and the
/// temperature and weather move to two lines if they don't fit. The icon
/// stays before the text in both languages.
class _WeatherInfo extends StatelessWidget {
  const _WeatherInfo();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final look = _weatherLooks[_prototypeWeather]!;
    final word = switch (_prototypeWeather) {
      _Weather.sunny => s.weatherSunny,
      _Weather.cloudy => s.weatherCloudy,
      _Weather.rainy => s.weatherRainy,
      _Weather.windy => s.weatherWindy,
      _Weather.cold => s.weatherCold,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TODO(location): Replace the hardcoded city (Riyadh) with the
        //   user's real location/city.
        _WeatherRow(
          icon: Icons.location_on_outlined,
          text: s.weatherCityRiyadh,
          iconSize: 18,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        // Temperature and weather next to each other at the same size. The
        // weather moves below if there isn't room.
        Wrap(
          textDirection: TextDirection.ltr,
          spacing: 18,
          runSpacing: 6,
          children: [
            // TODO(weather-api): Show the real current temperature from
            //   the API.
            _WeatherRow(
              icon: Icons.thermostat_rounded,
              text: '${look.prototypeTempC}°C',
            ),
            _WeatherRow(icon: look.icon, text: word),
          ],
        ),
      ],
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({
    required this.icon,
    required this.text,
    this.iconSize = 16,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });
  final IconData icon;
  final String text;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    // When the text wraps to more lines, the icon lines up with the first line
    // instead of the middle of the block.
    final firstLineInset = ((fontSize * 1.3 - iconSize) / 2).clamp(0.0, 8.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: firstLineInset),
          child: Icon(icon, size: iconSize, color: AppColors.forest),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            softWrap: true,
            style: AppText.label(context)
                .copyWith(fontSize: fontSize, fontWeight: fontWeight),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Streak card: not started, active or lost. It can't be tapped.
// The fire picture is the same in every state; it only pulses while the
// streak is active.
// ---------------------------------------------------------------------------

// Streak states shown on Home.
enum _StreakState { notStarted, active, lost }

/// The streak's state, title and hint. It is active while above 0, lost
/// when it went back to 0 after a completed day, and otherwise not started.
/// [missed] is true when it was lost because earlier tasks weren't done
/// (see [streakBrokenByMissedTasks]), and the hint then says so.
(_StreakState, String, String) _streakTexts(
  S s,
  FarmStats stats, {
  bool missed = false,
}) {
  final state = stats.currentStreak > 0 && !missed
      ? _StreakState.active
      : stats.lastCompletedDate != null
      ? _StreakState.lost
      : _StreakState.notStarted;
  final (title, hint) = switch (state) {
    _StreakState.notStarted => (s.streakNotStartedTitle, s.streakNotStartedHint),
    _StreakState.active =>
      (s.streakActiveTitle(stats.currentStreak), s.streakActiveHint),
    _StreakState.lost =>
      (s.streakLostTitle, missed ? s.streakMissedMessage : s.streakLostHint),
  };
  return (state, title, hint);
}

/// Shows a friendly dialog once when the streak was just lost because a
/// day with tasks was missed ([FarmStore.streakLost]). It waits until Home
/// is visible, so it never pops up over another page. It takes no space on
/// Home; the streak card then shows "Streak lost".
class _StreakLostAlert extends StatefulWidget {
  const _StreakLostAlert();

  @override
  State<_StreakLostAlert> createState() => _StreakLostAlertState();
}

class _StreakLostAlertState extends State<_StreakLostAlert> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    FarmStore.streakLost.addListener(_maybeShow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when Home becomes the visible tab or page again.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    FarmStore.streakLost.removeListener(_maybeShow);
    super.dispose();
  }

  Future<void> _maybeShow() async {
    final lost = FarmStore.streakLost.value;
    if (lost == 0 || _showing || !mounted) return;
    final onShow = (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (!onShow) return;
    _showing = true;
    FarmStore.streakLost.value = 0;
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => _StreakLostDialog(streak: lost),
    );
    _showing = false;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the tab or page changes, so the dialog shows as soon as
    // Home is on screen.
    TickerMode.valuesOf(context);
    ModalRoute.of(context);
    return const SizedBox.shrink();
  }
}

/// "Your streak ended": the fire, a kind message with the lost streak's
/// length, and a button to continue.
class _StreakLostDialog extends StatelessWidget {
  const _StreakLostDialog({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _StreakFire(animate: false, size: 56)),
            const SizedBox(height: 12),
            Text(
              s.streakLostDialogTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.streakLostDialogBody(streak),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 22),
            EthmarButton(
              label: s.streakLostDialogButton,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the streak was lost because of missed tasks.
bool _missedTasks(FarmStats stats) =>
    streakBrokenByMissedTasks(stats, FarmStore.plants.value, DateTime.now());

/// The Today's Tasks card's last measured height, so the Crop
/// Recommendations card can match it. Null until it is measured.
final _tasksCardHeight = ValueNotifier<double?>(null);

/// Lays out [child] normally and reports its height after each change
/// (after the frame, so listeners can rebuild safely).
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportHeight renderObject,
  ) =>
      renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

/// Current layout: one white card with today's tasks (title, progress bar
/// and count; tapping opens Daily Tasks) and the streak (the fire and the
/// number of days, on the end side). A thin line separates them. The row
/// follows the reading direction, so the tasks come first in both
/// languages.
class _TasksAndStreak extends StatelessWidget {
  const _TasksAndStreak();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: TodayTasksCard()),
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.border,
              ),
              _StreakCount(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The streak part of [_TasksAndStreak]: the fire and the current streak
/// (0 once it is lost). It can't be tapped; screen readers read the full
/// streak title and hint.
class _StreakCount extends StatelessWidget {
  const _StreakCount();

  @override
  Widget build(BuildContext context) {
    // The plants are needed too, because they decide whether tasks were missed.
    return ListenableBuilder(
      listenable: Listenable.merge([FarmStore.stats, FarmStore.plants]),
      builder: (context, _) {
        final stats = FarmStore.stats.value;
        final (state, title, hint) =
            _streakTexts(S.of(context), stats, missed: _missedTasks(stats));
        final days = state == _StreakState.active ? stats.currentStreak : 0;
        return Semantics(
          label: '$title. $hint',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StreakFire(animate: state == _StreakState.active, size: 34),
                // Close to the fire and moved down a bit, so the number sits on the fire's
                // body instead of its tip.
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$days',
                    style: AppText.title(context).copyWith(
                      fontSize: 24,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The streak fire picture. It doesn't move by default; with [animate] it
/// gently pulses. It stays still when the phone is set to reduce motion.
class _StreakFire extends StatefulWidget {
  const _StreakFire({required this.animate, this.size = 36});
  final bool animate;
  final double size;

  @override
  State<_StreakFire> createState() => _StreakFireState();
}

class _StreakFireState extends State<_StreakFire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 1.08).animate(_curve);
  late final Animation<double> _opacity =
      Tween<double>(begin: 0.9, end: 1.0).animate(_curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StreakFire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  /// Runs the pulse only when it's wanted and allowed.
  void _sync() {
    final run = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!run && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fire = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        'assets/images/ethmar_streak_icon.png',
        fit: BoxFit.contain,
      ),
    );
    if (!widget.animate) return fire;
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: fire),
    );
  }
}

// ---------------------------------------------------------------------------
// Ethmar Services (current layout): a Crop Recommendations card, then three
// tiles next to each other (Agricultural Places, Check Your Plant,
// Leaderboard). The tile order is the same in both languages. All four are
// white cards with a soft shadow, like the Today's Tasks card.
// ---------------------------------------------------------------------------

class _ExploreSection extends StatelessWidget {
  const _ExploreSection();

  /// How far the Crop Recommendations card goes past the page margin on each
  /// side, so it looks like the main card above the tiles.
  static const _mainCardBleed = 4.0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.homeExplore,
          style: AppText.title(context).copyWith(fontSize: 20),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) => OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minWidth: constraints.maxWidth + 2 * _mainCardBleed,
            maxWidth: constraints.maxWidth + 2 * _mainCardBleed,
            child: const _RecommendCard(),
          ),
        ),
        const SizedBox(height: 12),
        // All three tiles get the height of the tallest one.
        IntrinsicHeight(
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ExploreTile(
                  image: 'ethmar_location_icon',
                  label: s.homeCardNearMe,
                  onTap: () => Navigator.of(context)
                      .push(riseRoute(const AgriMapScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExploreTile(
                  image: 'ethmar_plant_diseases_icon',
                  label: s.homeCardDiagnosis,
                  onTap: () => Navigator.of(context)
                      .push(riseRoute(const LeafScanScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ExploreTile(
                  image: 'ethmar_leaderboard_icon',
                  label: s.homeCardLeaderboard,
                  onTap: () => Navigator.of(context)
                      .push(riseRoute(const LeaderboardScreen())),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The shared style of the Ethmar Services cards: white, rounded, a thin
/// border and a soft shadow. The whole card is the button.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  static const _radius = 20.0;

  /// The same 1px border as the Today's Tasks card. It is drawn on the card's
  /// edge, so it doesn't change the card's size.
  static const _border = BorderSide(color: AppColors.border);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: _border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forest.withValues(alpha: 0.08),
          highlightColor: AppColors.forest.withValues(alpha: 0.04),
          child: child,
        ),
      ),
    );
  }
}

/// The Crop Recommendations card: its name and a short line, with a picture
/// on the end side and an arrow. Tapping it opens Crop Recommendation.
class _RecommendCard extends StatelessWidget {
  const _RecommendCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: '${s.homeCardRecommended}. ${s.homeRecommendHint}',
      excludeSemantics: true,
      // As tall as the Today's Tasks card above it (measured, so it matches on
      // every screen), with the content centred. Until that card is measured, or
      // if large text needs more space, it is as tall as its content.
      child: ValueListenableBuilder<double?>(
        valueListenable: _tasksCardHeight,
        builder: (context, tasksHeight, child) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: tasksHeight ?? 0),
          child: child,
        ),
        child: _ServiceCard(
          onTap: () => Navigator.of(context)
              .push(riseRoute(const CropRecommendationScreen())),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.homeCardRecommended,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(context)
                            .copyWith(fontSize: 19, height: 1.25),
                      ),
                      const SizedBox(height: 2),
                      // One line on every screen (a bit smaller on narrow ones), so the card
                      // stays as short as the tasks card.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          s.homeRecommendHint,
                          maxLines: 1,
                          softWrap: false,
                          style: AppText.body(
                            context,
                            color: AppColors.textPrimary,
                          ).copyWith(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/ethmar_recomender_icon.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 4),
                // chevron_right flips by itself in Arabic.
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white service tile: the feature's picture with its name below.
class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.image,
    required this.label,
    required this.onTap,
  });

  /// Picture in assets/images/ (without .png).
  final String image;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _ServiceCard(
        onTap: onTap,
        // At least 120 tall, and taller with large text so the name is never cut
        // off (the row makes all three tiles the same height).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/$image.png',
                  width: 54,
                  height: 54,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  // Grows with the phone's text size, but only up to 1.15x, so a long word
                  // ("Agricultural") still fits the narrow tile.
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.15),
                  style: AppText.label(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
