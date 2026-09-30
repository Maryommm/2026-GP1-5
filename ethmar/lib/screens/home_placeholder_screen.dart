import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/page_routes.dart';
import 'welcome_screen.dart';

/// Temporary landing screen after sign up / log in, until Home is built.
/// Greeting and title on top, the character on its sea-coloured disc
/// (the one accent) in the middle, a quiet log-out at the bottom.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key, this.name = ''});
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final who = name.isEmpty ? s.homeFriend : name.split(' ').first;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final greeting = '${s.homeHello}${isAr ? '، ' : ', '}$who';
    return Scaffold(
      body: LeafPrintBackground(
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting,
                        style: AppText.accent(context,
                            size: 22, color: AppColors.forest)),
                    const SizedBox(height: 8),
                    Text(s.homeTitle, style: AppText.display(context)),
                    const SizedBox(height: 12),
                    Text(s.homeBody, style: AppText.body(context)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final charH = math.min(c.maxHeight * 0.9, 260.0);
                      final disc = math.min(charH * 0.95, c.maxWidth);
                      return Entrance(
                        delay: const Duration(milliseconds: 150),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: disc,
                                height: disc,
                                decoration: const BoxDecoration(
                                  color: AppColors.seaTint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              EthmarCharacter(
                                  name: 'character_home', height: charH),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              EthmarButton(
                label: s.logOut,
                outlined: true,
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  riseRoute(const WelcomeScreen()),
                  (_) => false,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
