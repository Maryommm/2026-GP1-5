import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_header.dart';
import '../widgets/page_routes.dart';
import 'add_plant_screen.dart';
import 'plant_details_screen.dart';

/// "My plants": every plant on the farm, newest first, by the name the
/// user gave it. Tapping one opens its details.
class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: ValueListenableBuilder<List<FarmPlant>>(
          valueListenable: FarmStore.plants,
          builder: (context, plants, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EthmarPageHeader(title: s.myPlants, accent: s.myPlantsAccent),
              Expanded(
                child: plants.isEmpty
                    ? const _NoPlants()
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          16 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: plants.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          // Newest first.
                          final index = plants.length - 1 - i;
                          return Entrance(
                            delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                            child: _PlantCard(
                              plant: plants[index],
                              onTap: () => Navigator.of(context).push(
                                riseRoute(PlantDetailsScreen(index: index)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
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
                child: Image.asset(crop.image, cacheWidth: 220),
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
              color: AppColors.forest,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
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
