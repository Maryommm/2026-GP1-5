import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/crop_recommendation.dart' show CropCategory;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A category's display name. Grain and "Other crops" keep their own label.
String categoryLabel(CropCategory cat, BuildContext context) {
  final s = S.of(context);
  return switch (cat) {
    CropCategory.herb => s.cropCatHerb,
    CropCategory.legume => s.cropCatLegume,
    CropCategory.root => s.cropCatRoot,
    CropCategory.vegetable => s.cropCatVegetable,
    CropCategory.fruit => s.cropCatFruit,
    _ => cat.label.of(context),
  };
}

/// Small transparent icon for the category buttons.
String categoryIcon(CropCategory cat) => switch (cat) {
  CropCategory.herb => 'assets/images/ethmar_herbs_icon.png',
  CropCategory.legume => 'assets/images/ethmar_legumes_icon.png',
  CropCategory.root => 'assets/images/ethmar_root_veg_icon.png',
  CropCategory.vegetable => 'assets/images/ethmar_veg_icon.png',
  CropCategory.fruit => 'assets/images/ethmar_fruits_icon.png',
  _ => cat.iconImage,
};

/// One category button, used by the recommender and when adding a plant: its
/// icon (if any), its name, and how many crops it has.
/// White with a thin earthy border; the selected one gets a soft green
/// tint and a stronger border.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count = 0,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The asset path, e.g. from [categoryIcon]. Null for "All".
  final String? icon;

  /// Shown in a small circle when there is more than one.
  final int count;

  @override
  Widget build(BuildContext context) {
    final image = icon;
    const radius = BorderRadius.all(Radius.circular(14));
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.featureCard : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.earthBrown.withValues(alpha: selected ? 0.7 : 0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          // InkWell shows the ripple effect when tapped.
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: ConstrainedBox(
              // Compact, but still an easy tap target.
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  image == null ? 12 : 8,
                  0,
                  10,
                  0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image != null) ...[
                      ExcludeSemantics(
                        child: Image.asset(
                          image,
                          width: 24,
                          height: 24,
                          cacheWidth: 96,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: AppText.label(context).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // The small circle with the number of crops
                    if (count > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.backgroundAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: AppText.small(
                            context,
                            color: AppColors.earthBrown,
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
