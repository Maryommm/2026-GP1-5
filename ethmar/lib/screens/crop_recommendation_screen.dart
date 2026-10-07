import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart';
import '../services/crop_recommendation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';

class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  final _service = CropRecommendationService();
  late Future<CropRecommendationResult> _future = _service.recommend();

  void _retry() => setState(() => _future = _service.recommend());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LeafPrintBackground(
        child: FutureBuilder<CropRecommendationResult>(
          future: _future,
          builder: (context, snap) {
            final Widget child;
            if (snap.connectionState != ConnectionState.done) {
              child = const _LoadingView();
            } else if (snap.hasError || snap.data == null) {
              child = _ErrorView(onRetry: _retry);
            } else {
              child = _ResultsView(result: snap.data!);
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey(snap.connectionState),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> {
  int _step = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (t) {
      if (_step >= 2) return t.cancel();
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final steps = s.cropLoadingSteps;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                            color: AppColors.seaTint,
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
                        color: AppColors.sea,
                        backgroundColor: AppColors.seaTint,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
                    s.cropError,
                    textAlign: TextAlign.center,
                    style: AppText.body(context),
                  ),
                  const SizedBox(height: 24),
                  EthmarButton(label: s.tryAgain, onPressed: onRetry),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results: one seed packet per crop. Sideways = category, up/down = crop.
// ---------------------------------------------------------------------------

/// The weather character that matches today's sky (same art as Home).
String _weatherCharacter(GrowingConditions c) =>
    switch (c.sky.en.toLowerCase()) {
      'sunny' => 'ethmar_sunny_day_character',
      'cloudy' => 'ethmar_cloudy_day_character',
      'rainy' => 'ethmar_rainy_day_character',
      'windy' => 'ethmar_windy_day_character',
      'cold' => 'ethmar_cold_day_character',
      _ => 'ethmar_buddy_watering',
    };

/// The crops of one category, in the order the recommendation gave them.
class _CategoryGroup {
  _CategoryGroup(this.category);
  final CropCategory category;
  final crops = <CropRecommendation>[];
}

/// Groups crops by category. Categories keep the order of their first
/// (best) crop, so the strongest suggestion's category comes first.
List<_CategoryGroup> _groupByCategory(List<CropRecommendation> crops) {
  final groups = <CropCategory, _CategoryGroup>{};
  for (final crop in crops) {
    groups.putIfAbsent(crop.category, () => _CategoryGroup(crop.category))
        .crops
        .add(crop);
  }
  return groups.values.toList();
}

/// Swipe left/right between categories, up/down between the crops of the
/// category you're on.
class _ResultsView extends StatefulWidget {
  const _ResultsView({required this.result});
  final CropRecommendationResult result;

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  late final _groups = _groupByCategory(widget.result.crops);
  final _categoryPages = PageController(viewportFraction: 0.88);

  /// One up/down stack per category, so the arrow buttons can drive it.
  late final _stackKeys = [
    for (final _ in _groups) GlobalKey<_CropStackState>(),
  ];
  late final _cropIndex = List.filled(_groups.length, 0);
  late final _chipKeys = [for (final _ in _groups) GlobalKey()];

  int _category = 0;

  /// The sideways hint shows until the user changes category once.
  bool _swipedSideways = false;

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

  void _onCategoryChanged(int i) {
    setState(() {
      _category = i;
      _swipedSideways = true;
    });
    // Keep the active chip in view when the chip row is wider than the screen.
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
    final group = _groups[_category];
    final row = _cropIndex[_category];
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
                child: _groups[i].crops.length == 1
                    ? _SeedPacket(crop: _groups[i].crops.first)
                    : _CropStack(
                        key: _stackKeys[i],
                        crops: _groups[i].crops,
                        onCropChanged: (j) =>
                            setState(() => _cropIndex[i] = j),
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            MediaQuery.paddingOf(context).bottom + 8,
          ),
          child: _DeckStatus(
            index: row,
            count: group.crops.length,
            showSidewaysHint: !_swipedSideways && _groups.length > 1,
            onUp: row > 0
                ? () => _stackKeys[_category].currentState?.goTo(row - 1)
                : null,
            onDown: row < group.crops.length - 1
                ? () => _stackKeys[_category].currentState?.goTo(row + 1)
                : null,
          ),
        ),
      ],
    );
  }
}

class _CropStack extends StatefulWidget {
  const _CropStack({
    super.key,
    required this.crops,
    required this.onCropChanged,
  });
  final List<CropRecommendation> crops;
  final ValueChanged<int> onCropChanged;

  @override
  State<_CropStack> createState() => _CropStackState();
}

class _CropStackState extends State<_CropStack>
    with AutomaticKeepAliveClientMixin {
  static const _gap = 12.0;

  final _scroll = ScrollController();
  late final _itemKeys = [for (final _ in widget.crops) GlobalKey()];
  int _index = 0;

  /// Where each packet starts, measured after each frame. Sizes can't be
  /// read while Flutter is still laying out, and the scroll physics asks
  /// for these during layout.
  List<double> _offsets = const [];

  // Keeps the scroll position when this category is swiped off screen.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackIndex);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final offsets = <double>[];
    var y = 0.0;
    for (final key in _itemKeys) {
      offsets.add(y);
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) y += box.size.height;
    }
    _offsets = offsets;
  }

  void _trackIndex() {
    final pos = _scroll.position;
    final offsets = _offsets;
    if (offsets.isEmpty) return;
    var i = 0;
    while (i + 1 < offsets.length &&
        offsets[i + 1] <= pos.pixels + pos.viewportDimension * 0.35) {
      i++;
    }
    if (i == _index) return;
    _index = i;
    // The position can change during layout; tell the parent afterwards.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCropChanged(_index);
      });
    } else {
      widget.onCropChanged(i);
    }
  }

  void goTo(int i) {
    if (!_scroll.hasClients || i >= _offsets.length) return;
    final target = _offsets[i].clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    SchedulerBinding.instance.addPostFrameCallback(_measure);
    final crops = widget.crops;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        controller: _scroll,
        physics: _SnapToItems(() => _offsets),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < crops.length; j++)
              Padding(
                key: _itemKeys[j],
                padding: const EdgeInsets.only(bottom: _gap),
                child: Semantics(
                  container: true,
                  label: '${j + 1} / ${crops.length}',
                  child: _SeedPacket(crop: crops[j], scrollable: false),
                ),
              ),
            // Room so the last packet can also snap to the top.
            SizedBox(height: box.maxHeight * 0.5),
          ],
        ),
      ),
    );
  }
}

