import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shared corner radius for buttons and text fields.
const kControlRadius = BorderRadius.all(Radius.circular(16));

/// Big friendly button with soft rounded corners and a gentle "press" squish.
///
/// * Primary: solid forest, flat.
/// * [outlined]: a quieter tinted button (no hard border), for secondary actions.
class EthmarButton extends StatefulWidget {
  const EthmarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.showArrow = false,
    this.loading = false,
    this.color,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool showArrow;
  final bool loading;

  /// Optional overrides, e.g. for buttons sitting on a dark card.
  final Color? color;
  final Color? textColor;

  @override
  State<EthmarButton> createState() => _EthmarButtonState();
}

class _EthmarButtonState extends State<EthmarButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = !widget.outlined;
    final enabled = widget.onPressed != null;
    final fg = widget.textColor ?? (primary ? AppColors.onForest : AppColors.forest);
    final bg = widget.color ?? (primary ? AppColors.forest : AppColors.forestTint);

    final label = widget.loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.button(context, color: fg)),
              ),
              if (widget.showArrow) ...[
                const SizedBox(width: 8),
                // arrow_forward flips automatically in Arabic (RTL).
                Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: enabled ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 150),
            child: Material(
              color: bg,
              borderRadius: kControlRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.loading ? null : widget.onPressed,
                splashColor: primary ? const Color(0x22FFFFFF) : const Color(0x14152C14),
                highlightColor: Colors.transparent,
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: label),
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

/// Small text link, e.g. "Log in" / "Forgot password?".
/// Always at least 48px tall so it's easy to tap.
class EthmarLink extends StatelessWidget {
  const EthmarLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppText.label(context).copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.forest,
                decorationThickness: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain back arrow with a 48px tap area (arrow flips in Arabic).
class EthmarBackButton extends StatelessWidget {
  const EthmarBackButton({super.key, required this.tooltip});
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
    );
  }
}
