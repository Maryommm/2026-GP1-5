// ("What to plant").
//
// The file is in four parts:
//   1. CropRecommendationScreen - loads the data and picks which view to show.
//   2. _LoadingView / _ErrorView - shown while waiting or when it fails.
//   3. _ResultsView and its pieces - the category buttons and the tickets.
//   4. Drawing helpers - the ticket outline and the dashed line.

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart';
import '../services/auth_service.dart';
import '../services/crop_recommendation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_routes.dart';
import 'login_screen.dart';

/// Loads the crops after the first [loaded] ones, for the same request.
typedef LoadMoreCrops = Future<List<CropRecommendation>> Function(
    CropRecommendationResult first, int loaded);

/// three states: loading, error, and results.
class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key, this.load, this.loadMore});

  /// Loads the first page of recommendations.
  final Future<CropRecommendationResult> Function()? load;

  /// Loads the next page when the user scrolls to the end of a list.
  final LoadMoreCrops? loadMore;

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  // fetches the data
  late final _service = CropRecommendationService();
  late final _load = widget.load ?? _service.recommend;
  late final LoadMoreCrops _loadMore = widget.loadMore ?? _service.nextPage;
  late Future<CropRecommendationResult> _future = _load();
  // The braces matter: `() => _future = ...` would return the Future, which
  // setState doesn't allow.
  void _retry() => setState(() {
        _future = _load();
      });

  // True after we send the user to the phone's settings to allow location,
  // so we try again by ourselves when they come back to the app.
  bool _sentToSettings = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_sentToSettings) return;
    _sentToSettings = false;
    _retry();
  }

  void _openSettings(String status) {
    _sentToSettings = true;
    CropRecommendationService.openLocationSettings(status);
  }

  // The server no longer accepts the sign-in: sign out and open Login with
  // the email filled in.
  Future<void> _signInAgain() async {
    final auth = AuthService();
    final email = auth.currentSession?.email ?? '';
    try {
      await auth.signOut();
    } catch (_) {
      // Login signs in again either way.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      riseRoute(LoginScreen(email: email)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<CropRecommendationResult>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            // Only the results use the recommender's own background.
            var showingResults = false;
            final Widget child;
            //show the loading animation.
            if (loading) {
              child = const _LoadingView();
              // The request failed: show the error message.
            } else if (snap.hasError || snap.data == null) {
              child = _ErrorView(
                error: snap.error,
                onRetry: _retry,
                onOpenSettings: _openSettings,
                onSignIn: _signInAgain,
              );
              // It worked but returned no crops: show the "no crops" message.
            } else if (snap.data!.crops.isEmpty) {
              child = _ErrorView(onRetry: _retry, empty: true);
              // Success: show the seed packets.
            } else {
              child = _ResultsView(result: snap.data!, loadMore: _loadMore);
              showingResults = true;
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey(snap.connectionState),
                // The results use the recommender's own background, with the
                // hills and clouds behind Thamoor. Loading, "no crops" and
                // error messages use the shared inner background.
                child: LeafPrintBackground(
                  image: showingResults
                      ? 'assets/images/ethmar_recommender_background.png'
                      : LeafPrintBackground.asset,
                  child: child,
                ),
              ),
            );
          },
        ),
    );
  }
}

/// Loading screen
class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> {
  int _step = 0;
  late final Timer _timer;

