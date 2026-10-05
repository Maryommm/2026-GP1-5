import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart';
import '../services/crop_recommendation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart';
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
// Results
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.result});
  final CropRecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final crops = result.crops;
    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        AuthHeader(
          title: s.cropTitle,
          accent: s.cropAccent,
          character: 'ethmar_buddy_watering',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Entrance(
            delay: const Duration(milliseconds: 150),
            child: _ConditionsStrip(conditions: result.conditions),
          ),
        ),
        for (var i = 0; i < crops.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Entrance(
              delay: Duration(milliseconds: 200 + 70 * i),
              child: _CropCard(crop: crops[i]),
            ),
          ),
      ],
    );
  }
}

class _ConditionsStrip extends StatelessWidget {
  const _ConditionsStrip({required this.conditions});
  final GrowingConditions conditions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = conditions;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(icon: Icons.place_rounded, text: c.city.of(context)),
        _Pill(
          icon: Icons.wb_sunny_rounded,
          text: '${c.temperature}°C · ${c.sky.of(context)}',
        ),
        _Pill(
          icon: Icons.water_drop_rounded,
          text: '${c.humidity}% ${s.cropHumidity}',
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.seaDark),
          const SizedBox(width: 6),
          Text(text, style: AppText.small(context, color: AppColors.forest)),
        ],
      ),
    );
  }
}

class _CropCard extends StatefulWidget {
  const _CropCard({required this.crop});
  final CropRecommendation crop;

  @override
  State<_CropCard> createState() => _CropCardState();
}

class _CropCardState extends State<_CropCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final crop = widget.crop;
    final cat = crop.category;
    const radius = BorderRadius.all(Radius.circular(20));

    return Semantics(
      button: true,
      expanded: _open,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: cat.color, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          splashColor: cat.tint,
          highlightColor: Colors.transparent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cat.tint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, color: cat.dark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop.name.of(context),
                              style: AppText.title(context)
                                  .copyWith(fontSize: 21),
                            ),
                            const SizedBox(height: 4),
                            _CategoryChip(category: cat),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.forest,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  if (_open) ...[
                    const SizedBox(height: 14),
                    Text(crop.reason.of(context), style: AppText.body(context)),
                    const SizedBox(height: 14),
                    _DetailGrid(
                      items: [
                        _Detail(
                          Icons.thermostat_rounded,
                          s.cropTempRange,
                          '${crop.minTemp}–${crop.maxTemp}°C',
                        ),
                        _Detail(
                          Icons.water_drop_rounded,
                          s.cropIrrigation,
                          crop.irrigation.of(context),
                        ),
                        _Detail(
                          Icons.calendar_month_rounded,
                          s.cropSeason,
                          crop.season.of(context),
                        ),
                        _Detail(
                          Icons.agriculture_rounded,
                          s.cropHarvest,
                          '${crop.daysToHarvest} ${s.cropDays}',
                        ),
                      ],
                      category: cat,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final CropCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: category.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category.label.of(context),
        style: AppText.small(
          context,
          color: category.dark,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _Detail {
  const _Detail(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

/// Two-column grid of small detail tiles.
class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items, required this.category});
  final List<_Detail> items;
  final CropCategory category;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final tileW = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final d in items)
              Container(
                width: tileW,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(d.icon, size: 16, color: category.dark),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small(context)
                                .copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(d.value, style: AppText.label(context)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
