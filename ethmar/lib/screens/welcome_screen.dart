import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_logo.dart';
import '../widgets/language_chip.dart';
import '../widgets/page_routes.dart';
import 'crop_recommendation_screen.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

/// Logo and language switch in the top corners, then floating leaves and
/// the character on its seedling bed.
/// Welcome text and the two actions sit underneath.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LeafPrintBackground(
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: logo in the start corner, language switch in the
              // end corner (Row flips these automatically in Arabic).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Entrance(
                    delay: const Duration(milliseconds: 200),
                    // 110 wide -> ~48 tall, same height as the language chip.
                    child: EthmarLogo(width: 110),
                  ),
                  const LanguageChip(),
                ],
              ),
              const Expanded(child: _Hero()),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.welcomeTitle, style: AppText.title(context)),
                    const SizedBox(height: 8),
                    Text(s.welcomeBody, style: AppText.body(context)),
                    const SizedBox(height: 24),
                    EthmarButton(
                      label: s.createAccount,
                      onPressed: () => Navigator.of(context)
                          .push(riseRoute(const SignUpScreen())),
                    ),
                    const SizedBox(height: 12),
                    EthmarButton(
                      label: s.haveAccount,
                      outlined: true,
                      onPressed: () => Navigator.of(context)
                          .push(riseRoute(const LoginScreen())),
                    ),
                    // TEMP: shortcut to the crop recommendation screen
                    // until the home page exists.
                    Center(
                      child: EthmarLink(
                        label: s.cropPreviewLink,
                        onTap: () => Navigator.of(context).push(
                            riseRoute(const CropRecommendationScreen())),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

/// A few loose leaves floating around, and the character
/// standing on the seedling bed at the bottom.
/// (English: character right of centre. Arabic mirrors this.)
class _Hero extends StatelessWidget {
  const _Hero();

  // Floating leaves: image, position, width (px) and tilt (radians).
  // Position runs from -1 to 1 across the hero area:
  // x: -1 = left edge, 1 = right edge. y: -1 = top, 1 = bottom.
  static const _leaves = [
    _Leaf('ethmar_leaf_light_flat', Alignment(-0.85, -0.75), 40, -0.5),
    _Leaf('ethmar_leaf_curved', Alignment(0.9, -0.55), 34, 0.3),
    _Leaf('ethmar_sprout_pair_tilted', Alignment(-0.95, -0.1), 30, -0.2),
    _Leaf('ethmar_leaf_dark', Alignment(-0.5, 0.25), 32, 0.6),
    _Leaf('ethmar_leaf_curled', Alignment(0.95, 0.3), 36, -0.3),
    _Leaf('ethmar_sprout_pair', Alignment(0.55, -0.75), 28, 0.2),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        // ---- Placement knobs: tweak these ----
        // Seedling bed width (the height follows the image's shape).
        final bedW = w * 1.0;
        final bedH = bedW * 582 / 1986;
        // How far up the bed the character's feet stand (share of bed height).
        final feet = bedH * 0.20;
        // Character height.
        final charH = math.min((h - feet) * 0.8, 250.0);
        // Character left/right: 0 = middle, 1 = right edge (both languages).
        const charX = 1.0;
        // ---------------------------------------

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final leaf in _leaves)
              Align(
                alignment: leaf.at,
                child: Entrance(
                  delay: const Duration(milliseconds: 300),
                  offset: 0,
                  child: Transform.rotate(
                    angle: leaf.tilt,
                    child: Image.asset('assets/images/${leaf.image}.png',
                        width: leaf.width),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Entrance(
                offset: 0,
                child: Image.asset('assets/images/ethmar_seedling_bed.png',
                    width: bedW, height: bedH),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: feet,
              child: Align(
                // Plain Alignment (not directional) so Arabic uses the
                // same spot as English instead of mirroring it.
                alignment: const Alignment(charX, 1),
                child: Entrance(
                  delay: const Duration(milliseconds: 100),
                  child: EthmarCharacter(
                      name: 'ethmar_buddy_crate', height: charH),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Leaf {
  const _Leaf(this.image, this.at, this.width, this.tilt);
  final String image;
  final Alignment at;
  final double width;
  final double tilt;
}