  @override
  ///loading text
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (t) {
      if (_step >= 2) return t.cancel();
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    // Stop the timer when the screen closes so it doesn't keep running.
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // The loading messages, in the app's current language.
    final steps = s.cropLoadingSteps;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button in the top corner.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
            child: EthmarBackButton(tooltip: s.back),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: const BoxDecoration(
                            color: AppColors.featureCard,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const EthmarCharacter(
                          name: 'ethmar_buddy_thinking',
                          height: 190,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          steps[_step],
                          key: ValueKey(_step),
                          textAlign: TextAlign.center,
                          style: AppText.title(context).copyWith(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        minHeight: 6,
                        color: AppColors.forest,
                        backgroundColor: AppColors.featureCard,
                      ),
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

/// Shown when loading fails, or when no crop
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.onRetry,
    this.onOpenSettings,
    this.onSignIn,
    this.error,
    this.empty = false,
  });
  final VoidCallback onRetry;

  /// Opens the phone's settings for a LOCATION_OFF / LOCATION_BLOCKED error.
  final ValueChanged<String>? onOpenSettings;

  /// Sends the user to Login for an UNAUTHENTICATED error.
  final VoidCallback? onSignIn;
  final Object? error;

  /// The request worked but no crop suits the area this month.
  final bool empty;

  /// The error's status, e.g. 'LOCATION_DENIED' (null for other errors).
  String? get _status {
    final e = error;
    return e is CropRecommendationException ? e.status : null;
  }

  String _message(S s) {
    if (empty) return s.cropNoCrops;
    return switch (_status) {
      'UNAUTHENTICATED' => s.cropErrorSignIn,
      'UNAVAILABLE' => s.cropErrorClimate,
      'NETWORK' => s.cropErrorOffline,
      'LOCATION_DENIED' => s.cropLocationDenied,
      'LOCATION_BLOCKED' => s.cropLocationBlocked,
      'LOCATION_OFF' => s.cropLocationOff,
      'LOCATION_UNAVAILABLE' => s.cropLocationUnavailable,
      _ => s.cropError,
    };
  }

  /// The main button, plus a smaller "Try again" link when the main button
  /// sends the user to the phone's settings.
  List<Widget> _actions(S s) {
    final status = _status;
    // Trying again can't help until the user signs in again.
    final signIn = onSignIn;
    if (signIn != null && status == 'UNAUTHENTICATED') {
      return [EthmarButton(label: s.loginButton, onPressed: signIn)];
    }
    // Denied once: trying again shows the location prompt again.
    if (status == 'LOCATION_DENIED') {
      return [EthmarButton(label: s.mapAllowLocation, onPressed: onRetry)];
    }
    // Off or blocked: only the phone's settings can change it. The screen
    // tries again by itself when the user comes back.
    final open = onOpenSettings;
    if (open != null &&
        (status == 'LOCATION_OFF' || status == 'LOCATION_BLOCKED')) {
      return [
        EthmarButton(label: s.cropOpenSettings, onPressed: () => open(status!)),
        const SizedBox(height: 4),
        EthmarLink(label: s.tryAgain, onTap: onRetry),
      ];
    }
    return [EthmarButton(label: s.tryAgain, onPressed: onRetry)];
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Prints the real error in the debug console, for developers.
    if (error != null) debugPrint('crop recommendations failed: $error');
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
            child: EthmarBackButton(tooltip: s.back),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EthmarCharacter(
                    name: 'ethmar_buddy_worried',
                    height: 160,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _message(s),
                    textAlign: TextAlign.center,
                    style: AppText.body(context),
                  ),
                  const SizedBox(height: 24),
                  ..._actions(s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Results: one seed packet per crop.
String _weatherCharacter(GrowingConditions c) {
  if (c.rainMm > 50) return 'ethmar_rainy_day_character';
  if (c.tempLow <= 8) return 'ethmar_cold_day_character';
  if (c.tempHigh >= 30) return 'ethmar_sunny_day_character';
  return 'ethmar_cloudy_day_character';
}

/// The crops of one category, in the order the recommendation gave them.
class _CategoryGroup {
  _CategoryGroup(this.category);
  final CropCategory category;
  // Filled in by _groupByCategory below.
  final crops = <CropRecommendation>[];
}

/// Groups crops by category. Categories keep the order of their first
/// (best) crop, so the strongest suggestion's category comes first.
List<_CategoryGroup> _groupByCategory(List<CropRecommendation> crops) {
  final groups = <CropCategory, _CategoryGroup>{};
  for (final crop in crops) {
    groups
        .putIfAbsent(crop.category, () => _CategoryGroup(crop.category))
        .crops
        .add(crop);
  }
  return groups.values.toList();
}

// Display names and artwork for the five main categories on this screen.
// Grain and "Other crops" keep their existing label and art unchanged.

String _categoryLabel(CropCategory cat, BuildContext context) {
  final s = S.of(context);
  return switch (cat) {
    CropCategory.herb => s.cropCatHerb,
    CropCategory.legume => s.cropCatLegume,
    CropCategory.root => s.cropCatRoot,
    CropCategory.vegetable => s.cropCatVegetable,
    CropCategory.fruit => s.cropCatFruit,
    _ => cat.label.of(context),
  };
}

/// Small transparent icon for the category buttons.
String _categoryIcon(CropCategory cat) => switch (cat) {
      CropCategory.herb => 'assets/images/ethmar_herbs_icon.png',
      CropCategory.legume => 'assets/images/ethmar_legumes_icon.png',
      CropCategory.root => 'assets/images/ethmar_root_veg_icon.png',
      CropCategory.vegetable => 'assets/images/ethmar_veg_icon.png',
      CropCategory.fruit => 'assets/images/ethmar_fruits_icon.png',
      _ => cat.iconImage,
    };

/// Illustration on the ticket (drawn on a near-white background, so the
/// ticket face is warm white for it to blend in).
String _categoryPhoto(CropCategory cat) => switch (cat) {
      CropCategory.herb => 'assets/images/ethmar_herbs_photo.png',
      CropCategory.legume => 'assets/images/ethmar_legumes_photo.png',
      CropCategory.root => 'assets/images/ethmar_root_veg_photo.png',
      CropCategory.vegetable => 'assets/images/ethmar_veg_photo.png',
      CropCategory.fruit => 'assets/images/ethmar_fruits_photo.png',
      _ => cat.image,
    };

/// Swipe left/right between categories; each category's tickets scroll
/// freely up and down.
class _ResultsView extends StatefulWidget {
  const _ResultsView({required this.result, required this.loadMore});
  final CropRecommendationResult result;
  final LoadMoreCrops loadMore;

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  // Every crop loaded so far, best first. Grows by one page each time the
  // user scrolls to the end of a list.
  late final _crops = [...widget.result.crops];
  late var _groups = _groupByCategory(_crops);
  final _categoryPages = PageController(viewportFraction: 0.88);
  late var _chipKeys = [for (final _ in _groups) GlobalKey()];
  int _category = 0;
  bool _swipedSideways = false;

  // Paging. A failed page waits for "Try again" instead of retrying on
  // every scroll.
  late int _total = widget.result.total;
  bool _loadingMore = false;
  bool _moreFailed = false;

  bool get _hasMore => _crops.length < _total;

  Future<void> _loadMore() async {
    if (_loadingMore || _moreFailed || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.loadMore(widget.result, _crops.length);
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // An empty page means the list ended early; stop asking.
        if (page.isEmpty) _total = _crops.length;
        _crops.addAll(page);
        // Existing categories keep their place; new ones join at the end.
        _groups = _groupByCategory(_crops);
        _chipKeys = [
          ..._chipKeys,
          for (var i = _chipKeys.length; i < _groups.length; i++) GlobalKey(),
        ];
      });
    } catch (e) {
      debugPrint('more crop recommendations failed: $e');
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  void _retryMore() {
    setState(() => _moreFailed = false);
    _loadMore();
  }

  /// Shown under the last ticket of every list while a page loads or
  /// after one failed.
  Widget? _listFooter(S s) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.forest,
            ),
          ),
        ),
      );
    }
    if (_moreFailed) {
      return Column(
        children: [
          Text(
            s.cropMoreFailed,
            textAlign: TextAlign.center,
            style: AppText.small(context),
          ),
          EthmarLink(label: s.tryAgain, onTap: _retryMore),
        ],
      );
    }
    return null;
  }

  @override
  void dispose() {
    _categoryPages.dispose();
    super.dispose();
  }

  void _animate(PageController controller, int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(page);
    } else {
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // Runs when the user lands on a different category page
  void _onCategoryChanged(int i) {
    setState(() {
      _category = i;
      _swipedSideways = true;
    });
    final chip = _chipKeys[i].currentContext;
    if (chip != null) {
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conditions = widget.result.conditions;
    final showSwipeHint = !_swipedSideways && _groups.length > 1;
    final footer = _listFooter(S.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactHeader(conditions: conditions),
        const SizedBox(height: 10),
        Entrance(
          delay: const Duration(milliseconds: 150),
          child: _CategoryBar(
            groups: _groups,
            selected: _category,
            chipKeys: _chipKeys,
            onSelect: (i) => _animate(_categoryPages, i),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Entrance(
            delay: const Duration(milliseconds: 220),
            offset: 24,
            child: PageView.builder(
              controller: _categoryPages,
              itemCount: _groups.length,
              onPageChanged: _onCategoryChanged,
              itemBuilder: (context, i) => _PacketSlot(
                controller: _categoryPages,
                index: i,
                child: _CropList(
                  crops: _groups[i].crops,
                  footer: footer,
                  onEndReached: _loadMore,
                ),
              ),
            ),
          ),
        ),
        // One-time hint about swiping between categories. Takes no space
        // once it no longer applies.
        if (showSwipeHint)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              6,
              16,
              MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: Text(
              S.of(context).cropSwipeHint,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small(context),
            ),
          ),
      ],
    );
  }
}

