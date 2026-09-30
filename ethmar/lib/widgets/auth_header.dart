import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'character.dart';
import 'doodles.dart' show SquiggleUnderline;
import 'entrance.dart';
import 'ethmar_buttons.dart';

/// Header used on Sign up and Log in: back arrow, title with the
/// hand-written coral line (the screen's one accent), character at the end.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.accent,
    required this.character,
  });

  final String title;
  final String accent;
  final String character;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12, top + 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EthmarBackButton(tooltip: s.back),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Entrance(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.title(context)),
                        const SizedBox(height: 6),
                        IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(accent, style: AppText.accent(context, size: 19)),
                              DelayedProgress(
                                delay: const Duration(milliseconds: 400),
                                builder: (_, p) => SquiggleUnderline(progress: p, width: 40),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Entrance(
                  delay: const Duration(milliseconds: 120),
                  child: EthmarCharacter(name: character, height: 112),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Already have an account? Log in" style footer.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key, required this.question, required this.action, required this.onTap});
  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: AppText.small(context).copyWith(fontSize: 14)),
        const SizedBox(width: 2),
        EthmarLink(label: action, onTap: onTap),
      ],
    );
  }
}

/// Friendly floating message at the bottom of the screen.
void showEthmarToast(BuildContext context, String message,
    {IconData icon = Icons.check_circle_rounded, Color color = AppColors.forest}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Row(
        children: [
          Icon(icon, color: AppColors.sun),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.label(context, color: Colors.white))),
        ],
      ),
    ));
}
