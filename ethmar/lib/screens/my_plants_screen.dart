import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../services/network_errors.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/category_chip.dart' show categoryIcon, categoryLabel;
import '../widgets/centered_header.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'add_plant_screen.dart';
import 'plant_details_screen.dart';

/// "My plants": every plant on the farm, newest first, by the name the
/// user gave it. Tapping one opens its details.
///
/// The Filter button in the header lists the plant categories; picking one
/// shows only the plants in it, and clearing it shows them all again.
///
/// The Select button puts a box next to every plant: tapping plants ticks
/// them, and Delete removes all the ticked ones after asking. Cancel or
/// Back leaves select mode without deleting anything.
class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  /// The chosen category; null shows every plant.
  CropCategory? _filter;

  /// True while the boxes are shown.
  bool _selecting = false;

  /// Ids of the ticked plants. Only the ones still on screen count (see
  /// [_ticked]), so a plant hidden by the filter or deleted elsewhere is
  /// never deleted by mistake.
  final _selected = <String>{};

  void _setFilter(CropCategory? category) => setState(() => _filter = category);

  void _startSelecting() => setState(() {
    _selecting = true;
    _selected.clear();
  });

  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  /// The ticked plants among [shown].
  List<FarmPlant> _ticked(List<FarmPlant> shown) => [
    for (final p in shown)
      if (_selected.contains(p.id)) p,
  ];

  /// Asks first, then deletes [plants] and their growth entries.
  ///
  /// Each plant leaves the list once its delete is confirmed; one that
  /// can't be deleted (e.g. offline) stays, and the screen says so.
  Future<void> _deleteTicked(List<FarmPlant> plants) async {
    if (plants.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => _DeletePlantsDialog(plants: plants),
    );
    if (confirmed != true || !mounted) return;
    final s = S.of(context);
    _stopSelecting();
    // One after another, so the streak only counts deletes that worked;
    // the ones that fail stay in the list.
    final failed = await FarmStore.deletePlants([for (final p in plants) p.id!]);
    if (mounted && failed.isNotEmpty) {
      showEthmarToast(
        context,
        failed.values.any(isNetworkError)
            ? s.plantsDeleteFailed
            : s.plantsDeleteFailedGeneric,
        type: EthmarToastType.error,
      );
    }
  }

  Future<void> _openFilter(List<FarmPlant> plants) async {
    final choice = await showModalBottomSheet<({CropCategory? category})>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _FilterSheet(plants: plants, selected: _filter),
    );
    // Closed without a choice: keep the current filter.
    if (choice != null && mounted) _setFilter(choice.category);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      // Back leaves select mode first, then the screen.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _stopSelecting();
      },
      child: Scaffold(
        body: LeafPrintBackground(
          child: ValueListenableBuilder<List<FarmPlant>>(
            valueListenable: FarmStore.plants,
            builder: (context, plants, _) {
              final filter = _filter;
              final newestFirst = [
                for (final p in plants)
                  if (filter == null || p.category == filter) p,
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              // Nothing left to select (e.g. the last plants were deleted).
              final selecting = _selecting && plants.isNotEmpty;
              final ticked = _ticked(newestFirst);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Just the title and Back; the actions are in the
                  // toolbar below.
                  EthmarCenteredHeader(title: s.myPlants),
                  // Nothing to filter or select on an empty farm.
                  if (plants.isNotEmpty)
                    selecting
                        ? _SelectionBar(
                            count: ticked.length,
                            allTicked: ticked.length == newestFirst.length,
                            // Nothing to tick when the filter shows none.
                            onToggleAll: newestFirst.isEmpty
                                ? null
                                : () => setState(() {
                                    if (ticked.length == newestFirst.length) {
                                      _selected.clear();
                                    } else {
                                      _selected.addAll([
                                        for (final p in newestFirst) p.id!,
                                      ]);
                                    }
                                  }),
                            onCancel: _stopSelecting,
                          )
                        : _Toolbar(
                            onFilter: () => _openFilter(plants),
                            onSelect: _startSelecting,
                          ),
                  if (filter != null && plants.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        10,
                        16,
                        0,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _ActiveFilter(
                          category: filter,
                          onClear: () => _setFilter(null),
                        ),
                      ),
                    ),
                  Expanded(
                    child: plants.isEmpty
                        ? const _NoPlants()
                        : newestFirst.isEmpty
                        ? _NoMatch(
                            category: filter!,
                            onClear: () => _setFilter(null),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              // The delete bar below takes the safe area.
                              16 +
                                  (selecting && ticked.isNotEmpty
                                      ? 0
                                      : MediaQuery.paddingOf(context).bottom),
                            ),
                            itemCount: newestFirst.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final plant = newestFirst[i];
                              return Entrance(
                                delay: Duration(
                                  milliseconds: 40 * i.clamp(0, 8),
                                ),
                                child: _PlantCard(
                                  plant: plant,
                                  selected: selecting
                                      ? _selected.contains(plant.id)
                                      : null,
                                  onTap: selecting
                                      ? () => _toggle(plant.id!)
                                      : () => Navigator.of(context).push(
                                          riseRoute(
                                            PlantDetailsScreen(
                                              plantId: plant.id!,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Delete appears once a plant is ticked.
                  if (selecting && ticked.isNotEmpty)
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: EthmarButton(
                        key: const Key('deleteSelected'),
                        label: s.deleteSelected(ticked.length),
                        color: AppColors.error,
                        textColor: AppColors.surface,
                        onPressed: () => _deleteTicked(ticked),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Under the header: Filter and Select, on the end side.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onFilter, required this.onSelect});
  final VoidCallback onFilter;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ToolbarButton(
            key: const Key('plantsFilter'),
            icon: Icons.filter_alt_outlined,
            label: s.filter,
            onPressed: onFilter,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            key: const Key('selectPlants'),
            icon: Icons.check_box_outlined,
            label: s.select,
            semanticLabel: s.selectPlants,
            onPressed: onSelect,
          ),
        ],
      ),
    );
  }
}

/// In place of the toolbar in select mode, on a pale green band so the
/// mode is clear: how many plants are ticked, a button to tick (or untick)
/// every plant on screen, and Cancel.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.allTicked,
    required this.onToggleAll,
    required this.onCancel,
  });
  final int count;
  final bool allTicked;

  /// Null when the filter shows no plants to tick.
  final VoidCallback? onToggleAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final toggleAll = onToggleAll;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.forestTint,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.selectedCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(context, color: AppColors.forest)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (toggleAll != null) ...[
              _ToolbarButton(
                key: const Key('toggleAllPlants'),
                label: allTicked ? s.deselectAll : s.selectAll,
                onPressed: toggleAll,
              ),
              const SizedBox(width: 6),
            ],
            _ToolbarButton(
              key: const Key('cancelSelecting'),
              icon: Icons.close_rounded,
              label: s.cancel,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact white pill with an optional icon and a short label, in the
/// app's dark green, for the toolbar and the select-mode bar.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// What screen readers say, when it should say more than [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            // An easy tap target, still compact.
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                glyph == null ? 14 : 12,
                0,
                14,
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (glyph != null) ...[
                    Icon(glyph, size: 18, color: AppColors.forest),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: AppText.label(context, color: AppColors.forest)
                        .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
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

/// Asks before deleting the ticked plants; their growth entries go too.
/// One plant is named, as on its details page.
class _DeletePlantsDialog extends StatelessWidget {
  const _DeletePlantsDialog({required this.plants});
  final List<FarmPlant> plants;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final one = plants.length == 1;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              size: 42,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              one ? s.deletePlantTitle : s.deletePlantsTitle(plants.length),
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              one
                  ? s.deletePlantMessage(plants.single.name)
                  : s.deletePlantsMessage,
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 22),
            EthmarButton(
              key: const Key('confirmDeletePlants'),
              label: s.deleteSelected(plants.length),
              color: AppColors.error,
              textColor: AppColors.surface,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.cancel,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plant's picture, its name, what it is, how old it is and how often
/// it's watered.
///
/// In select mode ([selected] isn't null) a box at the start shows whether
/// it's ticked, and tapping the card ticks or unticks it.
class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant, required this.onTap, this.selected});
  final FarmPlant plant;
  final VoidCallback onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final crop = plant.crop;
    final cat = plant.category;
    final irrigation = plant.irrigation;
    final ticked = selected;
    return Semantics(
      checked: ticked,
      child: Material(
        color: ticked == true ? AppColors.forestTint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: ticked == true
              ? const BorderSide(color: AppColors.forest, width: 1.6)
              : const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ticked == null ? 12 : 4,
              12,
              8,
              12,
            ),
            child: Row(
              children: [
                if (ticked != null)
                  Checkbox(
                    key: Key('selectPlant_${plant.id}'),
                    value: ticked,
                    onChanged: (_) => onTap(),
                    activeColor: AppColors.forest,
                    side: const BorderSide(
                      color: AppColors.textSecondary,
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cat.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: PlantPicture(crop.image, cacheWidth: 220),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(
                          context,
                        ).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${crop.name.of(context)} · ${cat.label.of(context)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small(context),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            text: s.plantAge(plant.daysSincePlanting),
                          ),
                          _InfoChip(
                            icon: Icons.water_drop_rounded,
                            text: irrigation == null
                                ? s.summaryNotSet
                                : irrigation.repeat.label(s),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tapping opens the details only outside select mode.
                if (ticked == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.forest),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppText.small(
              context,
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// The filtering options: "All" and every plant category, each with how
/// many of the user's plants are in it. Picking one closes the sheet with
/// that choice (a null category means all plants).
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.plants, required this.selected});
  final List<FarmPlant> plants;
  final CropCategory? selected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    int countOf(CropCategory c) =>
        plants.where((p) => p.category == c).length;
    void pick(CropCategory? c) => Navigator.of(context).pop((category: c));

    Widget option({
      required CropCategory? category,
      required String label,
      required int count,
    }) {
      final isSelected = category == selected;
      final icon = category == null ? null : categoryIcon(category);
      return ListTile(
        key: Key('filterOption_${category?.name ?? 'all'}'),
        selected: isSelected,
        selectedTileColor: AppColors.forestTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: SizedBox(
          width: 32,
          height: 32,
          child: icon == null
              ? const Icon(Icons.eco_rounded, color: AppColors.forest)
              : Image.asset(icon, cacheWidth: 96),
        ),
        title: Text(
          label,
          style: AppText.label(context).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: AppText.small(context)),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_rounded, color: AppColors.forest),
            ],
          ],
        ),
        onTap: () => pick(category),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
              child: Text(
                s.filterByCategory,
                style: AppText.title(context).copyWith(fontSize: 20),
              ),
            ),
            option(category: null, label: s.filterAll, count: plants.length),
            for (final c in CropCategory.values)
              option(
                category: c,
                label: categoryLabel(c, context),
                count: countOf(c),
              ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              EthmarButton(label: s.clearFilter, onPressed: () => pick(null)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chosen category under the header; tapping it clears the filter.
class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.category, required this.onClear});
  final CropCategory category;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: '${categoryLabel(category, context)}, ${s.clearFilter}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.featureCard,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.earthBrown.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('clearPlantsFilter'),
          onTap: onClear,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 10, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    categoryIcon(category),
                    width: 24,
                    height: 24,
                    cacheWidth: 96,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    categoryLabel(category, context),
                    style: AppText.label(context)
                        .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
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

/// No plant in the chosen category: says so, with a way back to all plants.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.category, required this.onClear});
  final CropCategory category;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EthmarCharacter(name: 'ethmar_buddy_seedling', height: 140),
            const SizedBox(height: 20),
            Text(
              s.filterNoMatch,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              s.filterNoMatchBody(categoryLabel(category, context)),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 24),
            EthmarButton(label: s.clearFilter, onPressed: onClear),
          ],
        ),
      ),
    );
  }
}

/// Nothing planted yet: a friendly nudge to add the first plant.
class _NoPlants extends StatelessWidget {
  const _NoPlants();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EthmarCharacter(name: 'ethmar_buddy_seedling', height: 160),
            const SizedBox(height: 20),
            Text(
              s.myPlantsEmpty,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              s.myPlantsEmptyBody,
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 24),
            EthmarButton(
              label: s.homeAddPlant,
              onPressed: () => AddPlantScreen.open(context),
            ),
          ],
        ),
      ),
    );
  }
}
