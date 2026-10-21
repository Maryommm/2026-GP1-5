import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft cream background image used behind every screen except Home.
/// Stays fixed behind [child] while it scrolls. A screen can pass its own
/// [image] (Profile does); everyone else gets the shared inner background.
class LeafPrintBackground extends StatelessWidget {
  const LeafPrintBackground({
    super.key,
    required this.child,
    this.image = asset,
    this.shiftDown = 0,
  });
  final Widget child;
  final String image;

  /// Moves the image down by this fraction of the screen height, so its
  /// top illustration sits a little lower. The space above it is the same
  /// sand colour, and the image's top edge fades into it.
  final double shiftDown;

  static const asset = 'assets/images/ethmar_inner_background.png';

  @override
  Widget build(BuildContext context) {
    final picture = Image.asset(
      image,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return Stack(
      children: [
        // Sand colour shows while the image loads.
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.background,
            child: shiftDown <= 0
                ? picture
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final offset = constraints.maxHeight * shiftDown;
                      return Padding(
                        padding: EdgeInsets.only(top: offset),
                        // Soft top edge, so the corner leaves don't end in a
                        // hard line.
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [Color(0x00000000), Color(0xFF000000)],
                            stops: [0, (offset / rect.height).clamp(0.0, 1.0)],
                          ).createShader(rect),
                          child: picture,
                        ),
                      );
                    },
                  ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
