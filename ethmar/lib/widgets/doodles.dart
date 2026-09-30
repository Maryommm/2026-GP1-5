import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Wavy hand-drawn underline that "draws itself" in.
/// The one playful mark on the Sign up and Log in screens.
class SquiggleUnderline extends StatelessWidget {
  const SquiggleUnderline({super.key, required this.progress, this.color = AppColors.coral, this.width = 170});
  final double progress; // 0..1
  final Color color;
  final double width;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return CustomPaint(
      size: Size(width, 12),
      painter: _SquigglePainter(progress, color, rtl),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.progress, this.color, this.rtl);
  final double progress;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size s) {
    if (progress <= 0) return;
    final path = Path();
    const waves = 5;
    final seg = s.width / waves;
    path.moveTo(0, s.height * 0.6);
    for (var i = 0; i < waves; i++) {
      final x0 = i * seg;
      path.quadraticBezierTo(x0 + seg * 0.25, s.height * (i.isEven ? 0.05 : 0.95),
          x0 + seg * 0.5, s.height * 0.55);
      path.quadraticBezierTo(x0 + seg * 0.75, s.height * (i.isEven ? 0.95 : 0.1),
          x0 + seg, s.height * 0.5);
    }
    if (rtl) {
      // Draw from right to left in Arabic.
      canvas.translate(s.width, 0);
      canvas.scale(-1, 1);
    }
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      partial,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SquigglePainter old) =>
      old.progress != progress || old.color != color || old.rtl != rtl;
}
