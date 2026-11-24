import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ethmar_buttons.dart';

/// The app's page header (the Profile design): the title centred on the
/// screen, the back button on the reading start side and optional actions
/// on the end side (Back left / actions right in English, mirrored in
/// Arabic). An optional hand-written [subtitle] sits centred under the
/// title.
///
/// The title stays centred whatever is on the sides: both sides take the
/// width of the wider one (at least [_minSideWidth]), so one back button
/// against two action buttons doesn't push the title off centre.
class EthmarCenteredHeader extends StatelessWidget {
  const EthmarCenteredHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
    this.titleColor,
  });
  final String title;

  /// The title's colour over a dark page; the usual text colour otherwise.
  final Color? titleColor;

  /// A short hand-written line under the title (e.g. "who's growing the
  /// most?").
  final String? subtitle;

  /// Actions on the end side: a button, or a row of them.
  final Widget? trailing;

  /// False on the main tabs, where there is nothing to go back to. The
  /// slot keeps its width, so the title stays centred.
  final bool showBack;

  /// Each side is at least this wide, so short titles sit in the same place
  /// on every screen.
  static const _minSideWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    final end = trailing;
    final sub = subtitle;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        8,
      ),
      child: _CenteredRow(
        minSideWidth: _minSideWidth,
        start: showBack ? EthmarBackButton(tooltip: S.of(context).back) : null,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Long titles (e.g. "تعديل الملف الشخصي") shrink a little on
            // narrow phones instead of being cut off.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: AppText.title(
                  context,
                  color: titleColor,
                ).copyWith(fontSize: 22),
              ),
            ),
            if (sub != null)
              Text(
                sub,
                textAlign: TextAlign.center,
                style: AppText.accent(context, size: 16),
              ),
          ],
        ),
        // Very wide actions shrink rather than squeeze the title.
        end: end == null
            ? null
            : FittedBox(fit: BoxFit.scaleDown, child: end),
      ),
    );
  }
}

enum _Slot { start, title, end }

/// Lays out [start], [title] and [end] in a row with [title] centred on the
/// whole row: both sides are as wide as the wider of the two (at least
/// [minSideWidth], at most a third of the row), and the title gets the
/// width left between them. [start] is on the reading start side.
class _CenteredRow extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _CenteredRow({
    required this.minSideWidth,
    required this.title,
    this.start,
    this.end,
  });
  final double minSideWidth;
  final Widget title;
  final Widget? start;
  final Widget? end;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.start => start,
    _Slot.title => title,
    _Slot.end => end,
  };

  @override
  _RenderCenteredRow createRenderObject(BuildContext context) =>
      _RenderCenteredRow(
        minSideWidth: minSideWidth,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCenteredRow renderObject,
  ) {
    renderObject
      ..minSideWidth = minSideWidth
      ..textDirection = Directionality.of(context);
  }
}

class _RenderCenteredRow extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderCenteredRow({
    required double minSideWidth,
    required TextDirection textDirection,
  }) : _minSideWidth = minSideWidth,
       _textDirection = textDirection;

  /// The header is never shorter than a back button.
  static const _minHeight = 48.0;

  double _minSideWidth;
  set minSideWidth(double value) {
    if (value == _minSideWidth) return;
    _minSideWidth = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _start => childForSlot(_Slot.start);
  RenderBox? get _title => childForSlot(_Slot.title);
  RenderBox? get _end => childForSlot(_Slot.end);

  /// Sizes the children with [layoutChild] and returns the row's size, the
  /// side width, and each child's size.
  ({Size size, double side, Size start, Size title, Size end}) _measure(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
  ) {
    final width = constraints.maxWidth;
    // At most a third each, so the title always keeps a third of the row.
    final sideLimit = BoxConstraints(maxWidth: width / 3);
    final startBox = _start;
    final endBox = _end;
    final titleBox = _title;
    final start = startBox == null
        ? Size.zero
        : layoutChild(startBox, sideLimit);
    final end = endBox == null ? Size.zero : layoutChild(endBox, sideLimit);
    final side = [
      _minSideWidth,
      start.width,
      end.width,
    ].reduce((a, b) => a > b ? a : b).clamp(0.0, width / 3);
    final title = titleBox == null
        ? Size.zero
        : layoutChild(
            titleBox,
            BoxConstraints(maxWidth: (width - 2 * side).clamp(0.0, width)),
          );
    final height = [
      _minHeight,
      start.height,
      end.height,
      title.height,
    ].reduce((a, b) => a > b ? a : b);
    return (
      size: constraints.constrain(Size(width, height)),
      side: side,
      start: start,
      title: title,
      end: end,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _measure(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'The header needs a bounded width.');
    final m = _measure(constraints, ChildLayoutHelper.layoutChild);
    size = m.size;
    final width = size.width;
    final ltr = _textDirection == TextDirection.ltr;
    double middle(Size child) => (size.height - child.height) / 2;

    void place(RenderBox? box, Offset offset) {
      if (box != null) (box.parentData! as BoxParentData).offset = offset;
    }

    // Start at the reading start edge, end at the other edge, title in the
    // middle of the whole row.
    place(
      _start,
      Offset(ltr ? 0 : width - m.start.width, middle(m.start)),
    );
    place(_end, Offset(ltr ? width - m.end.width : 0, middle(m.end)));
    place(
      _title,
      Offset((width - m.title.width) / 2, middle(m.title)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    (box) => box.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    (box) => box.getMaxIntrinsicHeight(width),
  );

  double _intrinsicHeight(double Function(RenderBox) heightOf) => [
    _minHeight,
    for (final box in children) heightOf(box),
  ].reduce((a, b) => a > b ? a : b);

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth(
    (box) => box.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth(
    (box) => box.getMaxIntrinsicWidth(height),
  );

  double _intrinsicWidth(double Function(RenderBox) widthOf) {
    final startBox = _start;
    final endBox = _end;
    final titleBox = _title;
    final side = [
      _minSideWidth,
      if (startBox != null) widthOf(startBox),
      if (endBox != null) widthOf(endBox),
    ].reduce((a, b) => a > b ? a : b);
    return 2 * side + (titleBox == null ? 0 : widthOf(titleBox));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final box in children) {
      context.paintChild(box, offset + (box.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final box in children.toList().reversed) {
      final hit = result.addWithPaintOffset(
        offset: (box.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            box.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
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
