import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Quiet text button that switches between عربي and English.
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: toggleLanguage,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, size: 18, color: AppColors.forest),
                const SizedBox(width: 6),
                Text(s.languageSwitch, style: AppText.label(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
