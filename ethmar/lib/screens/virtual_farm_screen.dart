import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';

/// Virtual Farm: the user's lands as 3D (isometric) blocks of grass on
/// soil, floating on a soft sky. Pinch or use the buttons to zoom.
///
/// Each land holds 8 × 8 = 64 crops. When it's full, a new land can be added
/// next to it, growing the farm up to 3 × 3 lands.
///
/// The lands are empty for now; crops will be placed on their grids later.
/// TODO(farm-plants): Draw the user's plants on the lands' grid cells.
class VirtualFarmScreen extends StatefulWidget {
  const VirtualFarmScreen({super.key});

  @override
  State<VirtualFarmScreen> createState() => _VirtualFarmScreenState();
}

class _VirtualFarmScreenState extends State<VirtualFarmScreen>
    with SingleTickerProviderStateMixin {
  static const _minScale = 0.6;

  /// How far in you can zoom on a single land filling the screen. With more
  /// lands each one is drawn smaller, so the limit grows to match.
  static const _maxZoomOneLand = 5.0;

  /// The order lands are added in, as (column, row) on the farm: right of
  /// the first, in front of it, the corner between, then out to 3 × 3.
  static const _landSpots = [
    (0, 0), (1, 0), (0, 1), (1, 1), //
    (2, 0), (2, 1), (0, 2), (1, 2), (2, 2),
  ];

  // TODO(backend): Load how many lands the user has from the database.
  //   Prototype: starts with one land; "Add land" adds more on this screen
  //   only (they're gone when it's reopened).
  int _landCount = 1;

  final _view = TransformationController();
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_onMove);
  Animation<Matrix4>? _moveTween;

  /// Size of the zoomable area, kept from the last layout.
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _move.dispose();
    _view.dispose();
    super.dispose();
  }

  void _onMove() {
    final tween = _moveTween;
    if (tween != null) _view.value = tween.value;
  }

  void _animateTo(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _view.value = target;
      return;
    }
    _moveTween = Matrix4Tween(
      begin: _view.value,
      end: target,
    ).animate(CurvedAnimation(parent: _move, curve: Curves.easeOutCubic));
    _move.forward(from: 0);
  }

  /// Crops planted across all the user's lands.
  ///
  /// TODO(backend): Count the user's planted crops from the database.
  ///   Prototype: no crops yet, so the lands are never full.
  int get _plantedCount => 0;

  /// True when every square on every land has a crop (64 per land).
  bool get _landsFull =>
      _plantedCount >= _landCount * _FarmLayout.cells * _FarmLayout.cells;

  /// The next spot a land can be added in. Null until the lands are full,
  /// and once the farm is at its biggest.
  ///
  /// TODO(backend): Test once crops are saved: fill a land (all 64 squares)
  ///   → the "Add land" spot appears next to it; not full → it doesn't.
  ///   To try the design without the backend, make [_plantedCount] return
  ///   64 * [_landCount].
  (int, int)? get _nextSpot => _landsFull && _landCount < _landSpots.length
      ? _landSpots[_landCount]
      : null;

  void _addLand() {
    // TODO(backend): Save the new land for the user, then show it.
    setState(() => _landCount++);
  }

  double get _maxScale => _maxZoomOneLand * _zoomRoom;

  /// How much smaller one land is drawn now than when it's alone.
  double _zoomRoom = 1;

  /// Zooms around the middle of the screen, staying within the limits.
  void _zoomBy(double factor) {
    final current = _view.value.getMaxScaleOnAxis();
    final k = (current * factor).clamp(_minScale, _maxScale) / current;
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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.seaTint, AppColors.background],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) {
                  _viewport = box.biggest;
                  // The farm fills almost the whole width, but stays short
                  // enough to fit between the header and the buttons.
                  final fit = Size(box.maxWidth * 0.96, box.maxHeight * 0.9);
                  final lands = _landSpots.take(_landCount).toList();
                  final next = _nextSpot;
                  final layout = _FarmLayout(lands, next, fit);
                  _zoomRoom =
                      _FarmLayout([lands.first], null, fit).landWidth /
                      layout.landWidth;
                  return InteractiveViewer(
                    transformationController: _view,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    boundaryMargin: const EdgeInsets.all(240),
                    onInteractionStart: (_) => _move.stop(),
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
                                      painter: _FarmPainter(layout),
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
            const Align(alignment: Alignment.topCenter, child: _FarmHeader()),
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
                        child: Text(
                          s.farmPinchHint,
                          style: AppText.small(context),
                        ),
                      ),
                      _ZoomControls(
                        onZoomIn: () => _zoomBy(1.4),
                        onZoomOut: () => _zoomBy(1 / 1.4),
                        onReset: () => _animateTo(Matrix4.identity()),
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

/// Soft green header (same style as the chat and map): back, title and
/// the hand-written line.
class _FarmHeader extends StatelessWidget {
  const _FarmHeader();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: s.back,
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.farmTitle,
                  style: AppText.title(context).copyWith(fontSize: 24),
                ),
                Text(s.farmAccent, style: AppText.accent(context, size: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// +, − and reset, stacked in one white pill.
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

/// "+ Add land", sitting on the empty spot where the next land will go.
/// On a small spot (a big farm, zoomed out) it's just a round "+".
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
// on top, two side faces (grass edge with a wavy line into the soil), and a
// soft shadow underneath. Left faces are lit, right faces are in shade.
// Lands sit edge to edge, so together they read as one bigger field.
// ---------------------------------------------------------------------------

/// Where every land (and the empty "next" spot) sits on the canvas, sized so
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

  /// Squares per side of a land: 8 × 8 = 64, one crop each. The grid isn't
  /// drawn; it only tells the app where crops go.
  static const cells = 8;

  /// Side thickness, as a part of a land's width.
  static const depth = 0.15;
  static const _shadowRoom = 0.08;

  /// (column, row) of each land, in the order they were added.
  final List<(int, int)> lands;

  /// Where the next land would go, or null when the farm is full size.
  final (int, int)? next;

  late final double landWidth;
  late final Size size;
  late final int _minAcross;
  late final int _minDown;

  /// Top-left of the box around the land at [spot].
  Offset originOf((int, int) spot) => Offset(
    (spot.$1 - spot.$2 - _minAcross) * landWidth / 2,
    (spot.$1 + spot.$2 - _minDown) * landWidth / 4,
  );

  /// A point on a land's grass top: [u] runs from its back corner to its
  /// right corner, [v] to its left corner (0..1).
  Offset pointOn((int, int) spot, double u, double v) =>
      originOf(spot) +
      Offset(landWidth / 2 + (u - v) * landWidth / 2, (u + v) * landWidth / 4);

  /// Middle of the land's grass top.
  Offset middleOf((int, int) spot) => pointOn(spot, 0.5, 0.5);

  bool hasLand((int, int) spot) => lands.contains(spot);
}

class _FarmPainter extends CustomPainter {
  const _FarmPainter(this.layout);
  final _FarmLayout layout;

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

    // Back lands first: a land in front covers the sides of the one behind.
    final ordered = [...layout.lands]
      ..sort((a, b) => (a.$1 + a.$2).compareTo(b.$1 + b.$2));
    for (final spot in ordered) {
      _land(canvas, spot, w, t);
    }

    final next = layout.next;
    if (next != null) _emptySpot(canvas, next);
  }

  void _land(Canvas canvas, (int, int) spot, double w, double t) {
    final (col, row) = spot;
    Offset at(double u, double v) => layout.pointOn(spot, u, v);
    final top = at(0, 0), right = at(1, 0), bottom = at(1, 1), left = at(0, 1);

    // The wave runs along the whole farm edge, so it joins up between lands.
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

    // Little grass tufts, different on each land but the same every time.
    // They keep away from the middle of each grid square, where that
    // square's crop will stand.
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

    // Light rim along the front edges, only where no land joins on.
    final rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!layout.hasLand((col, row + 1))) canvas.drawLine(left, bottom, rim);
    if (!layout.hasLand((col + 1, row))) canvas.drawLine(bottom, right, rim);
  }

  /// One side face from [a] to [b]: soil, with a grass band on top whose
  /// lower edge waves like the example. [from] and [to] say where this face
  /// sits along the farm's edge, so the wave continues onto the next land.
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

    // Darker strip at the very bottom, like deeper earth.
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
      old.layout.lands.length != layout.lands.length ||
      old.layout.landWidth != layout.landWidth ||
      old.layout.next != layout.next;
}