/// The tickets of one category, one under the other, scrolling freely.
/// Kept alive so each category remembers where it was scrolled to.
class _CropList extends StatefulWidget {
  const _CropList({
    required this.crops,
    required this.onEndReached,
    this.footer,
  });
  final List<CropRecommendation> crops;

  /// Called when the user scrolls near the bottom, to load the next page.
  final VoidCallback onEndReached;

  /// The paging spinner or "Try again", under the last ticket.
  final Widget? footer;

  @override
  State<_CropList> createState() => _CropListState();
}

class _CropListState extends State<_CropList>
    with AutomaticKeepAliveClientMixin {
  static const _gap = 16.0;

  // Start the next page this far (in pixels) before the real end, so it is
  // usually there before the user gets to the bottom.
  static const _loadAhead = 600.0;

  @override
  bool get wantKeepAlive => true;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical &&
        n.metrics.extentAfter < _loadAhead) {
      widget.onEndReached();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final crops = widget.crops;
    final footer = widget.footer;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.separated(
        // Lets a short list be pulled too, so the user can reach its end.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 4,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        itemCount: crops.length + (footer == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: _gap),
        itemBuilder: (context, j) => j == crops.length
            ? footer!
            : Semantics(
                container: true,
                label: '${j + 1} / ${crops.length}',
                child: _SeedPacket(crop: crops[j]),
              ),
      ),
    );
  }
}

