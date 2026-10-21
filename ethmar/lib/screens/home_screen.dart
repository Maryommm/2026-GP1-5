import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/daily_slogan_service.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_logo.dart';
import '../widgets/page_routes.dart';
import '../widgets/user_avatar.dart';
import 'add_plant_screen.dart';
import 'agri_map_screen.dart';
import 'crop_recommendation_screen.dart';
import 'leaderboard_screen.dart';
import 'leaf_scan_screen.dart';
import 'profile_screen.dart';

/// Home: logo and avatar on top, a time-of-day greeting, the weather card,
/// the streak card, then five feature cards (Add Plant, Disease Diagnosis,
/// Near Me, Recommended, Leaderboard).
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
              child: SingleChildScrollView(
                // One shared side margin, so every section lines up.
                padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Both follow the shared username, so they update as soon
                    // as it changes (e.g. after Edit Profile).
                    ValueListenableBuilder<String>(
                      valueListenable: currentUsername,
                      builder: (context, savedName, _) => _TopBar(
                          username: savedName.isEmpty ? username : savedName),
                    ),
                    const SizedBox(height: 20),
                    Entrance(
                      child: ValueListenableBuilder<String>(
                        valueListenable: currentUsername,
                        builder: (context, savedName, _) => _Greeting(
                            username:
                                savedName.isEmpty ? username : savedName),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Entrance(
                      delay: Duration(milliseconds: 100),
                      child: _WeatherCard(),
                    ),
                    const SizedBox(height: 16),
                    const Entrance(
                      delay: Duration(milliseconds: 150),
                      child: _StreakCard(),
                    ),
                    const SizedBox(height: 20),
                    const Entrance(
                      delay: Duration(milliseconds: 200),
                      child: _FeatureGrid(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppText.label(context)),
        // Reserve the same height in both languages (the taller Arabic
        // line) so the rest of the page doesn't move when switching.
        Container(
          constraints: const BoxConstraints(minHeight: 41),
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            username.isEmpty ? s.homeFriend : username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title(context),
          ),
        ),
        const SizedBox(height: 4),
        const _DailySlogan(),
      ],
    );
  }
}

/// Today's slogan (one of three, picked once per day by
/// [dailySloganService]) in earthy brown.
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
    final style =
        AppText.accent(context, size: 18, color: AppColors.earthBrown);
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: BoxConstraints(
          minHeight:
              _tallestSloganHeight(s, style, constraints.maxWidth, context),
        ),
        alignment: AlignmentDirectional.centerStart,
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
    // The illustrations are 2:1, so the card keeps that shape and the
    // picture is never stretched. Rounded clipping also hides the white
    // corners baked into some of the images.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 2,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/${look.image}.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Weather details in the top-left corner (in both languages).
              // They are as wide as their text, but never reach Thamoor on
              // the right.
              Positioned(
                left: 20,
                top: 20,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        constraints.maxWidth * _weatherInfoSafeWidth - 20,
                  ),
                  child: const _WeatherInfo(),
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
          iconSize: 20,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        // Temperature and weather word side by side, the same size; the
        // weather word moves below if there isn't room.
        Wrap(
          textDirection: TextDirection.ltr,
          spacing: 12,
          runSpacing: 4,
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

// Streak states shown on Home (UI only for now).
enum _StreakState { notStarted, active, lost }

// TODO(streak): Replace these prototype values with the user's real streak
//   (state + current count) once plants and daily tasks are saved.
// Change _prototypeStreak to preview another state.
const _prototypeStreak = _StreakState.notStarted;
const _prototypeStreakCount = 5; // only used when the state is active

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (title, hint) = switch (_prototypeStreak) {
      _StreakState.notStarted => (s.streakNotStartedTitle, s.streakNotStartedHint),
      _StreakState.active =>
        (s.streakActiveTitle(_prototypeStreakCount), s.streakActiveHint),
      _StreakState.lost => (s.streakLostTitle, s.streakLostHint),
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.sunTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StreakFire(animate: _prototypeStreak == _StreakState.active),
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
  const _StreakFire({required this.animate});
  final bool animate;

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
      width: 36,
      height: 36,
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
// Feature cards, all light green:
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
