import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Soft green header with rounded bottom corners: back button in a white
/// circle, the title, an optional hand-written line, and an optional
/// widget at the end (e.g. a button).
class EthmarPageHeader extends StatelessWidget {
  const EthmarPageHeader({
    super.key,
    required this.title,
    this.accent,
    this.trailing,
  });
  final String title;
  final String? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final a = accent;
    final end = trailing;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: S.of(context).back,
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(context).copyWith(fontSize: 24),
                ),
                if (a != null)
                  Text(a, style: AppText.accent(context, size: 16)),
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: 8), end],
        ],
      ),
    );
  }
}
