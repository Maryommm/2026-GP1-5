import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Current design: the tab type shared by the labeled and pill bars.
// ---------------------------------------------------------------------------

/// One tab of [LabeledNavBar] or [PillNavBar].
class NavBarItem {
  const NavBarItem({
    required this.image,
    required this.label,
    this.tinted = true,
    this.iconSize = 28,
  });

  /// Picture in assets/images/ (without .png).
  final String image;
  final String label;

  /// Box the picture fits in; wide or padded pictures need a bigger one to
  /// look the same size as the others.
  final double iconSize;

  /// Line-art icons are tinted to the bar's colours; a colourful picture
  /// (Your Farm's) keeps its own colours.
  final bool tinted;
}

// ---------------------------------------------------------------------------
// Labeled bar (navBarStyle = NavBarStyle.labeled in app_layout.dart).
// ---------------------------------------------------------------------------

/// A white bar with each tab's icon above its name. The open tab sits on a
/// pale-green rounded square, in dark green; the others are grey. Same tab
/// order in both languages.
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
          child: Row(
            textDirection: TextDirection.ltr,
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
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      // heightFactor 1: only as tall as the tab. Without it Center fills
      // all the height the Scaffold allows a bottom bar (the whole screen).
      child: Center(
        heightFactor: 1,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 96),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.forestTint : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The same height for every icon, so the names line up;
                  // pictures with empty space around them spill over it.
                  SizedBox(
                    width: 40,
                    height: 28,
                    child: OverflowBox(
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: item.iconSize,
                      maxHeight: item.iconSize,
                      child: Image.asset(
                        'assets/images/${item.image}.png',
                        width: item.iconSize,
                        height: item.iconSize,
                        fit: BoxFit.contain,
                        color: item.tinted ? color : null,
                        colorBlendMode: item.tinted ? BlendMode.srcIn : null,
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

// ---------------------------------------------------------------------------
// Pill bar (navBarStyle = NavBarStyle.pills in app_layout.dart).
// ---------------------------------------------------------------------------

/// A floating light-green pill with one circle per tab. The open tab grows
/// into a wider pill: its icon on a white circle, and its name beside it.
/// The tabs keep the same order in both languages; the name follows the
/// reading direction.
///
/// MainShell lets the page run behind it (Scaffold.extendBody), so the
/// page shows around the pill and keeps clear of it through the bottom
/// padding.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _circle = 56.0;
  static const _gap = 8.0;
  static const _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(_inset),
          decoration: BoxDecoration(
            color: AppColors.featureCard,
            borderRadius: BorderRadius.circular(_circle),
            // A faint edge and shadow lift it off the cream pages.
            border: Border.all(color: AppColors.forest.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The open tab takes whatever the other circles leave.
              final open = constraints.maxWidth -
                  (items.length - 1) * (_circle + _gap);
              return Row(
                textDirection: TextDirection.ltr,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    _PillTab(
                      item: items[i],
                      selected: i == currentIndex,
                      width: i == currentIndex ? open : _circle,
                      onTap: () => onSelect(i),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.item,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    const size = PillNavBar._circle;
    final icon = Image.asset(
      'assets/images/${item.image}.png',
      width: item.iconSize,
      height: item.iconSize,
      fit: BoxFit.contain,
      color: !item.tinted
          ? null
          : selected
          ? AppColors.forest
          : AppColors.forest.withValues(alpha: 0.6),
      colorBlendMode: item.tinted ? BlendMode.srcIn : null,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          width: width,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(size),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(size),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: _duration,
                    curve: _curve,
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : null,
                      shape: BoxShape.circle,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.forest.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: icon,
                  ),
                  // The name, only on the open tab; it fades in as the pill
                  // grows and never wraps.
                  Expanded(
                    child: AnimatedOpacity(
                      duration: _duration,
                      opacity: selected ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 16,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: AppText.label(
                            context,
                            color: AppColors.forest,
                          ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
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

// ---------------------------------------------------------------------------
// Raised-button bar (navBarStyle = NavBarStyle.centerButton): Home and Ask
// Thamoor on the bar, and Your Farm as a big round button in the middle,
// raised above it ([FarmCenterButton], docked by MainShell).
// ---------------------------------------------------------------------------

/// The bar under the farm button: Home on the left and Ask Thamoor on the
/// right (same sides in both languages), with a gap in the middle for the
/// button. Icons only; their names are read out by screen readers and shown
/// on a long press.
class FarmCenterBottomBar extends StatelessWidget {
  const FarmCenterBottomBar({
    super.key,
    required this.homeSelected,
    required this.chatSelected,
    required this.onHome,
    required this.onChat,
  });

  final bool homeSelected;
  final bool chatSelected;
  final VoidCallback onHome;
  final VoidCallback onChat;

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
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              _IconTab(
                image: 'ethmar_homepage_icon',
                label: s.navHome,
                selected: homeSelected,
                onTap: onHome,
              ),
              // Room for the farm button.
              const SizedBox(width: FarmCenterButton.size + 24),
              _IconTab(
                image: 'ethmar_chatbot_icon',
                // Wide, detailed drawing: a bigger box so it looks the same
                // size as the house.
                iconWidth: 50,
                iconHeight: 38,
                label: s.navAskThamoor,
                selected: chatSelected,
                onTap: onChat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big round Your Farm button that sits on the middle of the bar, with
/// the colourful "Grow a Plant" picture (a plant and a "+", hinting that
/// plants are added there): pale green, and pale yellow (like the other
/// selected tabs) while the farm is open. Place it with [location].
class FarmCenterButton extends StatelessWidget {
  const FarmCenterButton({
    super.key,
    required this.selected,
    required this.onTap,
  });

  static const size = 72.0;

  /// How far the button's centre sits below the bar's top edge, so only
  /// part of it rises above the bar.
  static const drop = 16.0;

  /// How much of the button shows above the bar.
  static const rise = size / 2 - drop;

  /// Docked in the middle of the bar, [drop] lower than Flutter's
  /// centerDocked.
  static const FloatingActionButtonLocation location = _LoweredCenterDocked();

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = S.of(context).navVirtualFarm;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Pale yellow while open, like the other selected tabs.
            color: selected ? AppColors.sunTint : AppColors.forestTint,
            shape: BoxShape.circle,
            // A white ring separates it from the bar and the page behind.
            border: Border.all(color: AppColors.surface, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              // Home's former "Grow a Plant" picture, in colour: the plant
              // with its own "+".
              child: Center(
                child: Image.asset(
                  'assets/images/ethmar_add_plant_icon.png',
                  // The picture has empty space around it, so a big box.
                  width: 62,
                  height: 62,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flutter's centerDocked, moved [FarmCenterButton.drop] lower.
class _LoweredCenterDocked extends FloatingActionButtonLocation {
  const _LoweredCenterDocked();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final docked = FloatingActionButtonLocation.centerDocked.getOffset(
      geometry,
    );
    return docked.translate(0, FarmCenterButton.drop);
  }
}

/// A bar icon without a name under it; the selected one sits on the same
/// pale-yellow pill as in the classic bar.
class _IconTab extends StatelessWidget {
  const _IconTab({
    required this.image,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconWidth = 36,
    this.iconHeight = 36,
  });

  final String image;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double iconWidth;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 56,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 76,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sunTint : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'assets/images/$image.png',
                    width: iconWidth,
                    height: iconHeight,
                    fit: BoxFit.contain,
                    color: AppColors.forest,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Classic design (useClassicLayout = true), unchanged.
// ---------------------------------------------------------------------------

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
