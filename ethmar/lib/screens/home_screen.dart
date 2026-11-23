import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit, RenderProxyBox;

import '../app_layout.dart';
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
import 'add_plant_screen.dart';
import 'agri_map_screen.dart';
import 'crop_recommendation_screen.dart';
import 'leaderboard_screen.dart';
import 'leaf_scan_screen.dart';
import 'profile_screen.dart';

/// Home: logo and avatar on top, then the time-of-day greeting, then:
/// - now: the weather card, one card with Today's Tasks (opens Daily Tasks)
///   and the streak, and Ethmar Services: a compact Crop Recommendations
///   card and three tiles (Agricultural Places, Check Your Plant,
///   Leaderboard). Plants are added from Your Farm.
/// - with [useClassicLayout]: the streak card, the weather card and the five
///   feature cards (Add Plant, Disease Diagnosis, Near Me, Recommended,
///   Leaderboard).
///
/// It is the first tab of MainShell, which draws the shared bottom bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.username = ''});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative background: fills the screen without stretching and
          // stays in place while the content scrolls over it.
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
              // Keep normal scrolling, but no stretch when pulling past the
              // edges.
              behavior:
                  ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: LayoutBuilder(
                builder: (context, viewport) {
                  // One shared side margin, so every section lines up.
                  // The bottom keeps clear of the farm button over the bar.
                  final padding = EdgeInsetsDirectional.fromSTEB(
                    24,
                    8,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  );
                  return SingleChildScrollView(
                    padding: padding,
                    // At least as tall as the screen. When the content is
                    // shorter, the room left over is shared out: half above
                    // the greeting (so everything below the logo moves down
                    // together, keeping its own spacing) and half at the
                    // bottom. When it is taller (small screen, large text),
                    // there is nothing to share and the page just scrolls.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (viewport.maxHeight - padding.vertical)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Both follow the shared username, so they update
                          // as soon as it changes (e.g. after Edit Profile).
                          ValueListenableBuilder<String>(
                            valueListenable: currentUsername,
                            builder: (context, savedName, _) => _TopBar(
                                username:
                                    savedName.isEmpty ? username : savedName),
                          ),
                          _content(),
                          // The bottom half of the room left over.
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

  /// Everything below the top bar, with its own fixed spacing.
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
          child: useClassicLayout
              ? const _StreakCard()
              // Its height is shared with the Crop Recommendations card.
              : _ReportHeight(
                  onHeight: (height) => _tasksCardHeight.value = height,
                  child: const _TasksAndStreak(),
                ),
        ),
        const SizedBox(height: 20),
        const Entrance(
          delay: Duration(milliseconds: 200),
          child: useClassicLayout
              ? _FeatureGrid()
              : _ExploreSection(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar: logo in the start corner, avatar in the end corner
// (Row flips these automatically in Arabic).
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

/// The user's avatar. Tapping it opens the Profile Page.
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
        // Forest-green ring like Profile's, around the 44px avatar; the ring
        // also keeps the tap area above 48px.
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
// Greeting: "Good evening," + username, and one hand-written accent line.
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
    // The three lines sit close together, as one block. The name has the
    // same line height in both languages (and room for Arabic marks), so
    // the rest of the page doesn't move when switching.
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
/// [dailySloganService]) in near-black.
///
/// The slot is as tall as the longest of the three slogans in the current
/// language, at this width and text size, so the page below doesn't move
/// when the slogan changes from day to day. It's only a minimum: with large
/// text the slogan can wrap onto more lines and the slot grows.
class _DailySlogan extends StatefulWidget {
  const _DailySlogan();

  @override
  State<_DailySlogan> createState() => _DailySloganState();
}

class _DailySloganState extends State<_DailySlogan>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  // Last measurement, reused until the width, language or text size changes.
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
    // Back from the background: the day may have changed meanwhile.
    if (state == AppLifecycleState.resumed) {
      dailySloganService.refresh();
      _scheduleMidnightRefresh();
    }
  }

  /// Checks again just after the next local midnight, while Home is open.
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

  /// Height of the tallest slogan, laid out exactly like the visible text:
  /// same style, direction, text size, locale and width.
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
    // Near-black, not brown, so it reads clearly on the background.
    final style = AppText.accent(context, size: 18, color: AppColors.textPrimary)
        .copyWith(height: 1.25);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: BoxConstraints(
          minHeight:
              _tallestSloganHeight(s, style, constraints.maxWidth, context),
        ),
        // Top, so a shorter slogan stays right under the name.
        alignment: AlignmentDirectional.topStart,
        child: ValueListenableBuilder<int?>(
          valueListenable: dailySloganIndex,
          // Empty (but already sized) for the moment before the first
          // lookup finishes, so nothing jumps.
          builder: (context, index, _) => index == null
              ? const SizedBox.shrink()
              : Text(s.homeSlogan(index), style: style),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather card (prototype for this sprint): a full weather illustration with
// Thamoor on the right, and location, temperature and the weather word on
// the left. Fixed positions (left/right, not start/end) so it looks the same
// in Arabic and English.
// ---------------------------------------------------------------------------

// Prototype weather states (UI only, no real data yet).
enum _Weather { sunny, cloudy, rainy, windy, cold }

class _WeatherLook {
  const _WeatherLook(this.icon, this.image, this.prototypeTempC);
  final IconData icon;

  /// Weather illustration in assets/images/ (without .png).
  final String image;

  /// TODO(weather-api): Prototype temperature, replaced by the real one.
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

// Change this to preview another state (sunny / cloudy / rainy / windy / cold).
// TODO(weather-api): Replace with the current weather from the API.
const _prototypeWeather = _Weather.sunny;

/// How far across the card (from its left edge) the weather details may
/// reach, keeping them clear of Thamoor on the right. Same for all states.
const _weatherInfoSafeWidth = 0.55;

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final look = _weatherLooks[_prototypeWeather]!;
    // The slim illustrations are 3:1 with a thin white band baked in above
    // and below the scene. The card is a little wider than that (3.6:1), so
    // "cover" fills it edge to edge and trims only that white band; the
    // picture keeps its shape and is never stretched. Rounded clipping also
    // hides the white corners baked into the images.
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
              // Weather details on the left (in both languages), centred
              // up and down. They never reach Thamoor on the right, and
              // shrink to fit if large text would make them too tall.
              Positioned(
                left: 16,
                top: 10,
                bottom: 10,
                width: constraints.maxWidth * _weatherInfoSafeWidth - 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // Still wraps long names within the safe width.
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

/// Location on top (the strongest text), then temperature and weather word
/// side by side, drawn straight on the illustration. Long names wrap instead
/// of being cut off, and the temperature and weather word move onto two
/// lines if they don't fit side by side. Rows keep the icon before the text
/// in both languages; the Arabic words themselves still read right-to-left.
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
        // Temperature and weather word side by side, the same size; the
        // weather word moves below if there isn't room.
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
    // Text wraps onto more lines when needed, so the icon lines up with the
    // first line (roughly centred on it) instead of the middle of the block.
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
// Streak card: not started, active or lost. It isn't tappable.
// The fire is the same picture in every state; it only pulses while the
// streak is active.
// ---------------------------------------------------------------------------

// Streak states shown on Home.
enum _StreakState { notStarted, active, lost }

/// The streak's state, title and hint: active while it is above 0; lost
/// when it went back to 0 after a completed day; otherwise not started.
/// [missed] is true when it was lost because earlier tasks weren't done
/// (see [streakBrokenByMissedTasks]); the hint then says so.
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

/// Shows a friendly dialog once when the streak was just lost because a day
/// with tasks was missed ([FarmStore.streakLost]). It waits until Home is
/// the screen on show, so it never pops up over another page. It takes no
/// room on Home itself; the streak card then shows "Streak lost".
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
    // Also runs when Home becomes the visible tab or route again.
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
    // Rebuilt when the tab's ticker mode or the route changes, so the dialog
    // shows as soon as Home is on screen.
    TickerMode.valuesOf(context);
    ModalRoute.of(context);
    return const SizedBox.shrink();
  }
}

/// "Your streak ended": the still fire, a kind line with the lost streak's
/// length, and a button to carry on.
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

/// Whether the streak was lost to missed tasks, for the streak cards.
bool _missedTasks(FarmStats stats) =>
    streakBrokenByMissedTasks(stats, FarmStore.plants.value, DateTime.now());

/// The Today's Tasks card's height as last laid out, so the Crop
/// Recommendations card can match it. Null until it has been measured.
final _tasksCardHeight = ValueNotifier<double?>(null);

/// Lays out [child] as usual and reports its height after each change (after
/// the frame, so listeners can rebuild safely).
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

/// Current layout: one short white card with today's tasks (the main part:
/// title, progress bar and count; it opens Daily Tasks) and the streak (a
/// small part on the end side: the fire and the number of days). A thin
/// line separates them. The row follows the reading direction, so the
/// tasks come first in both languages.
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
/// (0 once it is lost). It isn't tappable; screen readers hear the full
/// streak title and hint.
class _StreakCount extends StatelessWidget {
  const _StreakCount();

  @override
  Widget build(BuildContext context) {
    // The plants too: they decide whether tasks were missed.
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
                // Close to the fire, and nudged down so the number sits on
                // the fire's body rather than its tip.
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

/// Classic layout: the user's streak from [FarmStore.stats] as a full-width
/// bar.
class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FarmStore.stats, FarmStore.plants]),
      builder: (context, _) => _buildCard(context, FarmStore.stats.value),
    );
  }

  Widget _buildCard(BuildContext context, FarmStats stats) {
    final (state, title, hint) =
        _streakTexts(S.of(context), stats, missed: _missedTasks(stats));
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.sunTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StreakFire(animate: state == _StreakState.active),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.label(context)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                // Smaller and lighter than the title, with room for Arabic.
                Text(
                  hint,
                  style: AppText.small(context).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The streak fire picture. Static by default; with [animate] it gently
/// pulses (a little bigger and back, with a very soft fade). It stays static
/// when the phone asks for reduced motion.
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

  /// Runs the pulse only while animating is wanted and allowed.
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
// Ethmar Services (current layout): one compact Crop Recommendations card,
// then three tiles side by side (Agricultural Places, Check Your Plant,
// Leaderboard). The tile order stays the same in both languages (LTR row),
// like the classic grid. All four are plain white cards with a soft shadow,
// like the Today's Tasks card.
// ---------------------------------------------------------------------------

class _ExploreSection extends StatelessWidget {
  const _ExploreSection();

  /// How far the Crop Recommendations card reaches past the page margin on
  /// each side, so it reads as the main card above the tiles.
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
        // The three tiles share the tallest one's height.
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

/// The shared look of the Ethmar Services cards: white, rounded, a thin
/// border and a soft forest shadow. The whole card is the button.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  static const _radius = 20.0;

  /// The Today's Tasks card's border (1px, the theme's border colour),
  /// used by all four cards. It is drawn on the card's edge, so it doesn't
  /// change the card's size.
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

/// The compact Crop Recommendations card: its name and a short line, with
/// the recommendation picture on the end side and an arrow. The whole card
/// opens Crop Recommendation.
class _RecommendCard extends StatelessWidget {
  const _RecommendCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: '${s.homeCardRecommended}. ${s.homeRecommendHint}',
      excludeSemantics: true,
      // As tall as the Today's Tasks card above (measured, so it matches on
      // every screen); the content is centred in it. Until that card has
      // been measured, or if large text needs more room, it is as tall as
      // its content.
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
                      // One line on every screen (a little smaller on narrow
                      // ones), so the card stays as short as the tasks card.
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
                // chevron_right flips automatically in Arabic.
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

/// A white service tile: the feature's picture and its name below.
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
        // At least 120 tall; taller with large text, so the name is never
        // cut off (the row makes all three tiles the same height).
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
                  // Grows with the phone's text size, but only up to 1.15x,
                  // so a long word ("Agricultural") still fits the narrow
                  // tile instead of breaking in the middle.
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

// ---------------------------------------------------------------------------
// Feature cards (classic layout, useClassicLayout = true), all light green:
//   Add Plant      | Disease Diagnosis
//   Near Me        | Recommended
//   Leaderboard (full width)
// Each card is compact and horizontal: picture, name, then a chevron.
// The card positions stay the same in both languages (LTR rows); the
// content inside each card still follows the reading direction.
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  static const _gap = 8.0; // between the two cards in a row
  static const _rowGap = 12.0; // between rows

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: _FeatureCard(
                image: 'ethmar_add_plant_icon',
                iconWidth: 44,
                iconHeight: 44,
                iconLabelGap: 1,
                iconStartOffset: 3.0,
                label: s.homeCardAddPlant,
                onTap: () => AddPlantScreen.open(context),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _FeatureCard(
                image: 'ethmar_plant_diseases_icon',
                iconWidth: 32,
                iconHeight: 32,
                iconLabelGap: 10.5,
                label: s.homeCardDiagnosis,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const LeafScanScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: _rowGap),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: _FeatureCard(
                image: 'ethmar_location_icon',
                iconWidth: 32,
                iconHeight: 32,
                iconLabelGap: 6,
                label: s.homeCardNearMe,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const AgriMapScreen())),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: _FeatureCard(
                image: 'ethmar_recomender_icon',
                iconWidth: 33,
                iconHeight: 33,
                iconLabelGap: 6,
                label: s.homeCardRecommended,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const CropRecommendationScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: _rowGap),
        _FeatureCard(
          image: 'ethmar_leaderboard_icon',
          iconWidth: 38,
          iconHeight: 38,
          iconLabelGap: 10,
          extraStartPadding: 8,
          label: s.homeCardLeaderboard,
          onTap: () => Navigator.of(context)
              .push(riseRoute(const LeaderboardScreen())),
        ),
      ],
    );
  }
}

/// One compact light-green feature card: picture, name and a chevron in a
/// row that follows the reading direction, so Arabic reads
/// "chevron … name picture" and English "picture name … chevron".
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.image,
    required this.label,
    required this.onTap,
    this.iconWidth = 36,
    this.iconHeight = 36,
    this.iconLabelGap = 8,
    this.iconStartOffset = 0,
    this.extraStartPadding = 0,
  });

  /// Picture in assets/images/ (without .png).
  final String image;
  final String label;
  final VoidCallback onTap;

  /// Box the picture is fitted into. Each picture has a different amount of
  /// empty space around it, so each card sets its own box to make the
  /// pictures look the same size.
  final double iconWidth;
  final double iconHeight;

  /// Space between the picture and the name. Set per card because the
  /// pictures look different sizes, so the same gap doesn't look equal.
  final double iconLabelGap;

  /// Moves only the picture this far toward the card's start edge (left in
  /// English, right in Arabic), for pictures that look too far from the
  /// edge. It doesn't move the name or the chevron.
  final double iconStartOffset;

  /// Extra space before the picture (left in English, right in Arabic).
  /// Moves the picture and name inward together; the chevron stays put.
  final double extraStartPadding;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: 72,
      child: Material(
        color: AppColors.featureCard,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.forest.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                8 + extraStartPadding, 10, 4, 10),
            child: Row(
              children: [
                // The source pictures have different canvas sizes, so each
                // one sits in a fixed box and is scaled to fit (never
                // stretched).
                Transform.translate(
                  // Toward the start edge: left in English, right in Arabic.
                  offset: Offset(rtl ? iconStartOffset : -iconStartOffset, 0),
                  child: SizedBox(
                    width: iconWidth,
                    height: iconHeight,
                    child: Image.asset('assets/images/$image.png',
                        fit: BoxFit.contain),
                  ),
                ),
                SizedBox(width: iconLabelGap),
                // Same size on every card. Names with more than one word
                // wrap between words (up to two lines). A single word stays
                // on one line, so it is never split in the middle; it would
                // only end in "…" on a very narrow screen.
                Expanded(
                  child: Text(
                    label,
                    maxLines: label.trim().contains(' ') ? 2 : 1,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(context,
                            color: AppColors.textPrimary)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 2),
                // chevron_right flips automatically in Arabic.
                const ExcludeSemantics(
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.featureCardText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
