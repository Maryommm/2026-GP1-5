import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart' show BiText;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';

/// "Near me" (AgriMap): nurseries and farm stores around the user.
///
/// Asks for location access first. Allowed: the map centres on the user and
/// shows the places as markers; tapping one opens a preview card.
/// Denied: the map stays empty and explains why GPS access is needed.
///
/// UI only for now: the permission prompt, the user's position, the map and
/// the places are all prototypes.
/// TODO(location): Ask for the real GPS permission and read the user's
///   current coordinates.
/// TODO(google-maps): Replace the drawn map with Google Maps, centred on the
///   user, and load the real nearby nurseries and farm stores.
class AgriMapScreen extends StatefulWidget {
  const AgriMapScreen({super.key});

  @override
  State<AgriMapScreen> createState() => _AgriMapScreenState();
}

enum _Status { asking, locating, ready, denied }

enum _Filter { all, nursery, store }

enum _PlaceType { nursery, store }

class _Place {
  const _Place(this.type, this.name, this.address, this.km, this.at);
  final _PlaceType type;
  final BiText name;
  final BiText address;

  /// Distance from the user, e.g. '1.2'.
  final String km;

  /// Where it sits on the drawn map.
  final Offset at;
}

/// Colours and icon for each kind of place (markers, chips and card).
({Color color, Color tint, IconData icon}) _look(_PlaceType type) =>
    switch (type) {
      _PlaceType.nursery => (
        color: AppColors.forest,
        tint: AppColors.forestTint,
        icon: Icons.local_florist_rounded,
      ),
      _PlaceType.store => (
        color: AppColors.coralDark,
        tint: AppColors.coralTint,
        icon: Icons.storefront_rounded,
      ),
    };

// The drawn map is a fixed canvas; the user stands in its middle.
const _mapSize = Size(1400, 1400);
const _userAt = Offset(700, 700);
const _land = Color(0xFFF1EBDF);

// TODO(google-maps): Prototype places, replaced by real nearby results.
const _places = [
  _Place(
    _PlaceType.nursery,
    BiText('Al Nakheel Nursery', 'مشتل النخيل'),
    BiText(
      'Prince Turki St, Al Nakheel, Riyadh',
      'شارع الأمير تركي، النخيل، الرياض',
    ),
    '0.8',
    Offset(560, 590),
  ),
  _Place(
    _PlaceType.nursery,
    BiText('Green Oasis Nursery', 'مشتل الواحة الخضراء'),
    BiText('Olaya St, Al Olaya, Riyadh', 'شارع العليا، العليا، الرياض'),
    '1.4',
    Offset(900, 520),
  ),
  _Place(
    _PlaceType.nursery,
    BiText('Al Rawdah Plant Nursery', 'مشتل الروضة للنباتات'),
    BiText('Abu Bakr Rd, Al Rawdah, Riyadh', 'طريق أبو بكر، الروضة، الرياض'),
    '2.1',
    Offset(820, 900),
  ),
  _Place(
    _PlaceType.store,
    BiText('Al Waha Farm Supplies', 'مستلزمات الواحة الزراعية'),
    BiText('King Fahd Rd, Al Muruj, Riyadh', 'طريق الملك فهد، المروج، الرياض'),
    '1.1',
    Offset(480, 820),
  ),
  _Place(
    _PlaceType.store,
    BiText('Seed & Soil Store', 'متجر البذور والتربة'),
    BiText(
      'Takhassusi St, Al Mohammadiyah, Riyadh',
      'شارع التخصصي، المحمدية، الرياض',
    ),
    '1.7',
    Offset(980, 760),
  ),
  _Place(
    _PlaceType.store,
    BiText('Harvest Tools Center', 'مركز أدوات الحصاد'),
    BiText(
      'Northern Ring Rd, Al Wadi, Riyadh',
      'الطريق الدائري الشمالي، الوادي، الرياض',
    ),
    '2.4',
    Offset(640, 1010),
  ),
];