/// Category chips under the header: shows where you are sideways, and tapping one jumps there.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.groups,
    required this.selected,
    required this.chipKeys,
    required this.onSelect,
  });
  final List<_CategoryGroup> groups;
  final int selected;
  final List<GlobalKey> chipKeys;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (var i = 0; i < groups.length; i++)
            Padding(
              key: chipKeys[i],
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _CategoryTab(
                group: groups[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// One category button: its icon, its name, and how many crops it has.
/// White with a thin earthy border; the selected one gets a soft green
/// tint and a stronger border.
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.group,
    required this.selected,
    required this.onTap,
  });
  final _CategoryGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = group.category;
    const radius = BorderRadius.all(Radius.circular(14));
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.featureCard : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.earthBrown
                .withValues(alpha: selected ? 0.7 : 0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          // InkWell shows the ripple effect when tapped.
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              // Compact, but still an easy tap target.
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 10, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Image.asset(
                        _categoryIcon(cat),
                        width: 24,
                        height: 24,
                        cacheWidth: 96,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _categoryLabel(cat, context),
                      style: AppText.label(context).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // The small circle with the number of crops
                    if (group.crops.length > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.backgroundAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${group.crops.length}',
                          style: AppText.small(
                            context,
                            color: AppColors.earthBrown,
                          ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Short header
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.conditions});
  final GrowingConditions conditions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        MediaQuery.paddingOf(context).top + 4,
        24,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button on its own row at the top.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: EthmarBackButton(tooltip: s.back),
          ),
          const SizedBox(height: 6),
          // Title and subtitle on one side, Thamoor on the other (in front
          // of the hills in the background).
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Entrance(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.cropTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(context).copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.cropAccent,
                          style: AppText.accent(context, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Entrance(
                  delay: const Duration(milliseconds: 120),
                  child: EthmarCharacter(
                    name: _weatherCharacter(conditions),
                    height: 96,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: _ConditionsRow(conditions: conditions),
          ),
        ],
      ),
    );
  }
}

