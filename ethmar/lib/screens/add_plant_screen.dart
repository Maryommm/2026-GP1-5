import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_catalog.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../models/daily_task.dart' show TaskType;
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
import '../widgets/care_icon.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'plant_details_screen.dart';

typedef SavePlant = Future<FarmPlant> Function(FarmPlant plant);

/// "Add a plant", in two steps: (screens)
///  1. Choose the crop
///  2. Name it and, if wanted, set the irrigation and fertilization schedules.
class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key, this.savePlant});

  /// Test seam; production callers save through [FarmStore].
  final SavePlant? savePlant;

  /// Returns the added plant, if any.
  static Future<FarmPlant?> open(
    BuildContext context, {
    SavePlant? savePlant,
  }) async {
    if (FarmStore.landsFull) {
      showEthmarToast(
        context,
        S.of(context).farmLandFull,
        type: EthmarToastType.info,
      );
      return null;
    }
    final plant = await Navigator.of(context)
        .push<FarmPlant>(riseRoute(AddPlantScreen(savePlant: savePlant)));
    if (plant != null && context.mounted) {
      showEthmarToast(context, S.of(context).plantAdded(plant.name));
      final plantId = plant.id;
      if (plantId != null && plantId.trim().isNotEmpty) {
        await Navigator.of(context)
            .push<void>(riseRoute(PlantDetailsScreen(plantId: plantId)));
      }
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

  /// An unknown plant's category, chosen by the user in step 2; it must be
  /// set before saving. Catalog crops already have theirs.
  CropCategory? _unknownCategory;
  bool _showCategoryError = false;

  bool get _isUnknown => _crop?.id == unknownCropId;

  /// What the user typed to find a crop in step 1.
  final _search = TextEditingController();

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
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  /// [name] is what to suggest for an unknown plant, e.g. the search text.
  void _choose(CatalogCrop crop, {String name = ''}) {
    FocusScope.of(context).unfocus();
    setState(() {
      //keep the user's own name if they come back for the same crop.
      // An unknown plant has no name to suggest: the user types their own.
      if (crop != _crop || crop.id == unknownCropId && name.isNotEmpty) {
        _name.text = crop.id == unknownCropId ? name : crop.name.of(context);
      }
      _crop = crop;
      _step = 1;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final named = _form.currentState!.validate();
    final missingCategory = _isUnknown && _unknownCategory == null;
    setState(() => _showCategoryError = missingCategory);
    if (!named || missingCategory) return;
    final plant = FarmPlant(
      crop: _crop!,
      category: _unknownCategory,
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
      final saved = await (widget.savePlant ?? FarmStore.addPlant)(plant);
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
    final query = _search.text.trim();

    // The search covers every category; the chips then narrow it down.
    final found = cropCatalog.where((c) => c.matches(query)).toList();
    int countOf(CropCategory c) => found.where((x) => x.category == c).length;
    // Only categories with a match, so no chip leads to an empty grid.
    final categories = <CropCategory>{
      for (final crop in found) crop.category,
    };
    final filter = categories.contains(_filter) ? _filter : null;
    final crops = filter == null
        ? found
        : found.where((c) => c.category == filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _CropSearchField(
              controller: _search,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        if (found.isNotEmpty)
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
                      count: found.length,
                      selected: filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: CategoryChip(
                        label: categoryLabel(c, context),
                        icon: categoryIcon(c),
                        count: countOf(c),
                        selected: filter == c,
                        onTap: () => setState(() => _filter = c),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: crops.isEmpty
              ? _NoCropFound(
                  query: query,
                  onUseUnknown: () => _choose(
                    cropCatalog.firstWhere((c) => c.id == unknownCropId),
                    name: query,
                  ),
                )
              : GridView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: crops.length,
                  itemBuilder: (context, i) => _CropCard(
                    crop: crops[i],
                    onTap: () => _choose(crops[i]),
                  ),
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
                  category: _isUnknown ? _unknownCategory : _crop!.category,
                  onChange: () => setState(() => _step = 0),
                ),
                const SizedBox(height: 20),
                if (_isUnknown) ...[
                  _CategoryPicker(
                    selected: _unknownCategory,
                    showError: _showCategoryError,
                    onSelected: (c) => setState(() {
                      _unknownCategory = c;
                      _showCategoryError = false;
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
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

// Step 1 classes: search field, no-match message and crop card

/// Rounded white search box, styled like the app's text fields.
class _CropSearchField extends StatelessWidget {
  const _CropSearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  static InputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: kControlRadius,
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: AppText.body(context, color: AppColors.textPrimary)
          .copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: s.cropSearchHint,
        hintStyle: AppText.body(context, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: s.cropSearchClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.forest, 1.6),
      ),
    );
  }
}

/// Shown when no crop matches the search: offers the unknown plant instead,
/// named after what the user typed.
class _NoCropFound extends StatelessWidget {
  const _NoCropFound({required this.query, required this.onUseUnknown});
  final String query;
  final VoidCallback onUseUnknown;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          const SizedBox(
            width: 96,
            height: 96,
            child: PlantPicture(defaultPlantImage, cacheWidth: 300),
          ),
          const SizedBox(height: 16),
          Text(
            s.cropSearchEmpty(query),
            textAlign: TextAlign.center,
            style: AppText.title(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 20),
          EthmarButton(
            label: s.cropSearchUseUnknown,
            outlined: true,
            color: AppColors.featureCard,
            onPressed: onUseUnknown,
          ),
        ],
      ),
    );
  }
}

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
          side: BorderSide(color: AppColors.earthBrown.withValues(alpha: 0.35)),
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

/// An unknown plant's category: one chip per category, and a short line on
/// why it's needed. [showError] asks for a choice after a save attempt.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selected,
    required this.showError,
    required this.onSelected,
  });
  final CropCategory? selected;
  final bool showError;
  final ValueChanged<CropCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      key: const Key('unknownCategoryPicker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.addPlantCategoryLabel,
          style: AppText.label(context).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(s.addPlantCategoryHint, style: AppText.small(context)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in CropCategory.values)
              CategoryChip(
                key: Key('unknownCategory_${c.name}'),
                label: categoryLabel(c, context),
                icon: categoryIcon(c),
                selected: c == selected,
                onTap: () => onSelected(c),
              ),
          ],
        ),
        if (showError) ...[
          const SizedBox(height: 8),
          Text(
            s.errPlantCategoryRequired,
            style: AppText.small(context, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// The crop picked in step 1, with a link back to change it. [category] is
/// null while an unknown plant has none chosen yet.
class _ChosenCrop extends StatelessWidget {
  const _ChosenCrop({
    required this.crop,
    required this.category,
    required this.onChange,
  });
  final CatalogCrop crop;
  final CropCategory? category;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final cat = category;
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
                  if (cat != null)
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
    final cat = plant.category;
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
              type: TaskType.watering,
              label: s.summaryIrrigation,
              value: describe(plant.irrigation),
              set: plant.irrigation != null,
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              type: TaskType.fertilizing,
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
    required this.type,
    required this.label,
    required this.value,
    required this.set,
  });
  final TaskType type;
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
            child: CareTypeIcon(type, size: 18, color: AppColors.forest),
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
                        color: set
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
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
