import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// Header with a centred title, the back button on the reading start side
/// and an optional action on the end side (Back left / action right in
/// English, mirrored in Arabic).
class EthmarCenteredHeader extends StatelessWidget {
  const EthmarCenteredHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showBack = true,
  });
  final String title;
  final Widget? trailing;

  /// False on the main tabs, where there is nothing to go back to. The
  /// slot stays the same size, so the title stays centred.
  final bool showBack;

  // Same width on both sides keeps the title truly centred.
  static const _sideWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final end = trailing;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _sideWidth,
            // 48 keeps the header the same height with or without the button.
            height: 48,
            child: showBack
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: EthmarBackButton(tooltip: S.of(context).back),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
          ),
          SizedBox(
            width: _sideWidth,
            child: end == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FittedBox(fit: BoxFit.scaleDown, child: end),
                  ),
          ),
        ],
      ),
    );
  }
}

/// White pill button with an icon and a short label, for header actions.
class HeaderPillButton extends StatelessWidget {
  const HeaderPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.forest),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.label(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