class _AgriMapScreenState extends State<AgriMapScreen>
    with SingleTickerProviderStateMixin {
  /// Like the real OS permission, a "yes" is remembered, so the prompt
  /// isn't shown again this session.
  static bool _granted = false;

  _Status _status = _Status.asking;
  _Filter _filter = _Filter.all;
  _Place? _selected;
  Timer? _locateTimer;

  /// Size of the map area, kept from the last layout.
  Size _viewport = Size.zero;

  final _map = TransformationController();
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..addListener(_onMove);
  Animation<Matrix4>? _moveTween;

  @override
  void initState() {
    super.initState();
    if (_granted) {
      _locate();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askPermission());
    }
  }

  @override
  void dispose() {
    _locateTimer?.cancel();
    _move.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _askPermission() async {
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.overlay,
      builder: (_) => const _PermissionDialog(),
    );
    if (!mounted) return;
    if (allowed == true) {
      _granted = true;
      _locate();
    } else {
      setState(() => _status = _Status.denied);
    }
  }

  void _locate() {
    setState(() => _status = _Status.locating);
    _locateTimer = Timer(const Duration(milliseconds: 1200), () {
      _map.value = _centredOn(_userAt);
      setState(() => _status = _Status.ready);
    });
  }

  /// Moves the map so [point] sits in the middle of the screen.
  Matrix4 _centredOn(Offset point) => Matrix4.translationValues(
    _viewport.width / 2 - point.dx,
    _viewport.height / 2 - point.dy,
    0,
  );

  void _onMove() {
    final tween = _moveTween;
    if (tween != null) _map.value = tween.value;
  }

  void _recenter() {
    final target = _centredOn(_userAt);
    if (MediaQuery.disableAnimationsOf(context)) {
      _map.value = target;
      return;
    }
    _moveTween = Matrix4Tween(
      begin: _map.value,
      end: target,
    ).animate(CurvedAnimation(parent: _move, curve: Curves.easeOutCubic));
    _move.forward(from: 0);
  }

  bool _shows(_Place p) => switch (_filter) {
    _Filter.all => true,
    _Filter.nursery => p.type == _PlaceType.nursery,
    _Filter.store => p.type == _PlaceType.store,
  };

  void _setFilter(_Filter f) {
    setState(() {
      _filter = f;
      final selected = _selected;
      if (selected != null && !_shows(selected)) _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _status == _Status.ready;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                _viewport = box.biggest;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: ready
                      ? _buildMap()
                      // Empty map until (and unless) we know where the user is.
                      : const ColoredBox(
                          key: ValueKey('empty'),
                          color: _land,
                          child: SizedBox.expand(),
                        ),
                );
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _MapHeader(),
              if (ready)
                Entrance(
                  delay: const Duration(milliseconds: 150),
                  child: _FilterBar(selected: _filter, onSelect: _setFilter),
                ),
            ],
          ),
          if (_status == _Status.locating) const Center(child: _LocatingPill()),
          if (_status == _Status.denied)
            Center(child: _DeniedCard(onAllow: _askPermission)),
          if (ready)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _RecenterButton(onPressed: _recenter),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: _selected == null
                            ? const SizedBox.shrink()
                            : _PreviewCard(
                                key: ObjectKey(_selected),
                                place: _selected!,
                                onClose: () => setState(() => _selected = null),
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

  Widget _buildMap() {
    return InteractiveViewer(
      key: const ValueKey('map'),
      transformationController: _map,
      constrained: false,
      minScale: 0.6,
      maxScale: 2.5,
      onInteractionStart: (_) => _move.stop(),
      child: SizedBox.fromSize(
        size: _mapSize,
        child: Stack(
          children: [
            // Tapping the map itself closes the preview card.
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: const CustomPaint(painter: _MapPainter()),
              ),
            ),
            Positioned(
              left: _userAt.dx - 40,
              top: _userAt.dy - 40,
              child: const _UserDot(),
            ),
            for (final place in _places)
              if (_shows(place))
                Positioned(
                  left: place.at.dx - 24,
                  top: place.at.dy - 56,
                  child: _Marker(
                    place: place,
                    selected: identical(place, _selected),
                    onTap: () => setState(() => _selected = place),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header and filters
// ---------------------------------------------------------------------------

/// Soft green header (same style as the chat): back, title and accent line,
/// and the Ethmar buddy carrying a crate.
class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        12,
        10,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.homeNearMe,
                  style: AppText.title(context).copyWith(fontSize: 24),
                ),
                Text(s.mapAccent, style: AppText.accent(context, size: 16)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const EthmarCharacter(name: 'ethmar_buddy_crate', height: 76),
        ],
      ),
    );
  }
}

/// All / Nurseries / Farm stores. The type chips carry the marker colour,
/// so they double as the map's legend.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final _Filter selected;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _FilterChip(
            label: s.mapFilterAll,
            selected: selected == _Filter.all,
            onTap: () => onSelect(_Filter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: s.mapFilterNurseries,
            type: _PlaceType.nursery,
            selected: selected == _Filter.nursery,
            onTap: () => onSelect(_Filter.nursery),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: s.mapFilterStores,
            type: _PlaceType.store,
            selected: selected == _Filter.store,
            onTap: () => onSelect(_Filter.store),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.type,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _PlaceType? type;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onForest : AppColors.forest;
    final t = type;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.forest : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.forest : AppColors.border,
          ),
        ),
        elevation: 2,
        shadowColor: AppColors.forest.withValues(alpha: 0.25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                t == null ? 16 : 6,
                0,
                16,
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _look(t).color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(_look(t).icon, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppText.label(
                      context,
                      color: fg,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map pieces: markers, the user's dot, and the drawn streets.
// ---------------------------------------------------------------------------

/// A round pin with the place's icon. Grows a little when selected.
class _Marker extends StatelessWidget {
  const _Marker({
    required this.place,
    required this.selected,
    required this.onTap,
  });
  final _Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = _look(place.type);
    return Semantics(
      button: true,
      selected: selected,
      label: place.name.of(context),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 56,
          child: AnimatedScale(
            scale: selected ? 1.25 : 1,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: look.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(look.icon, size: 20, color: Colors.white),
                ),
                CustomPaint(
                  size: const Size(12, 8),
                  painter: _PinTip(look.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small point under a marker.
class _PinTip extends CustomPainter {
  const _PinTip(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinTip old) => old.color != color;
}

/// Turquoise "you are here" dot with a soft pulse around it.
class _UserDot extends StatefulWidget {
  const _UserDot();

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.4;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context).mapYouAreHere,
      child: SizedBox.square(
        dimension: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final v = Curves.easeOut.transform(_c.value);
                return Container(
                  width: 24 + 56 * v,
                  height: 24 + 56 * v,
                  decoration: BoxDecoration(
                    color: AppColors.sea.withValues(alpha: 0.35 * (1 - v)),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.sea,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.seaDeep.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A calm, made-up neighbourhood: sand blocks, white streets, warm main
/// roads, green parks and a turquoise wadi.
class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _land);

    final park = Paint()..color = const Color(0xFFD7E8CF);
    for (final r in const [
      Rect.fromLTWH(400, 460, 110, 90),
      Rect.fromLTWH(1090, 190, 230, 120),
      Rect.fromLTWH(150, 990, 210, 230),
      Rect.fromLTWH(720, 1100, 300, 120),
      Rect.fromLTWH(880, 590, 160, 90),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(22)),
        park,
      );
    }

    final wadi = Path()
      ..moveTo(-40, 250)
      ..cubicTo(300, 380, 420, 150, 760, 290)
      ..cubicTo(1050, 410, 1150, 120, 1440, 170);
    canvas.drawPath(
      wadi,
      Paint()
        ..color = AppColors.seaTint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round,
    );

    void road(Offset a, Offset b, double width, Color fill) {
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = AppColors.border
            ..strokeWidth = width + 3,
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..color = fill
            ..strokeWidth = width,
        );
    }

    final w = size.width, h = size.height;
    for (final y in const [120.0, 330.0, 570.0, 700.0, 830.0, 1090.0, 1250.0]) {
      road(Offset(0, y), Offset(w, y), 12, Colors.white);
    }
    for (final x in const [140.0, 260.0, 540.0, 700.0, 860.0, 1200.0, 1310.0]) {
      road(Offset(x, 0), Offset(x, h), 12, Colors.white);
    }
    // Main roads on top.
    road(Offset(0, 440), Offset(w, 440), 24, AppColors.sunTint);
    road(Offset(0, 960), Offset(w, 960), 24, AppColors.sunTint);
    road(const Offset(380, 0), Offset(380, h), 24, AppColors.sunTint);
    road(const Offset(1060, 0), Offset(1060, h), 24, AppColors.sunTint);
    road(Offset(0, h - 80), Offset(w, 520), 20, AppColors.sunTint);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Overlays: recenter, preview card, locating, denied, permission prompt.
// ---------------------------------------------------------------------------

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.forest.withValues(alpha: 0.3),
      child: IconButton(
        tooltip: S.of(context).mapRecenter,
        onPressed: onPressed,
        style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        icon: const Icon(Icons.my_location_rounded, color: AppColors.forest),
      ),
    );
  }
}

/// Shown after tapping a marker: what the place is, its name, address and
/// how far it is.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({super.key, required this.place, required this.onClose});
  final _Place place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final look = _look(place.type);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 4, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: look.tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(look.icon, size: 28, color: look.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.type == _PlaceType.nursery ? s.mapNursery : s.mapStore,
                  style: AppText.small(
                    context,
                    color: look.color,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  place.name.of(context),
                  style: AppText.label(context)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        place.address.of(context),
                        style: AppText.small(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: AppColors.seaTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 14,
                        color: AppColors.seaDeep,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.mapKm(place.km),
                        style: AppText.small(
                          context,
                          color: AppColors.seaDeep,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.close,
            onPressed: onClose,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocatingPill extends StatelessWidget {
  const _LocatingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.sea,
            ),
          ),
          const SizedBox(width: 12),
          Text(S.of(context).mapLocating, style: AppText.label(context)),
        ],
      ),
    );
  }
}

/// Location denied: explains why GPS is needed; the map stays empty.
class _DeniedCard extends StatelessWidget {
  const _DeniedCard({required this.onAllow});
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Entrance(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.coralTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 36,
                color: AppColors.coralDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.mapDeniedTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.mapDeniedBody,
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 20),
            EthmarButton(label: s.mapAllowLocation, onPressed: onAllow),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the system's location prompt.
/// TODO(location): Show the real OS permission request instead.
class _PermissionDialog extends StatelessWidget {
  const _PermissionDialog();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.seaTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 40,
                  color: AppColors.seaDeep,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.mapPermissionTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.mapPermissionBody,
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 24),
            EthmarButton(
              label: s.mapAllow,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.mapDontAllow,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
