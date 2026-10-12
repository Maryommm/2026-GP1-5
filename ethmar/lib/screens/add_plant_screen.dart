import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_catalog.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/care_schedule_editor.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';

/// "Add a plant", in two steps:
///  1. Choose the crop (filter by type, tap a card).
///  2. Name it and, if wanted, set the irrigation and fertilization
///     schedules.
/// A summary dialog confirms; then the plant goes on the farm (in the next
/// free square) and the screen pops with it. Pops with nothing if the user
/// leaves.
///
/// Open it with [open], which first checks there's a free square.
class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  /// Opens the steps, or explains that the land is full. Returns the added
  /// plant, if any.
  static Future<FarmPlant?> open(BuildContext context) async {
    if (FarmStore.landsFull) {
      showEthmarToast(
        context,
        S.of(context).farmLandFull,
        icon: Icons.info_rounded,
      );
      return null;
    }
    final plant = await Navigator.of(context)
        .push<FarmPlant>(riseRoute(const AddPlantScreen()));
    if (plant != null && context.mounted) {
      showEthmarToast(context, S.of(context).plantAdded(plant.name));
    }
    return plant;
  }

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  int _step = 0;

  /// Crop type shown in step 1, or null for all.
  CropCategory? _filter;
  CatalogCrop? _crop;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _irrigation = ScheduleDraft(
    Repeat.everyDay,
    const TimeOfDay(hour: 7, minute: 0),
  );
  final _fertilization = ScheduleDraft(
    Repeat.everyWeek,
    const TimeOfDay(hour: 8, minute: 0),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _choose(CatalogCrop crop) {
    setState(() {
      // Start from the crop's name; keep the user's own name if they come
      // back for the same crop.
      if (crop != _crop) _name.text = crop.name.of(context);
      _crop = crop;
      _step = 1;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final plant = FarmPlant(
      crop: _crop!,
      name: _name.text.trim(),
      irrigation: _irrigation.result,
      fertilization: _fertilization.result,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => _SummaryDialog(plant: plant),
    );
    if (confirmed != true || !mounted) return;
    FarmStore.addPlant(plant);
    Navigator.of(context).pop(plant);
  }

  @override
  Widget build(BuildContext context) {
    // In step 2, "back" returns to step 1 instead of leaving.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        body: LeafPrintBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(step: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: _step == 0
                      ? KeyedSubtree(
                          key: const ValueKey(0),
                          child: _buildChooseStep(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey(1),
                          child: _buildDetailsStep(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step 1: choose the crop
  // -------------------------------------------------------------------------

  Widget _buildChooseStep() {
    final s = S.of(context);
    // In the crop list's order (vegetables, fruits, herbs, grains), and only
    // types that have crops.
    final categories = <CropCategory>{
      for (final crop in cropCatalog) crop.category,
    };
    final crops = _filter == null
        ? cropCatalog
        : cropCatalog.where((c) => c.category == _filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              _FilterChip(
                label: s.filterAll,
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final c in categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _FilterChip(
                    label: c.label.of(context),
                    category: c,
                    selected: _filter == c,
                    onTap: () => setState(() => _filter = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: crops.length,
            itemBuilder: (context, i) =>
                _CropCard(crop: crops[i], onTap: () => _choose(crops[i])),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Step 2: name and schedules
  // -------------------------------------------------------------------------

  Widget _buildDetailsStep() {
    final s = S.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                _ChosenCrop(
                  crop: _crop!,
                  onChange: () => setState(() => _step = 0),
                ),
                const SizedBox(height: 20),
                EthmarTextField(
                  label: s.addPlantNameLabel,
                  hint: s.addPlantNameHint,
                  controller: _name,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final name = v?.trim() ?? '';
                    if (name.isEmpty) return s.errPlantNameRequired;
                    if (name.length > 30) return s.errPlantNameLong;
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CareScheduleCard(
                  irrigation: _irrigation,
                  fertilization: _fertilization,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 10),
                Text(
                  s.addPlantLaterHint,
                  textAlign: TextAlign.center,
                  style: AppText.small(context),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: EthmarButton(label: s.addPlantButton, onPressed: _submit),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: back, title, which step, and a two-part progress bar.
// ---------------------------------------------------------------------------

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      s.addPlantTitle,
                      style: AppText.title(context).copyWith(fontSize: 24),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        '${s.addPlantStep(step + 1)} · '
                        '${step == 0 ? s.addPlantChoose : s.addPlantDetails}',
                        key: ValueKey(step),
                        style: AppText.small(
                          context,
                          color: AppColors.forest,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.forest
                          : AppColors.forest.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 pieces
// ---------------------------------------------------------------------------

/// Crop type filter, same look as the categories on "What to plant?".
/// Without a [category] it's the "All" chip.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.category,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final CropCategory? category;

  @override
  Widget build(BuildContext context) {
    final c = category;
    final accent = c?.color ?? AppColors.forest;
    final tint = c?.tint ?? AppColors.forestTint;
    final fg = selected
        ? (c?.dark ?? AppColors.forest)
        : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? tint : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? accent : AppColors.border,
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
                padding: EdgeInsetsDirectional.fromSTEB(
                  c == null ? 18 : 12,
                  0,
                  16,
                  0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c != null) ...[
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
                              c.iconImage,
                              width: 62,
                              height: 62,
                              cacheWidth: 200,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppText.label(context, color: fg).copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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

/// Square card: the crop's picture on its type's soft colour, name below.
class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop, required this.onTap});
  final CatalogCrop crop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = crop.name.of(context);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: crop.category.tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      crop.image,
                      fit: BoxFit.contain,
                      cacheWidth: 320,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.label(context)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 pieces
// ---------------------------------------------------------------------------

/// The crop picked in step 1, with a link back to change it.
class _ChosenCrop extends StatelessWidget {
  const _ChosenCrop({required this.crop, required this.onChange});
  final CatalogCrop crop;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final cat = crop.category;
    return Entrance(
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cat.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(crop.image, cacheWidth: 200),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.label.of(context),
                    style: AppText.small(
                      context,
                      color: cat.dark,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    crop.name.of(context),
                    style: AppText.label(context)
                        .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            EthmarLink(label: S.of(context).addPlantChange, onTap: onChange),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary dialog: confirm, or go back and change something.
// ---------------------------------------------------------------------------

class _SummaryDialog extends StatelessWidget {
  const _SummaryDialog({required this.plant});
  final FarmPlant plant;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loc = MaterialLocalizations.of(context);
    final crop = plant.crop;
    final cat = crop.category;
    String describe(CareSchedule? c) => c == null
        ? s.summaryNotSet
        : s.summaryAt(c.repeat.label(s), loc.formatTimeOfDay(c.time));
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cat.tint,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(crop.image, cacheWidth: 300),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.summaryTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.forestTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.name,
                          style: AppText.label(
                            context,
                          ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        // The crop, unless the name already says it.
                        if (plant.name != crop.name.of(context))
                          Text(
                            crop.name.of(context),
                            style: AppText.small(context),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cat.tint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.label.of(context),
                      style: AppText.small(
                        context,
                        color: cat.dark,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.water_drop_rounded,
              label: s.summaryIrrigation,
              value: describe(plant.irrigation),
              set: plant.irrigation != null,
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              icon: Icons.spa_rounded,
              label: s.summaryFertilization,
              value: describe(plant.fertilization),
              set: plant.fertilization != null,
            ),
            const SizedBox(height: 22),
            EthmarButton(
              label: s.confirm,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.back,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.set,
  });
  final IconData icon;
  final String label;
  final String value;

  /// False shows the "not set yet" value in a quieter colour.
  final bool set;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.seaTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.seaDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.small(context)),
                Text(
                  value,
                  style:
                      AppText.label(
                        context,
                        color: set ? AppColors.forest : AppColors.textSecondary,
                      ).copyWith(
                        fontWeight: set ? FontWeight.w600 : FontWeight.w400,
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
