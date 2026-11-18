import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/category_chip.dart' show categoryIcon, categoryLabel;
import '../widgets/centered_header.dart' show HeaderPillButton;
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_header.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'add_plant_screen.dart';
import 'plant_details_screen.dart';

/// "My plants": every plant on the farm, newest first, by the name the
/// user gave it. Tapping one opens its details.
///
/// The Filter button in the header lists the plant categories; picking one
/// shows only the plants in it, and clearing it shows them all again.
class MyPlantsScreen extends StatefulWidget {
  const MyPlantsScreen({super.key});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  /// The chosen category; null shows every plant.
  CropCategory? _filter;

  void _setFilter(CropCategory? category) =>
      setState(() => _filter = category);

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
    return Scaffold(
      body: LeafPrintBackground(
        child: ValueListenableBuilder<List<FarmPlant>>(
          valueListenable: FarmStore.plants,
          builder: (context, plants, _) {
            final filter = _filter;
            final newestFirst = [
              for (final p in plants)
                if (filter == null || p.crop.category == filter) p,
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EthmarPageHeader(
                  title: s.myPlants,
                  accent: s.myPlantsAccent,
                  // Nothing to filter on an empty farm.
                  trailing: plants.isEmpty
                      ? null
                      : HeaderPillButton(
                          key: const Key('plantsFilter'),
                          icon: Icons.tune_rounded,
                          label: s.filter,
                          onPressed: () => _openFilter(plants),
                        ),
                ),
                if (filter != null && plants.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
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
                            16 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: newestFirst.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final plant = newestFirst[i];
                            return Entrance(
                              delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                              child: _PlantCard(
                                plant: plant,
                                onTap: () => Navigator.of(context).push(
                                  riseRoute(
                                    PlantDetailsScreen(plantId: plant.id!),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The plant's picture, its name, what it is, how old it is and how often
/// it's watered.
class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant, required this.onTap});
  final FarmPlant plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final crop = plant.crop;
    final cat = crop.category;
    final irrigation = plant.irrigation;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
          child: Row(
            children: [
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
                      style: AppText.label(context)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
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
        plants.where((p) => p.crop.category == c).length;
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
                    style: AppText.label(context).copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
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
