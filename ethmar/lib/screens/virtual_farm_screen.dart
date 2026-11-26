import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../services/sky_clock.dart';
import '../services/sun_times.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/system_bars.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/centered_header.dart';
import '../widgets/farm_sky.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'add_plant_screen.dart';
import 'my_plants_screen.dart';
import 'plant_details_screen.dart';

/// Virtual Farm: the user's lands drawn as 3D (isometric) blocks of grass
/// on soil, over a sky with hills ([FarmSky]). It shows day between the
/// user's sunrise and sunset, and night otherwise ([SkyClock]). Pinch or
/// use the buttons to zoom.
///
/// Each land holds 5 × 5 = 25 plants. New plants go in the next free square
/// automatically, row by row from the back corner. When every land is full,
/// a new land can be added next to them, up to 3 × 3 lands.
/// An empty farm asks the user to add their first plant.
/// The farm data comes from [FarmStore].
class VirtualFarmScreen extends StatefulWidget {
  const VirtualFarmScreen({super.key});

  /// "Pinch to Zoom" shows until the user zooms for the first time (by
  /// pinching or with + / −), and then never again, even after a restart.
  /// It is saved on this phone under this key.
  static const zoomHintDoneKey = 'farm_zoom_hint_done';

  /// For tests: forgets the saved value so it's read again.
  @visibleForTesting
  static void resetZoomHintForTests() =>
      _VirtualFarmScreenState._zoomLearned = null;

  @override
  State<VirtualFarmScreen> createState() => _VirtualFarmScreenState();
}

