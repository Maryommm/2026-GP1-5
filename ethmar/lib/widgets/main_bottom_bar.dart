import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// The tab type used by the bottom bar.
// ---------------------------------------------------------------------------

/// One tab of [LabeledNavBar].
class NavBarItem {
  const NavBarItem({
    required this.image,
    required this.label,
    this.selectedImage,
    this.tinted = true,
    this.iconSize = 28,
  });

  /// Picture in assets/images/ (without .png). This is the outline version
  /// when [selectedImage] is given.
  final String image;

  /// The filled version of [image], shown while this tab is open. If it's
  /// null, the open tab shows [image] too.
  final String? selectedImage;

  final String label;

  /// The picture to show for the tab's state.
  String imageFor({required bool selected}) =>
      selected ? (selectedImage ?? image) : image;

  /// The size of the box the picture fits in. Wide pictures need a bigger
  /// box to look the same size as the others.
  final double iconSize;

  /// Line icons are coloured to match the bar. A colourful picture (Your
  /// Farm's) keeps its own colours.
  final bool tinted;
}

// ---------------------------------------------------------------------------
// The bottom bar.
// ---------------------------------------------------------------------------

/// A white bar with each tab's icon above its name. The open tab shows its
/// filled icon in dark green, and the others show their outline icons in
/// grey. The tabs follow the reading direction (Home on the left in
/// English, on the right in Arabic).
class LabeledNavBar extends StatelessWidget {
  const LabeledNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          // Follows the reading direction: Home is on the left in English and on the
          // right in Arabic.
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _LabeledTab(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledTab extends StatelessWidget {
  const _LabeledTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : AppColors.textSecondary;
    Widget picture(String image) => Image.asset(
      'assets/images/$image.png',
      width: item.iconSize,
      height: item.iconSize,
      fit: BoxFit.contain,
      color: item.tinted ? color : null,
      colorBlendMode: item.tinted ? BlendMode.srcIn : null,
    );
    final outline = item.imageFor(selected: false);
    final filled = item.imageFor(selected: true);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      // heightFactor 1 keeps it only as tall as the tab. Without it, Center would
      // fill all the height the Scaffold gives a bottom bar (the whole screen).
      child: Center(
        heightFactor: 1,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 96),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Every icon gets the same height so the names line up.
                  SizedBox(
                    width: 40,
                    height: 28,
                    child: OverflowBox(
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: item.iconSize,
                      maxHeight: item.iconSize,
                      // Both pictures stay loaded in the same box, so switching tabs swaps them
                      // at once without a blank frame or a jump.
                      child: outline == filled
                          ? picture(outline)
                          : Stack(
                              children: [
                                Offstage(
                                  offstage: selected,
                                  child: picture(outline),
                                ),
                                Offstage(
                                  offstage: !selected,
                                  child: picture(filled),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: AppText.label(context, color: color).copyWith(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
