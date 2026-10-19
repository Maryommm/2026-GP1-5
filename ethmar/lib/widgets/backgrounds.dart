import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft cream background image used behind every screen except Home.
/// Stays fixed behind [child] while it scrolls. A screen can pass its own
/// [image] (Profile does); everyone else gets the shared inner background.
class LeafPrintBackground extends StatelessWidget {
  const LeafPrintBackground({super.key, required this.child, this.image = asset});
  final Widget child;
  final String image;

  static const asset = 'assets/images/ethmar_inner_background.png';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sand colour shows while the image loads.
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.background,
            child: Image.asset(
              image,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