class _VirtualFarmScreenState extends State<VirtualFarmScreen>
    with SingleTickerProviderStateMixin {
  static const _minScale = 0.6;

  /// Text colour on the night sky: soft white.
  static const _onNight = Color(0xF2FFFFFF);

  /// How far you can zoom in when a single land fills the screen. With more
  /// lands each one is drawn smaller, so the limit grows to match.
  static const _maxZoomOneLand = 5.0;

  /// The order lands are added in, as (column, row): right of the first, in
  /// front of it, the corner between them, then out to 3 × 3.
  static const _landSpots = [
    (0, 0), (1, 0), (0, 1), (1, 1), //
    (2, 0), (2, 1), (0, 2), (1, 2), (2, 2),
  ];

  int get _landCount => FarmStore.lands.value;

  /// True once we know the user has no plants (not while loading).
  bool get _farmEmpty =>
      FarmStore.plantsLoaded.value && FarmStore.plants.value.isEmpty;

  /// The id of a plant added while this screen is open, so it can pop in.
  String? _newest;

  /// The plants already on the farm, to notice when a new one is added.
  Set<String?> _knownPlants = const {};

  final _view = TransformationController();
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )
    ..addListener(_onMove)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _checkButtonZoom();
    });
  Animation<Matrix4>? _moveTween;

  /// Size of the zoomable area from the last layout.
  Size _viewport = Size.zero;

  /// Day or night where the user is, for the sky behind the farm.
  final _sky = SkyClock.create();

  /// Whether the user has zoomed before (shared by all farm screens once
  /// read). Null until it's read, and the hint stays hidden until then.
  static bool? _zoomLearned;

  /// The zoom level when the current pinch or drag started.
  double _scaleAtStart = 1;

  @override
  void initState() {
    super.initState();
    _knownPlants = _plantIds();
    _sky.addListener(_farmChanged);
    if (_zoomLearned == null) _loadZoomHint();
    FarmStore.lands.addListener(_farmChanged);
    FarmStore.plantsLoaded.addListener(_farmChanged);
    FarmStore.plants.addListener(_plantsChanged);
  }

  @override
  void dispose() {
    FarmStore.lands.removeListener(_farmChanged);
    FarmStore.plantsLoaded.removeListener(_farmChanged);
    FarmStore.plants.removeListener(_plantsChanged);
    _sky.removeListener(_farmChanged);
    _sky.dispose();
    _move.dispose();
    _view.dispose();
    super.dispose();
  }

  void _farmChanged() => setState(() {});

  Set<String?> _plantIds() => {for (final p in FarmStore.plants.value) p.id};

  void _plantsChanged() {
    final ids = _plantIds();
    final added = ids.difference(_knownPlants);
    _knownPlants = ids;
    setState(() {
      // Several new plants at once means the farm is loading, not the user
      // adding a plant.
      if (added.length == 1) _newest = added.first;
    });
  }

  Future<void> _loadZoomHint() async {
    var learned = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      learned = prefs.getBool(VirtualFarmScreen.zoomHintDoneKey) ?? false;
    } catch (_) {
      // Can't read it, so show the hint.
    }
    // If the user zoomed while it was loading, it's already set.
    _zoomLearned ??= learned;
    if (mounted) setState(() {});
  }

  /// The user really zoomed, so hide the hint for good.
  void _zoomed() {
    if (_zoomLearned == true) return;
    setState(() => _zoomLearned = true);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(VirtualFarmScreen.zoomHintDoneKey, true))
        .catchError((Object _) => false);
  }

  /// True when two zoom levels are really different (not just rounding).
  static bool _scaleChanged(double a, double b) => (a - b).abs() > a * 0.01;

  void _onMove() {
    final tween = _moveTween;
    if (tween != null) _view.value = tween.value;
  }

  /// The zoom before a + or − press, until its animation ends. Null
  /// otherwise (recentering, pinching).
  double? _zoomFrom;

  /// After a + or − animation: if the zoom really changed (it may be held at
  /// a limit), the user has zoomed.
  void _checkButtonZoom() {
    final from = _zoomFrom;
    _zoomFrom = null;
    if (from != null && _scaleChanged(from, _view.value.getMaxScaleOnAxis())) {
      _zoomed();
    }
  }

  void _recenter() {
    _zoomFrom = null;
    _animateTo(Matrix4.identity());
  }

  void _animateTo(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _view.value = target;
      _checkButtonZoom();
      return;
    }
    _moveTween = Matrix4Tween(
      begin: _view.value,
      end: target,
    ).animate(CurvedAnimation(parent: _move, curve: Curves.easeOutCubic));
    _move.forward(from: 0);
  }

  /// The next spot where a land can be added. Null until every land is full
  /// (25 plants each), and when the farm is at its biggest size.
  ///
  /// TODO(backend): Test once plants are saved: fill a land (all 25
  ///   squares) → the "Add land" spot appears next to it; not full → it
  ///   doesn't. Then reopen the app: the lands and plants should still be
  ///   there.
  (int, int)? get _nextSpot =>
      FarmStore.landsFull && _landCount < _landSpots.length
      ? _landSpots[_landCount]
      : null;

  Future<void> _addLand() async {
    try {
      await FarmStore.addLand();
    } catch (_) {
      if (!mounted) return;
      showEthmarToast(
        context,
        S.of(context).farmSaveFailed,
        type: EthmarToastType.error,
      );
    }
  }

  double get _maxScale => _maxZoomOneLand * _zoomRoom;

  /// How much smaller one land is drawn now compared to when it's alone.
  double _zoomRoom = 1;

  /// Zooms around the middle of the screen, within the limits.
  void _zoomBy(double factor) {
    final current = _view.value.getMaxScaleOnAxis();
    final k = (current * factor).clamp(_minScale, _maxScale) / current;
    // At the limit nothing changes, so it doesn't count as zooming.
    if (!_scaleChanged(current, current * k)) return;
    _zoomFrom = current;
    final c = _viewport.center(Offset.zero);
    final zoom = Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.diagonal3Values(k, k, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0))
      ..multiply(_view.value);
    _animateTo(zoom);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Until the real day/night phase is known, use the normal day colours.
    final night = _sky.settled && _sky.value == SkyPhase.night;
    // On the night sky, use light status bar icons, title and hint. The
    // buttons are white and stay the same.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: night ? ethmarSystemBarsOnDark : ethmarSystemBars,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // The background stays still. Only the farm inside the InteractiveViewer
            // moves and zooms.
            Positioned.fill(child: FarmSky(phase: _sky.value, ready: _sky.settled)),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) {
                  _viewport = box.biggest;
                  // The farm fills almost the whole width, but is short enough to fit
                  // between the header and the buttons.
                  final fit = Size(box.maxWidth * 0.96, box.maxHeight * 0.9);
                  final lands = _landSpots.take(_landCount).toList();
                  final next = _nextSpot;
                  final layout = _FarmLayout(lands, next, fit);
                  final plants = FarmStore.plants.value;
                  _zoomRoom =
                      _FarmLayout([lands.first], null, fit).landWidth /
                      layout.landWidth;
                  return InteractiveViewer(
                    transformationController: _view,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    boundaryMargin: const EdgeInsets.all(240),
                    onInteractionStart: (_) {
                      _move.stop();
                      _zoomFrom = null;
                      _scaleAtStart = _view.value.getMaxScaleOnAxis();
                    },
                    // A pinch that changed the zoom counts; just moving around doesn't.
                    onInteractionEnd: (_) {
                      if (_scaleChanged(
                        _scaleAtStart,
                        _view.value.getMaxScaleOnAxis(),
                      )) {
                        _zoomed();
                      }
                    },
                    child: SizedBox.fromSize(
                      size: box.biggest,
                      child: Center(
                        child: Entrance(
                          delay: const Duration(milliseconds: 120),
                          offset: 24,
                          child: SizedBox.fromSize(
                            size: layout.size,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Semantics(
                                    image: true,
                                    label: s.farmLand,
                                    child: CustomPaint(
                                      painter: _FarmPainter(layout, plants),
                                    ),
                                  ),
                                ),
                                // Back squares first, so plants in front overlap the ones behind them.
                                for (final plant in layout.backToFront(plants))
                                  _PlacedPlant(
                                    key: ValueKey(plant.id),
                                    plant: plant,
                                    at: layout.squareMiddle(plant),
                                    squareWidth:
                                        layout.landWidth / _FarmLayout.cells,
                                    popIn: plant.id == _newest,
                                    onTap: () => Navigator.of(context).push(
                                      riseRoute(
                                        PlantDetailsScreen(plantId: plant.id!),
                                      ),
                                    ),
                                  ),
                                if (next != null)
                                  Positioned.fromRect(
                                    rect: Rect.fromCenter(
                                      center: layout.middleOf(next),
                                      width: layout.landWidth,
                                      height: layout.landWidth / 2,
                                    ),
                                    child: Center(
                                      child: _AddLandButton(
                                        onPressed: _addLand,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_farmEmpty)
              _EmptyFarmPrompt(
                onAddPlant: () => AddPlantScreen.open(context),
              ),
            Align(
              alignment: Alignment.topCenter,
              // A main tab: no back button.
              child: EthmarCenteredHeader(
                title: s.farmTitle,
                titleColor: night ? _onNight : null,
                // On the start side: right in Arabic, left in English. This is a main tab,
                // so there is no back button.
                leading: const _MyPlantsButton(),
                showBack: false,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_zoomLearned == false)
                              Text(
                                s.farmPinchHint,
                                style: AppText.small(
                                  context,
                                  color: night ? _onNight : null,
                                ),
                              ),
                            // The empty farm prompt has its own button.
                            if (!_farmEmpty) ...[
                              const SizedBox(height: 10),
                              _AddPlantButton(
                                onPressed: () =>
                                    AddPlantScreen.open(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ZoomControls(
                        onZoomIn: () => _zoomBy(1.4),
                        onZoomOut: () => _zoomBy(1 / 1.4),
                        onReset: _recenter,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown on a farm with no plants: says so and offers to add the first one.
class _EmptyFarmPrompt extends StatelessWidget {
  const _EmptyFarmPrompt({required this.onAddPlant});
  final VoidCallback onAddPlant;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Below the middle, so the land is still visible above it.
    return Align(
      alignment: const Alignment(0, 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Entrance(
            delay: const Duration(milliseconds: 200),
            child: Material(
              color: AppColors.surface,
              elevation: 3,
              shadowColor: AppColors.overlay,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.farmEmptyTitle,
                      textAlign: TextAlign.center,
                      style: AppText.title(context).copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.farmEmptyBody,
                      textAlign: TextAlign.center,
                      style: AppText.small(context),
                    ),
                    const SizedBox(height: 16),
                    EthmarButton(
                      label: s.farmEmptyAction,
                      onPressed: onAddPlant,
                    ),
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

/// The "My plants" button in the header corner: a white circle with a
/// potted plant and a list. Opens the list of the user's plants.
class _MyPlantsButton extends StatelessWidget {
  const _MyPlantsButton();

  /// The picture's box size. The drawing fills about 70% of its width.
  static const _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: S.of(context).myPlants,
        onPressed: () =>
            Navigator.of(context).push(riseRoute(const MyPlantsScreen())),
        // Less padding around the bigger picture, but still a 48 circle.
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(4),
        ),
        iconSize: _iconSize,
        // The drawing is a bit below the middle of the picture, so it's moved up
        // to be centred in the circle.
        icon: Transform.translate(
          offset: const Offset(0, -_iconSize * 0.046),
          child: Image.asset(
            'assets/images/my_plants_icon.png',
            width: _iconSize,
            height: _iconSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// The +, − and reset buttons, stacked in one white pill.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          icon: Icon(icon, color: AppColors.forest),
        );
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.forest.withValues(alpha: 0.3),
      shape: const StadiumBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add_rounded, s.farmZoomIn, onZoomIn),
          button(Icons.remove_rounded, s.farmZoomOut, onZoomOut),
          const SizedBox(
            width: 32,
            child: Divider(height: 1, color: AppColors.border),
          ),
          button(Icons.center_focus_strong_rounded, s.farmResetView, onReset),
        ],
      ),
    );
  }
}

/// One plant standing in its square: the crop's picture with its base in
/// the middle of the square. [popIn] makes it grow in (for the plant just
/// added). Tapping it opens the plant's details.
class _PlacedPlant extends StatelessWidget {
  const _PlacedPlant({
    super.key,
    required this.plant,
    required this.at,
    required this.squareWidth,
    required this.onTap,
    this.popIn = false,
  });
  final FarmPlant plant;
  final Offset at;
  final double squareWidth;
  final VoidCallback onTap;
  final bool popIn;

  @override
  Widget build(BuildContext context) {
    // Narrower than the square, so there's grass between plants. The pictures
    // are about 4:5.
    final width = squareWidth * 0.6;
    final height = width * 1.3;
    Widget picture = PlantPicture(
      plant.crop.image,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      cacheWidth: 200,
      filterQuality: FilterQuality.medium,
    );
    if (popIn) picture = _PopIn(child: picture);
    return Positioned(
      left: at.dx - width / 2,
      // The soil in the pictures is a little above their bottom edge.
      top: at.dy - height * 0.94,
      child: Semantics(
        label: plant.name,
        button: true,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: picture,
        ),
      ),
    );
  }
}

/// Grows its child up from the ground with a little bounce. It waits a
/// moment first, so it plays after the add-a-plant screen has closed.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child});
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      alignment: Alignment.bottomCenter,
      child: widget.child,
    );
  }
}

/// "+ Add plant": opens the add-a-plant steps. It looks like the "Add
/// Plant" pill on Home, but a bit taller.
class _AddPlantButton extends StatelessWidget {
  const _AddPlantButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: AppColors.overlay,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: const Color(0x22FFFFFF),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 22, 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 22,
                color: AppColors.onForest,
              ),
              const SizedBox(width: 8),
              Text(S.of(context).homeAddPlant, style: AppText.button(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+ Add land", on the empty spot where the next land will go. On a small
/// spot (big farm, zoomed out) it's just a round "+".
class _AddLandButton extends StatelessWidget {
  const _AddLandButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = S.of(context).farmAddLand;
    const plus = Icon(Icons.add_rounded, size: 18, color: AppColors.onForest);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 150;
        final button = Material(
          color: AppColors.forest,
          shape: compact ? const CircleBorder() : const StadiumBorder(),
          elevation: 3,
          shadowColor: AppColors.overlay,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: const Color(0x22FFFFFF),
            child: compact
                ? Semantics(
                    label: label,
                    button: true,
                    excludeSemantics: true,
                    child: const SizedBox.square(dimension: 36, child: plus),
                  )
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        plus,
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppText.button(context).copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        );
        return compact ? Tooltip(message: label, child: button) : button;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// The farm, drawn in isometric view. Each land is a block: a grass diamond
// on top, two side faces (grass with a wavy line into the soil), and a
// soft shadow underneath. Left faces are light, right faces are in shade.
// Lands touch each other, so together they look like one bigger field.
// ---------------------------------------------------------------------------

/// Where every land (and the empty "next" spot) is on the canvas, sized so
/// the whole farm fits in [fit].
class _FarmLayout {
  _FarmLayout(this.lands, this.next, Size fit) {
    final spots = [...lands, ?next];
    // On screen, a land at (column, row) moves right by (column − row) half
    // widths, and down by (column + row) quarter widths.
    final across = spots.map((s) => s.$1 - s.$2);
    final down = spots.map((s) => s.$1 + s.$2);
    _minAcross = across.reduce(math.min);
    _minDown = down.reduce(math.min);
    final widthInLands = (across.reduce(math.max) - _minAcross) / 2 + 1;
    final heightInLands =
        (down.reduce(math.max) - _minDown) / 4 + 0.5 + depth + _shadowRoom;
    landWidth = math.min(fit.width / widthInLands, fit.height / heightInLands);
    size = Size(widthInLands * landWidth, heightInLands * landWidth);
  }

  /// Squares on each side of a land, one plant each. The grid isn't drawn;
  /// it only tells the app where plants go.
  static const cells = FarmStore.squaresPerSide;

  /// The side thickness, as a part of a land's width.
  static const depth = 0.15;
  static const _shadowRoom = 0.08;

  /// (column, row) of each land, in the order they were added.
  final List<(int, int)> lands;

  /// Where the next land would go, or null when the farm is at full size.
  final (int, int)? next;

  late final double landWidth;
  late final Size size;
  late final int _minAcross;
  late final int _minDown;

  /// The top-left corner of the box around the land at [spot].
  Offset originOf((int, int) spot) => Offset(
    (spot.$1 - spot.$2 - _minAcross) * landWidth / 2,
    (spot.$1 + spot.$2 - _minDown) * landWidth / 4,
  );

  /// A point on a land's grass top: [u] goes from its back corner to its
  /// right corner, and [v] to its left corner (0 to 1).
  Offset pointOn((int, int) spot, double u, double v) =>
      originOf(spot) +
      Offset(landWidth / 2 + (u - v) * landWidth / 2, (u + v) * landWidth / 4);

  /// The middle of the land's grass top.
  Offset middleOf((int, int) spot) => pointOn(spot, 0.5, 0.5);

  /// Where [plant] grows: its land, and its square's row and column. Squares
  /// go row by row from the land's back corner.
  ({(int, int) land, int row, int col}) squareOf(FarmPlant plant) => (
    land: lands[plant.land],
    row: plant.square ~/ cells,
    col: plant.square % cells,
  );

  /// The middle of [plant]'s square.
  Offset squareMiddle(FarmPlant plant) {
    final s = squareOf(plant);
    return pointOn(s.land, (s.col + 0.5) / cells, (s.row + 0.5) / cells);
  }

  /// [plants] sorted from the back of the farm to the front, so drawing them
  /// in this order layers them correctly.
  List<FarmPlant> backToFront(List<FarmPlant> plants) {
    int depth(FarmPlant plant) {
      final s = squareOf(plant);
      return (s.land.$1 + s.land.$2) * cells + s.row + s.col;
    }

    return [...plants]..sort((a, b) => depth(a).compareTo(depth(b)));
  }

  bool hasLand((int, int) spot) => lands.contains(spot);
}

class _FarmPainter extends CustomPainter {
  const _FarmPainter(this.layout, this.plants);
  final _FarmLayout layout;

  /// Squares with a plant get a soft shadow under it.
  final List<FarmPlant> plants;

  static const _grassTop = Color(0xFFA9D57F);
  static const _grassLit = Color(0xFF97C86F);
  static const _grassShade = Color(0xFF7FB25C);
  static const _soilLit = Color(0xFF8C7A55);
  static const _soilShade = Color(0xFF6F6142);
  static const _tuft = Color(0xFF7DB257);

  @override
  void paint(Canvas canvas, Size size) {
    final w = layout.landWidth;
    final t = w * _FarmLayout.depth;

    // Shadows first, so no land's shadow falls on another land.
    for (final spot in layout.lands) {
      final o = layout.originOf(spot);
      canvas.drawOval(
        Rect.fromCenter(
          center: o + Offset(w / 2, w / 2 + t * 0.85),
          width: w * 0.92,
          height: w * 0.28,
        ),
        Paint()
          ..color = AppColors.forest.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Back lands first, so a land in front covers the sides of the one behind.
    final ordered = [...layout.lands]
      ..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));
    for (final spot in ordered) {
      _land(canvas, spot, w, t);
    }

    final square = w / _FarmLayout.cells;
    final shadow = Paint()
      ..color = AppColors.forest.withValues(alpha: 0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, square * 0.06);
    for (final plant in plants) {
      canvas.drawOval(
        Rect.fromCenter(
          center: layout.squareMiddle(plant),
          width: square * 0.45,
          height: square * 0.18,
        ),
        shadow,
      );
    }

    final next = layout.next;
    if (next != null) _emptySpot(canvas, next);
  }

  void _land(Canvas canvas, (int, int) spot, double w, double t) {
    final (col, row) = spot;
    Offset at(double u, double v) => layout.pointOn(spot, u, v);
    final top = at(0, 0), right = at(1, 0), bottom = at(1, 1), left = at(0, 1);

    // The wave runs along the whole edge of the farm, so it joins up between
    // lands.
    _side(
      canvas,
      left,
      bottom,
      t,
      _soilLit,
      _grassLit,
      col.toDouble(),
      col + 1.0,
      0,
    );
    _side(
      canvas,
      bottom,
      right,
      t,
      _soilShade,
      _grassShade,
      row + 1.0,
      row.toDouble(),
      1.7,
    );

    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(left.dx, left.dy)
        ..close(),
      Paint()..color = _grassTop,
    );

    // Small grass tufts, different on each land but the same every time. They
    // stay away from the middle of each square, where the plant stands.
    final rand = math.Random(7 + col * 31 + row * 17);
    final tuft = Paint()..color = _tuft;
    final k = w / 360;
    double fromMiddle(double x) => ((x * _FarmLayout.cells) % 1 - 0.5).abs();
    var placed = 0;
    while (placed < 120) {
      final u = 0.04 + rand.nextDouble() * 0.92;
      final v = 0.04 + rand.nextDouble() * 0.92;
      if (fromMiddle(u) < 0.3 && fromMiddle(v) < 0.3) continue;
      placed++;
      final p = at(u, v);
      for (final dx in const [-2.5, 0.0, 2.5]) {
        final h = (dx == 0 ? 7.0 : 5.0) * k;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx + (dx - 1.2) * k, p.dy)
            ..lineTo(p.dx + (dx + 1.2) * k, p.dy)
            ..lineTo(p.dx + dx * 1.4 * k, p.dy - h)
            ..close(),
          tuft,
        );
      }
    }

    // A light edge along the front sides, only where no other land touches.
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!layout.hasLand((col, row + 1))) canvas.drawLine(left, bottom, rim);
    if (!layout.hasLand((col + 1, row))) canvas.drawLine(bottom, right, rim);
  }

  /// One side face from [a] to [b]: soil, with a grass band on top whose
  /// bottom edge is wavy. [from] and [to] say where this face is along the
  /// farm's edge, so the wave continues onto the next land.
  void _side(
    Canvas canvas,
    Offset a,
    Offset b,
    double depth,
    Color soil,
    Color grass,
    double from,
    double to,
    double phase,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy + depth)
        ..lineTo(a.dx, a.dy + depth)
        ..close(),
      Paint()..color = soil,
    );

    final band = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    const steps = 40;
    for (var i = steps; i >= 0; i--) {
      final f = i / steps;
      final p = Offset.lerp(a, b, f)!;
      final along = from + (to - from) * f;
      final wave = math.sin(along * math.pi * 5 + phase) * depth * 0.07;
      band.lineTo(p.dx, p.dy + depth * 0.42 + wave);
    }
    band.close();
    canvas.drawPath(band, Paint()..color = grass);

    // A darker strip at the very bottom, like deeper soil.
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy + depth * 0.86)
        ..lineTo(b.dx, b.dy + depth * 0.86)
        ..lineTo(b.dx, b.dy + depth)
        ..lineTo(a.dx, a.dy + depth)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
  }

  /// The empty spot for the next land: a pale diamond with a dashed edge.
  void _emptySpot(Canvas canvas, (int, int) spot) {
    final outline = Path()
      ..addPolygon([
        layout.pointOn(spot, 0, 0),
        layout.pointOn(spot, 1, 0),
        layout.pointOn(spot, 1, 1),
        layout.pointOn(spot, 0, 1),
      ], true);
    canvas.drawPath(
      outline,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    final dash = Paint()
      ..color = AppColors.forest.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 7), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FarmPainter old) =>
      old.plants != plants ||
      old.layout.lands.length != layout.lands.length ||
      old.layout.landWidth != layout.landWidth ||
      old.layout.next != layout.next;
}
