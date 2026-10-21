import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/centered_header.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_logo.dart';

/// About Ethmar: logo and tagline, what Ethmar is, what it offers (three
/// feature cards) and our goal.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          children: [
            EthmarCenteredHeader(title: s.aboutEthmar),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  // Logo, name and tagline.
                  Entrance(
                    child: Column(
                      children: [
                        // Same in both languages: the logo, then the tagline.
                        const EthmarLogo(width: 150),
                        const SizedBox(height: 8),
                        Text(
                          s.aboutTagline,
                          textAlign: TextAlign.center,
                          style: AppText.accent(context, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Entrance(
                    delay: const Duration(milliseconds: 80),
                    child: _TextSection(
                      title: s.aboutWhatTitle,
                      body: s.aboutWhatBody,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Entrance(
                    delay: const Duration(milliseconds: 140),
                    child: _SectionTitle(s.aboutOffersTitle),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delay: const Duration(milliseconds: 180),
                    child: _OfferCard(
                      icon: Icons.eco_outlined,
                      tint: AppColors.featureCard,
                      iconColor: AppColors.forest,
                      title: s.aboutCard1Title,
                      body: s.aboutCard1Body,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delay: const Duration(milliseconds: 220),
                    child: _OfferCard(
                      icon: Icons.water_drop_outlined,
                      tint: AppColors.seaTint,
                      iconColor: AppColors.seaDeep,
                      title: s.aboutCard2Title,
                      body: s.aboutCard2Body,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Entrance(
                    delay: const Duration(milliseconds: 260),
                    child: _OfferCard(
                      icon: Icons.emoji_events_outlined,
                      tint: AppColors.sunTint,
                      iconColor: AppColors.sunDark,
                      title: s.aboutCard3Title,
                      body: s.aboutCard3Body,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Entrance(
                    delay: const Duration(milliseconds: 300),
                    child: _TextSection(
                      icon: Icons.flag_outlined,
                      title: s.aboutGoalTitle,
                      body: s.aboutGoalBody,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.title(context).copyWith(fontSize: 20));
  }
}

// A heading and a paragraph in a white card, with an optional icon at the
// start of the heading.
class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.body, this.icon});
  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon == null)
            _SectionTitle(title)
          else
            Row(
              children: [
                // Same look as the feature cards' icons: a tinted circle.
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.featureCard,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: AppColors.forest),
                ),
                const SizedBox(width: 12),
                Flexible(child: _SectionTitle(title)),
              ],
            ),
          const SizedBox(height: 6),
          Text(body, style: AppText.body(context)),
        ],
      ),
    );
  }
}

// One benefit card: icon, short title and a short description.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.label(context)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppText.body(context)
                      .copyWith(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
