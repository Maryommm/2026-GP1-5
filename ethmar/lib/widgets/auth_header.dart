import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import '../theme/app_colors.dart';

import '../theme/app_theme.dart';

import 'character.dart';

import 'doodles.dart' show SquiggleUnderline;

import 'entrance.dart';

import 'ethmar_buttons.dart';

/// Shared header for authentication and registration screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.character,
    this.accent,
  });

  final String title;
  final String character;

  /// Optional hand-written line with a squiggle under the title.
  final String? accent;

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
              // A one-line title (no accent) sits level with the middle of
              // the character; a title with an accent keeps its baseline.
              crossAxisAlignment: accent == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Entrance(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.title(context)),

                        // Display the accent text with an animated underline.
                        if (accent case final a?) ...[
                          const SizedBox(height: 6),
                          IntrinsicWidth(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  a,
                                  style: AppText.accent(context, size: 19),
                                ),
                                DelayedProgress(
                                  delay: const Duration(milliseconds: 400),
                                  builder: (_, p) =>
                                      SquiggleUnderline(progress: p, width: 40),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Show the selected character beside the title.
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

/// Shared footer with a question and a navigation link.
class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: AppText.small(context).copyWith(fontSize: 14),
        ),
        const SizedBox(width: 2),
        EthmarLink(label: action, onTap: onTap),
      ],
    );
  }
}

/// The kind of feedback a toast gives; it sets the icon and its colour.
enum EthmarToastType {
  success(Icons.check_rounded, AppColors.toastSuccess),
  error(Icons.close_rounded, AppColors.toastError),
  info(Icons.info_outline_rounded, AppColors.toastInfo);

  const EthmarToastType(this.icon, this.color);
  final IconData icon;
  final Color color;
}

/// Show a floating message and replace any previous message.
void showEthmarToast(
  BuildContext context,
  String message, {
  EthmarToastType type = EthmarToastType.success,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forest,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Row(
          children: [
            // White circle, same 24px as the old icon, so the size stays.
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, size: 16, color: type.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppText.label(context, color: AppColors.surface),
              ),
            ),
          ],
        ),
      ),
    );
}