/// The area, this month, and this month's average temperatures, straight
/// on the background.
class _ConditionsRow extends StatelessWidget {
  const _ConditionsRow({required this.conditions});
  final GrowingConditions conditions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = conditions;
    final temps =
        '${String.fromCharCode(0x2066)}${c.tempLow}–${c.tempHigh}°C'
        '${String.fromCharCode(0x2069)}';
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        _Condition(icon: Icons.place_rounded, text: c.city.of(context)),
        _Condition(
          icon: Icons.calendar_month_rounded,
          text: s.monthName(c.month),
        ),
        _Condition(icon: Icons.thermostat_rounded, text: temps),
      ],
    );
  }
}


class _Condition extends StatelessWidget {
  const _Condition({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.forest),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppText.small(
            context,
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}


class _PacketSlot extends StatelessWidget {
  const _PacketSlot({
    required this.controller,
    required this.index,
    required this.child,
  });
  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final ready =
              controller.hasClients && controller.position.haveDimensions;
          final page = ready ? controller.page! : 0.0;
          final d = (page - index).abs().clamp(0.0, 1.0);
          return Opacity(
            opacity: 1 - 0.35 * d,
            child: reduce
                ? child
                : Transform.scale(scale: 1 - 0.07 * d, child: child),
          );
        },
      ),
    );
  }
}

/// One crop drawn as a ticket: a zig-zag top, a warm-white face, a dashed
/// line, then the care facts.
class _SeedPacket extends StatelessWidget {
  const _SeedPacket({required this.crop});
  final CropRecommendation crop;

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: const _PacketClipper(),
      clipBehavior: Clip.antiAlias,
      // Warm white: the category illustrations have a near-white
      // background, so they blend straight into the ticket.
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.earthBrown.withValues(alpha: 0.25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PacketFace(crop: crop),
          CustomPaint(
            size: const Size.fromHeight(2),
            painter: _PerforationPainter(
              AppColors.earthBrown.withValues(alpha: 0.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: _CareFacts(crop: crop),
          ),
        ],
      ),
    );
  }
}

