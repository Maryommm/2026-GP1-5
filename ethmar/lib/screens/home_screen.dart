import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart' show kControlRadius;
import '../widgets/ethmar_logo.dart';
import '../widgets/page_routes.dart';
import '../widgets/user_avatar.dart';
import 'add_plant_screen.dart';
import 'agri_map_screen.dart';
import 'chat_screen.dart';
import 'crop_recommendation_screen.dart';
import 'leaf_scan_screen.dart';
import 'profile_screen.dart';
import 'virtual_farm_screen.dart';

/// Home: logo and avatar on top, a time-of-day greeting, the streak card,
/// the character card with "Add Plant", then the four feature cards.
/// The bottom bar holds Home, Daily Tasks, Virtual Farm and Leaderboard.
///
/// UI only for now: the four feature cards open their screens.
/// The other actions are drawn but do nothing until their features are built.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.username = ''});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LeafPrintBackground(
        child: SafeArea(
          bottom: false,
          child: ScrollConfiguration(
            // Keep normal scrolling, but no stretch when pulling past the edges.
            behavior:
                ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
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
                          username: savedName.isEmpty ? username : savedName),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Entrance(
                    delay: Duration(milliseconds: 100),
                    child: _StreakCard(),
                  ),
                  const SizedBox(height: 16),
                  const Entrance(
                    delay: Duration(milliseconds: 150),
                    child: _HeroCard(),
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
      ),
      bottomNavigationBar: const _HomeBottomBar(),
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
        child: Padding(
          // 2px around the 44px avatar = a 48px tap area.
          padding: const EdgeInsets.all(2),
          child: UserAvatar(username: username),
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
        Container(
          constraints: const BoxConstraints(minHeight: 26),
          alignment: AlignmentDirectional.centerStart,
          child:
              Text(s.homeMotivation, style: AppText.accent(context, size: 18)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Streak card. Real streaks need plants and daily tasks, which aren't built
// yet, so this always shows the "not started" state (0 days).
// ---------------------------------------------------------------------------

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.sunTint,
        borderRadius: kControlRadius,
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 34, color: AppColors.coral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.homeStreakDays,
                  style: AppText.label(context)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(s.homeStreakHint, style: AppText.small(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weather card (prototype for this sprint): location, temperature and the
// weather word in the top left, the matching weather character on the
// right, and the "Add Plant" pill in the bottom left corner.
// Fixed positions (left/right, not start/end) so it looks the same in
// Arabic and English.
// ---------------------------------------------------------------------------

// Prototype weather states (UI only, no real data yet).
enum _Weather { sunny, cloudy, rainy, windy, cold }

class _WeatherLook {
  const _WeatherLook(this.icon, this.image, this.prototypeTempC);
  final IconData icon;

  /// Character image name in assets/images/ (without .png).
  final String image;

  /// TODO(weather-api): Prototype temperature, replaced by the real one.
  final int prototypeTempC;
}

// TODO(weather-api): Replace prototype weather values (state + temperature)
//   with real OpenWeather API data.
// TODO(weather-mapping): Map real API weather conditions to Sunny, Cloudy,
//   Rainy, Windy, or Cold (and pick the matching character image).
const _weatherLooks = {
  _Weather.sunny:
      _WeatherLook(Icons.wb_sunny_outlined, 'ethmar_sunny_day_character', 32),
  _Weather.cloudy:
      _WeatherLook(Icons.cloud_outlined, 'ethmar_cloudy_day_character', 26),
  _Weather.rainy: _WeatherLook(
      Icons.water_drop_outlined, 'ethmar_rainy_day_character', 18),
  _Weather.windy:
      _WeatherLook(Icons.air_rounded, 'ethmar_windy_day_character', 24),
  _Weather.cold:
      _WeatherLook(Icons.ac_unit_rounded, 'ethmar_cold_day_character', 8),
};

// Change this to preview another state (sunny / cloudy / rainy / windy / cold).
// TODO(weather-api): Replace with the current weather from the API.
const _prototypeWeather = _Weather.sunny;

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: const BoxDecoration(
        color: AppColors.seaTint,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: const Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 20),
              child: _WeatherCharacter(),
            ),
          ),
          // Weather details in the top left, kept to the left part of the
          // card so they never reach the character or the Add Plant pill.
          Positioned(
            left: 16,
            top: 16,
            right: 0,
            child: FractionallySizedBox(
              alignment: Alignment.topLeft,
              widthFactor: 0.55,
              child: _WeatherInfo(),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: _AddPlantPill(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Ethmar character for the current (prototype) weather.
class _WeatherCharacter extends StatelessWidget {
  const _WeatherCharacter();

  @override
  Widget build(BuildContext context) {
    return EthmarCharacter(
      name: _weatherLooks[_prototypeWeather]!.image,
      height: 170,
    );
  }
}

/// Location, temperature and weather word, each with its icon.
/// Rows keep the icon before the text in both languages; the Arabic words
/// themselves still read right-to-left.
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
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TODO(location): Replace the hardcoded city (Riyadh) with the
        //   user's real location/city.
        _WeatherRow(
            icon: Icons.location_on_outlined, text: s.weatherCityRiyadh),
        const SizedBox(height: 8),
        // TODO(weather-api): Show the real current temperature from the API.
        _WeatherRow(
          icon: Icons.thermostat_rounded,
          text: '${look.prototypeTempC}°C',
          large: true,
        ),
        const SizedBox(height: 8),
        _WeatherRow(icon: look.icon, text: word),
      ],
    );
  }
}

class _WeatherRow extends StatelessWidget {
  const _WeatherRow({
    required this.icon,
    required this.text,
    this.large = false,
  });
  final IconData icon;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        Icon(icon, size: large ? 24 : 20, color: AppColors.forest),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: large
                ? AppText.label(context)
                    .copyWith(fontSize: 22, fontWeight: FontWeight.w700)
                : AppText.label(context)
                    .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Small forest pill, same colours and text style as [EthmarButton].
/// Opens the add-a-plant steps.
class _AddPlantPill extends StatelessWidget {
  const _AddPlantPill();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: AppColors.overlay,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AddPlantScreen.open(context),
        splashColor: const Color(0x22FFFFFF),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 18, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: AppColors.onForest),
              const SizedBox(width: 6),
              Text(S.of(context).homeAddPlant,
                  style: AppText.button(context).copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature cards: 2 x 2 grid of forest cards (icon on top, label below).
// The card positions stay the same in both languages (LTR rows); the
// content inside each card still follows the reading direction.
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

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
                icon: Icons.help_outline_rounded,
                label: s.homeWhatToPlant,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const CropRecommendationScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureCard(
                icon: Icons.photo_camera_outlined,
                label: s.homeScanPlant,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const LeafScanScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.map_outlined,
                label: s.homeNearMe,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const AgriMapScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureCard(
                icon: Icons.smart_toy_outlined,
                label: s.homeAskEthmar,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const ChatScreen())),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One feature card. Without [onTap] the card is drawn but does nothing
/// (its feature screen isn't built yet).
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: Material(
        color: AppColors.forest,
        borderRadius: kControlRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () {},
          splashColor: const Color(0x22FFFFFF),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 30, color: AppColors.onForest),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.button(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar: Home (selected), Daily Tasks, Virtual Farm, Leaderboard.
// Virtual Farm opens its screen; Daily Tasks and Leaderboard do nothing yet.
// ---------------------------------------------------------------------------

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          // Same tab order in both languages.
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              _NavItem(
                  icon: Icons.home_rounded, label: s.navHome, selected: true),
              _NavItem(icon: Icons.checklist_rounded, label: s.navDailyTasks),
              _NavItem(
                icon: Icons.yard_outlined,
                label: s.navVirtualFarm,
                onTap: () => Navigator.of(context)
                    .push(riseRoute(const VirtualFarmScreen())),
              ),
              _NavItem(
                  icon: Icons.leaderboard_outlined, label: s.navLeaderboard),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;

  /// Null for tabs whose screen isn't built yet (tapping does nothing).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Soft pill behind the selected icon.
                Container(
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.forestTint : null,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppText.small(context, color: color).copyWith(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
