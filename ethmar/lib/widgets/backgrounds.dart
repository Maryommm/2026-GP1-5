import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Very faint green leaf prints on sand, used behind every screen.
/// Stays fixed behind [child] while it scrolls.
class LeafPrintBackground extends StatelessWidget {
  const LeafPrintBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(
            color: AppColors.background,
            child: RepaintBoundary(
                child: CustomPaint(painter: _LeafPrintPainter())),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Scattered little leaves, sprouts and dots in forest green at ~5% opacity.
class _LeafPrintPainter extends CustomPainter {
  const _LeafPrintPainter();

  static const _tile = 96.0;
  static const _ink = Color(0x0F152C14); // forest @ ~6%

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final fill = Paint()..color = _ink;

    final cols = (size.width / _tile).ceil() + 1;
    final rows = (size.height / _tile).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Same pseudo-random layout every time, so it doesn't jump.
        final rnd = math.Random(r * 131 + c * 17 + 7);
        final offsetRow = r.isOdd ? _tile / 2 : 0.0;
        final x = c * _tile + offsetRow + rnd.nextDouble() * 26 - 13;
        final y = r * _tile + rnd.nextDouble() * 26 - 13;
        final angle = rnd.nextDouble() * math.pi * 2;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        switch (rnd.nextInt(3)) {
          case 0:
            _leaf(canvas, stroke, 22);
          case 1:
            _sprout(canvas, stroke, 18);
          default:
            _leaf(canvas, stroke, 14);
        }
        canvas.restore();
        // A tiny seed-dot between prints.
        canvas.drawCircle(Offset(x + _tile * 0.45, y + _tile * 0.5), 1.8, fill);
      }
    }
  }

  // Almond leaf with a centre vein.
  void _leaf(Canvas canvas, Paint p, double len) {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.42, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.42, 0, 0);
    canvas.drawPath(path, p);
    canvas.drawLine(Offset.zero, Offset(len * 0.8, 0), p);
  }

  // Short stem with two little leaves.
  void _sprout(Canvas canvas, Paint p, double h) {
    canvas.drawLine(Offset.zero, Offset(0, -h), p);
    final l = Path()
      ..moveTo(0, -h * 0.55)
      ..quadraticBezierTo(-h * 0.45, -h * 0.95, -h * 0.55, -h * 0.55)
      ..quadraticBezierTo(-h * 0.3, -h * 0.4, 0, -h * 0.55);
    final r = Path()
      ..moveTo(0, -h * 0.75)
      ..quadraticBezierTo(h * 0.45, -h * 1.15, h * 0.55, -h * 0.75)
      ..quadraticBezierTo(h * 0.3, -h * 0.6, 0, -h * 0.75);
    canvas.drawPath(l, p);
    canvas.drawPath(r, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