/// The ticket's top: badges, crop name and reason on the start side, the
/// category illustration on the end side (mirrors in Arabic).
class _PacketFace extends StatelessWidget {
  const _PacketFace({required this.crop});
  final CropRecommendation crop;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final reason = crop.reason;
    return Stack(
      children: [
        // Soft earthy band along the zig-zag edge.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _PacketClipper.crimp + 8,
          child: ColoredBox(
            color: AppColors.earthBrown.withValues(alpha: 0.18),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            20,
            _PacketClipper.crimp + 18,
            12,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Badge 1: "Plant now" or "Plant in <month>".
                        _Badge(
                          icon: crop.plantNow
                              ? Icons.eco_rounded
                              : Icons.event_rounded,
                          text: crop.plantNow
                              ? s.cropPlantNow
                              : s.cropPlantIn(crop.plantMonth),
                          color: AppColors.forest,
                          background: AppColors.featureCard,
                        ),
                        // Badge 2: how well the crop matches the area.
                        _Badge(
                          text: s.cropBand(crop.band),
                          color: AppColors.earthBrown,
                          background: AppColors.backgroundAlt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      crop.name.of(context),
                      style: AppText.display(context).copyWith(fontSize: 30),
                    ),
                    // Why this crop was suggested
                    if (reason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.cropNote(reason),
                        style: AppText.accent(context, size: 17),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Image.asset(
                  _categoryPhoto(crop.category),
                  width: 120,
                  height: 120,
                  cacheWidth: 400,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One care fact
class _Fact {
  const _Fact(this.icon, this.label, this.value, {this.ltr = false});
  final IconData icon;
  final String label;
  final String value;
  final bool ltr;
}

class _CareFacts extends StatelessWidget {
  const _CareFacts({required this.crop});
  final CropRecommendation crop;

  /// "40–100 days", or one number when both ends are the same.
  static String _range(int min, int max) => min == max ? '$min' : '$min–$max';

  /// Height in metres: "12" for 10 or more, otherwise one decimal
  static String _meters(double m) => m >= 10
      ? m.round().toString()
      : m.toStringAsFixed(1).replaceAll('.0', '');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Read the crop's data. Some values can be missing (null or empty).
    final minTemp = crop.minTemp, maxTemp = crop.maxTemp;
    final water = s.cropWater(crop.waterNeed);
    final bestTime = s.monthRanges(crop.bestMonths);
    final harvest = crop.harvestDays;
    final height = crop.heightM;
    final tip = crop.tip;

    // Build the list of facts, skipping any the crop doesn't have.
    final facts = [
      if (minTemp != null && maxTemp != null)
        _Fact(
          Icons.thermostat_rounded,
          s.cropTempRange,
          '${_range(minTemp, maxTemp)}°C',
          ltr: true,
        ),
      if (water.isNotEmpty)
        _Fact(Icons.water_drop_rounded, s.cropWaterNeed, water),
      if (bestTime.isNotEmpty)
        _Fact(Icons.calendar_month_rounded, s.cropBestTime, bestTime),
      // A tree's growing cycle is its fruiting season, not the time until
      // its first harvest, so trees show their size instead.
      if (harvest != null && crop.category != CropCategory.fruit)
        _Fact(
          Icons.agriculture_rounded,
          s.cropHarvest,
          '${_range(harvest.min, harvest.max)} ${s.cropDays}',
        )
      else if (height != null && height > 0)
        _Fact(
          Icons.height_rounded,
          s.cropGrowsTo,
          '${_meters(height)} ${s.cropMeters}',
        ),
    ];


    // Puts two facts side by side. With only one, the right side stays empty.
    Widget pair(_Fact a, _Fact? b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _FactTile(fact: a)),
        const SizedBox(width: 14),
        Expanded(
          child: b == null ? const SizedBox.shrink() : _FactTile(fact: b),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < facts.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 16),
          pair(facts[i], i + 1 < facts.length ? facts[i + 1] : null),
        ],
        // The care tip, in a soft green box.
        if (tip != null) ...[
          const SizedBox(height: 16),
          _NoteLine(
            icon: Icons.lightbulb_rounded,
            text: s.cropNote(tip),
            color: AppColors.forest,
            background: AppColors.featureCard,
          ),
        ],
      ],
    );
  }
}

/// A small pill on the packet face, e.g. "Plant now" or "Great match".
class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.background,
    this.icon,
  });
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppText.small(
              context,
              color: color,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// One line of advice under the care facts.
class _NoteLine extends StatelessWidget {
  const _NoteLine({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.small(
                context,
                color: AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// One care fact: a round icon, a small label, and its value below.
class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});
  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    final f = fact;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.featureCard,
              shape: BoxShape.circle,
            ),
            child: Icon(f.icon, size: 18, color: AppColors.forest),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: AppText.small(context, color: AppColors.earthBrown)
                      .copyWith(fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  f.value,
                  // Keeps number ranges in the right order in Arabic.
                  textDirection: f.ltr ? TextDirection.ltr : null,
                  style: AppText.label(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Packet outline: a crimped (zig-zag) top edge and rounded bottom corners.
class _PacketClipper extends CustomClipper<Path> {
  const _PacketClipper();
  static const crimp = 7.0;
  static const _radius = 24.0;

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final teeth = (w / 14).round().clamp(1, 1000);
    final tooth = w / teeth;
    final p = Path()..moveTo(0, crimp);
    for (var i = 0; i < teeth; i++) {
      p
        ..lineTo(i * tooth + tooth / 2, 0)
        ..lineTo((i + 1) * tooth, crimp);
    }
    p
      ..lineTo(w, h - _radius)
      ..arcToPoint(
        Offset(w - _radius, h),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(_radius, h)
      ..arcToPoint(
        Offset(0, h - _radius),
        radius: const Radius.circular(_radius),
      )
      ..close();
    return p;
  }

  @override
  // The shape never changes
  bool shouldReclip(covariant _PacketClipper oldClipper) => false;
}

/// The dashed line between the packet face and its care facts.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0, gap = 5.0, inset = 16.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = inset; x < size.width - inset; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width - inset), y),
        paint,
      );
    }
  }

  @override
  // Only repaint when the colour changes.
  bool shouldRepaint(covariant _PerforationPainter old) => old.color != color;
}
