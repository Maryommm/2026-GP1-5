import 'package:flutter/material.dart';

import '../models/crop_catalog.dart';
import '../theme/app_colors.dart';

/// The box behind a plant's picture on My Plants and Plant Details: white,
/// with a thin outline and [radius] corners.
BoxDecoration plantPictureFrame(double radius) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.earthBrown.withValues(alpha: 0.35)),
);

/// A plant's picture, or [defaultPlantImage] if it can't be loaded.
class PlantPicture extends StatelessWidget {
  const PlantPicture(
    this.image, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
  });

  /// The asset path, e.g. `FarmPlant.image`.
  final String image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  Widget _asset(String path, {ImageErrorWidgetBuilder? onError}) => Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    cacheWidth: cacheWidth,
    filterQuality: filterQuality,
    errorBuilder: onError,
  );

  @override
  Widget build(BuildContext context) =>
      _asset(image, onError: (_, _, _) => _asset(defaultPlantImage));
}
