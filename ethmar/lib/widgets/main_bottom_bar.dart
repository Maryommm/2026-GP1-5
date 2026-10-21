import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The app's bottom bar: Home, Daily Tasks, Virtual Farm, Ask Thamoor, in
/// the same order in both languages. The selected tab sits on a
/// pale-yellow pill. Used only by MainShell.
class MainBottomBar extends StatelessWidget {
  const MainBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  /// 0 Home, 1 Daily Tasks, 2 Virtual Farm, 3 Ask Thamoor.
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          // Same tab order in both languages.
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              _NavItem(
                image: 'ethmar_homepage_icon',
                label: s.navHome,
                selected: currentIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                image: 'ethmar_tasks_icon',
                label: s.navDailyTasks,
                selected: currentIndex == 1,
                onTap: () => onSelect(1),
              ),
              _NavItem(
                image: 'ethmar_virtual_farm_icon',
                // Very wide drawing (about 2.3:1): a wider box so it looks
                // the same size as the square icons.
                iconWidth: 42,
                iconHeight: 20,
                label: s.navVirtualFarm,
                selected: currentIndex == 2,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                image: 'ethmar_chatbot_icon',
                // Wide, detailed drawing: a bigger box so it looks the same
                // size as the square icons.
                iconWidth: 36,
                iconHeight: 27,
                label: s.navAskThamoor,
                selected: currentIndex == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.image,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.iconWidth = 24,
    this.iconHeight = 24,
  });

  /// Line-art icon in assets/images/ (without .png), tinted dark green.
  final String image;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Icon box size; most icons are square and use 24×24.
  final double iconWidth;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pale-yellow pill behind the selected tab's icon. Icons sit
                // on one shared bottom line, whatever their shape.
                Container(
                  width: 56,
                  height: 32,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sunTint : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/images/$image.png',
                    width: iconWidth,
                    height: iconHeight,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    color: AppColors.forest,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppText.small(context, color: AppColors.textPrimary)
                        .copyWith(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
