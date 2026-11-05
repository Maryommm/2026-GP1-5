import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_catalog.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../services/plant_service.dart' show FarmFullException;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/care_schedule_editor.dart';
import '../widgets/category_chip.dart';
import '../widgets/centered_header.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';

/// "Add a plant", in two steps: (screens)
///  1. Choose the crop
///  2. Name it and, if wanted, set the irrigation and fertilization schedules.
class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  /// Returns the added plant, if any.
  static Future<FarmPlant?> open(BuildContext context) async {
    if (FarmStore.landsFull) {
      showEthmarToast(
        context,
        S.of(context).farmLandFull,
        type: EthmarToastType.info,
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
  bool _saving = false;
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
      //keep the user's own name if they come back for the same crop.
      // An unknown plant has no name to suggest: the user types their own.
      if (crop != _crop) {
        _name.text = crop.id == unknownCropId ? '' : crop.name.of(context);
      }
      _crop = crop;
      _step = 1;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
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
    setState(() => _saving = true);
    try {
      final saved = await FarmStore.addPlant(plant);
      if (mounted) Navigator.of(context).pop(saved);
    } on FarmFullException {
      _saveFailed((s) => s.farmLandFull, EthmarToastType.info);
    } catch (_) {
      _saveFailed((s) => s.farmSaveFailed, EthmarToastType.error);
    }
  }

  void _saveFailed(String Function(S) message, EthmarToastType type) {
    if (!mounted) return;
    setState(() => _saving = false);
    showEthmarToast(context, message(S.of(context)), type: type);
  }

  @override
  Widget build(BuildContext context) {
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



  // Step 1: choose the crop process 

  Widget _buildChooseStep() {
    final s = S.of(context);

    final categories = <CropCategory>{
      for (final crop in cropCatalog) crop.category,
    };
    final crops = _filter == null
        ? cropCatalog
        : cropCatalog.where((c) => c.category == _filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: CategoryChip(
                    label: s.filterAll,
                    count: cropCatalog.length,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: CategoryChip(
                      label: categoryLabel(c, context),
                      icon: categoryIcon(c),
                      count: cropCatalog.where((x) => x.category == c).length,
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
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

  // Step 2: name and schedules process

  Widget _buildDetailsStep() {
    final s = S.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: EthmarButton(
                label: s.addPlantButton,
                onPressed: _submit,
                loading: _saving,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Header: back, centred title and which step, straight on the background.

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EthmarCenteredHeader(title: s.addPlantTitle),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            '${s.addPlantStep(step + 1)} · '
            '${step == 0 ? s.addPlantChoose : s.addPlantDetails}',
            key: ValueKey(step),
            textAlign: TextAlign.center,
            style: AppText.small(context),
          ),
        ),
      ],
    );
  }
}


// Step 1 class: crop card

/// Square card: the crop's picture on warm white with a thin earthy border
/// (like the recommender's cards), name below.
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
          side: BorderSide(
            color: AppColors.earthBrown.withValues(alpha: 0.35),
          ),
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
                  child: PlantPicture(
                    crop.image,
                    fit: BoxFit.contain,
                    cacheWidth: 320,
                  ),
                ),
                const SizedBox(height: 8),
                // Long names shrink to fit, so they're never cut off.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppText.title(context).copyWith(fontSize: 16),
                  ),
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


// Step 2 classes: chosen crop and summary dialog

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
          color: AppColors.featureCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: PlantPicture(crop.image, cacheWidth: 200),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel(cat, context),
                    style: AppText.small(context),
                  ),
                  Text(
                    crop.name.of(context),
                    style: AppText.title(context).copyWith(fontSize: 18),
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


// Summary dialog: confirm, or go back and change something.


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
                decoration: const BoxDecoration(
                  color: AppColors.featureCard,
                  shape: BoxShape.circle,
                ),
                child: PlantPicture(crop.image, cacheWidth: 300),
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
                color: AppColors.featureCard,
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
                          style: AppText.title(context).copyWith(fontSize: 18),
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
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryLabel(cat, context),
                      style: AppText.small(
                        context,
                        color: AppColors.earthBrown,
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
              color: AppColors.featureCard,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.forest),
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
                        color: set ? AppColors.textPrimary : AppColors.textSecondary,
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