/// Snaps the list so a packet's top lines up with the top of the view.
/// A packet taller than the view (very large text) scrolls freely until
/// its end is on screen.
class _SnapToItems extends ScrollPhysics {
  const _SnapToItems(this.offsets, {super.parent});
  final List<double> Function() offsets;

  @override
  _SnapToItems applyTo(ScrollPhysics? ancestor) =>
      _SnapToItems(offsets, parent: buildParent(ancestor));

  double? _target(ScrollMetrics m, double velocity) {
    final o = offsets();
    if (o.isEmpty) return null;
    final p = m.pixels;
    var i = 0;
    while (i + 1 < o.length && o[i + 1] <= p) {
      i++;
    }
    final next = i + 1 < o.length ? o[i + 1] : m.maxScrollExtent;
    final tall = next - o[i] > m.viewportDimension;
    if (tall && p + m.viewportDimension < next) return null;
    final double t;
    if (velocity > 300) {
      t = next;
    } else if (velocity < -300) {
      t = o[i];
    } else {
      t = p - o[i] < (next - o[i]) / 2 ? o[i] : next;
    }
    return t.clamp(m.minScrollExtent, m.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _target(position, velocity);
    if (target == null) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

/// Category chips under the header: shows where you are sideways, and
/// tapping one jumps there.
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
    final fg = selected ? cat.dark : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? cat.tint : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? cat.color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 14, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The icon art sits in the middle of a wide transparent
                    // canvas, so draw it larger and let the empty margin
                    // spill outside the 28px slot.
                    ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 28,
                        child: OverflowBox(
                          maxWidth: 62,
                          maxHeight: 62,
                          child: Image.asset(
                            cat.iconImage,
                            width: 62,
                            height: 62,
                            cacheWidth: 200,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.label.of(context),
                      style: AppText.label(context, color: fg).copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (group.crops.length > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? cat.color : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${group.crops.length}',
                          style: AppText.small(
                            context,
                            color: selected
                                ? AppColors.onForest
                                : AppColors.forest,
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

/// Short header so the packet gets most of the screen: back + title on one
/// row, then the accent line and today's conditions beside the weather
/// character.
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
          Row(
            children: [
              EthmarBackButton(tooltip: s.back),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  s.cropTitle.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(context).copyWith(fontSize: 25),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Entrance(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.cropAccent,
                            style: AppText.accent(context, size: 18)),
                        const SizedBox(height: 8),
                        _ConditionsStrip(conditions: conditions),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Entrance(
                  delay: const Duration(milliseconds: 120),
                  child: EthmarCharacter(
                    name: _weatherCharacter(conditions),
                    height: 88,
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

/// Today's conditions on one quiet turquoise strip.
class _ConditionsStrip extends StatelessWidget {
  const _ConditionsStrip({required this.conditions});
  final GrowingConditions conditions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = conditions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.seaTint,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _Condition(icon: Icons.place_rounded, text: c.city.of(context)),
          _Condition(
            icon: Icons.wb_sunny_rounded,
            text: '${c.temperature}°C · ${c.sky.of(context)}',
          ),
          _Condition(
            icon: Icons.water_drop_rounded,
            text: '${c.humidity}% ${s.cropHumidity}',
          ),
        ],
      ),
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
        Icon(icon, size: 16, color: AppColors.seaDeep),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppText.small(context, color: AppColors.forest)
              .copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Scales and dims the packets beside the one in focus, so the deck reads
/// as one packet held up with the next one waiting.
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

/// One crop drawn as a seed packet: a crimped top, a short face in the
/// crop category's colour, and the care facts on the white strip below.
/// The packet is only as tall as its content and sits at the top of its
/// slot; it scrolls inside itself only when the text is set very large.
class _SeedPacket extends StatelessWidget {
  const _SeedPacket({required this.crop, this.scrollable = true});
  final CropRecommendation crop;

  /// False inside [_CropStack], which already scrolls.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final cat = crop.category;
    final packet = Padding(
      // Room for the shadow under the packet.
      padding: const EdgeInsets.only(bottom: 8),
      child: PhysicalShape(
        clipper: const _PacketClipper(),
        clipBehavior: Clip.antiAlias,
        color: AppColors.surface,
        elevation: 3,
        shadowColor: AppColors.forest.withValues(alpha: 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PacketFace(crop: crop),
            CustomPaint(
              size: const Size.fromHeight(2),
              painter: _PerforationPainter(cat.color.withValues(alpha: 0.55)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: _CareFacts(crop: crop),
            ),
          ],
        ),
      ),
    );
    if (!scrollable) return packet;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: packet,
    );
  }
}

/// The packet's coloured top, kept short: the oversized category art in
/// the end corner (cropped by the packet edge like printed packet art),
/// with the name and reason below it.
class _PacketFace extends StatelessWidget {
  const _PacketFace({required this.crop});
  final CropRecommendation crop;

  @override
  Widget build(BuildContext context) {
    final cat = crop.category;
    return ColoredBox(
      color: cat.tint,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Sealed band under the crimp, so the packet top reads clearly.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _PacketClipper.crimp + 12,
            child: ColoredBox(color: cat.color.withValues(alpha: 0.32)),
          ),
          // The category chips already name the category, so the packet
          // carries it only as colour and art.
          PositionedDirectional(
            end: -24,
            top: _PacketClipper.crimp + 4,
            child: ExcludeSemantics(
              child: Image.asset(
                cat.image,
                width: 170,
                height: 170,
                cacheWidth: 520,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              22,
              _PacketClipper.crimp + 64,
              22,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crop.name.of(context),
                  style: AppText.display(context).copyWith(fontSize: 32),
                ),
                const SizedBox(height: 4),
                Text(
                  crop.reason.of(context),
                  style: AppText.accent(context, color: cat.dark, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact {
  const _Fact(this.icon, this.label, this.value, {this.ltr = false});
  final IconData icon;
  final String label;
  final String value;

  /// Number ranges like "18–35°C" stay left-to-right in Arabic too.
  final bool ltr;
}

/// The four care facts in two columns, like the back of a seed packet.
class _CareFacts extends StatelessWidget {
  const _CareFacts({required this.crop});
  final CropRecommendation crop;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cat = crop.category;
    final facts = [
      _Fact(
        Icons.thermostat_rounded,
        s.cropTempRange,
        '${crop.minTemp}–${crop.maxTemp}°C',
        ltr: true,
      ),
      _Fact(
        Icons.water_drop_rounded,
        s.cropIrrigation,
        crop.irrigation.of(context),
      ),
      _Fact(
        Icons.calendar_month_rounded,
        s.cropSeason,
        crop.season.of(context),
      ),
      _Fact(
        Icons.agriculture_rounded,
        s.cropHarvest,
        '${crop.daysToHarvest} ${s.cropDays}',
      ),
    ];
    // Plain rows (not LayoutBuilder): the packet measures its intrinsic
    // height, which LayoutBuilder can't report.
    Widget pair(_Fact a, _Fact b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FactTile(fact: a, category: cat)),
            const SizedBox(width: 14),
            Expanded(child: _FactTile(fact: b, category: cat)),
          ],
        );
    return Column(
      children: [
        pair(facts[0], facts[1]),
        const SizedBox(height: 16),
        pair(facts[2], facts[3]),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact, required this.category});
  final _Fact fact;
  final CropCategory category;

  @override
  Widget build(BuildContext context) {
    final f = fact;
    final cat = category;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cat.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(f.icon, size: 18, color: cat.dark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: AppText.small(context).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  f.value,
                  textDirection: f.ltr ? TextDirection.ltr : null,
                  style: AppText.label(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the deck: in a category with several crops, "1 / 2 · Swipe up for
/// more" with up/down buttons; otherwise a one-time sideways hint.
class _DeckStatus extends StatelessWidget {
  const _DeckStatus({
    required this.index,
    required this.count,
    required this.showSidewaysHint,
    required this.onUp,
    required this.onDown,
  });
  final int index;
  final int count;
  final bool showSidewaysHint;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stacked = count > 1;
    final String text;
    if (stacked) {
      // Isolate keeps "1 / 2" in reading order inside Arabic text.
      final position = '${String.fromCharCode(0x2066)}${index + 1} / $count${String.fromCharCode(0x2069)}';
      text = onDown != null ? '$position · ${s.cropSwipeUp}' : position;
    } else {
      text = showSidewaysHint ? s.cropSwipeHint : '';
    }
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (stacked)
            _StepButton(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: s.cropPrev,
              onPressed: onUp,
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                text,
                key: ValueKey(text),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small(context),
              ),
            ),
          ),
          if (stacked)
            _StepButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: s.cropNext,
              onPressed: onDown,
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: AppColors.forestTint,
        foregroundColor: AppColors.forest,
        disabledBackgroundColor: AppColors.forestTint.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.textHint,
      ),
      icon: Icon(icon),
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
      ..arcToPoint(Offset(w - _radius, h),
          radius: const Radius.circular(_radius))
      ..lineTo(_radius, h)
      ..arcToPoint(Offset(0, h - _radius),
          radius: const Radius.circular(_radius))
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant _PacketClipper oldClipper) => false;
}

/// The dashed "tear here" line between the packet face and its care facts.
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
  bool shouldRepaint(covariant _PerforationPainter old) => old.color != color;
}
