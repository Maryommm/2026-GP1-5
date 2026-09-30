import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows the Ethmar character from `assets/images/<name>.png`.
///
/// Until the real illustration is added, a friendly placeholder
/// "plant buddy" is drawn instead, so the app always runs.
/// It also bobs gently, like it's breathing.
class EthmarCharacter extends StatefulWidget {
  const EthmarCharacter({super.key, required this.name, this.height = 220, this.bob = true});

  /// File name without extension, e.g. 'character_welcome'.
  final String name;
  final double height;
  final bool bob;

  @override
  State<EthmarCharacter> createState() => _EthmarCharacterState();
}

class _EthmarCharacterState extends State<EthmarCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.bob) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/${widget.name}.png',
      height: widget.height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(
        height: widget.height,
        width: widget.height * 0.8,
        child: const CustomPaint(painter: _PlantBuddyPainter()),
      ),
    );
    if (!widget.bob || MediaQuery.disableAnimationsOf(context)) return image;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, -6 * v), child: child);
      },
      child: image,
    );
  }
}

/// Placeholder mascot: a smiling terracotta pot with a sprout.
class _PlantBuddyPainter extends CustomPainter {
  const _PlantBuddyPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final cx = w / 2;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.95), width: w * 0.62, height: h * 0.05),
      Paint()..color = const Color(0x22152C14),
    );

    // Stem
    final stem = Paint()
      ..color = AppColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(cx, h * 0.52)
      ..quadraticBezierTo(cx - w * 0.03, h * 0.36, cx, h * 0.22);
    canvas.drawPath(stemPath, stem);

    // Leaves
    void leaf(Offset base, double len, double angle, Color color) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.42, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.32, 0, 0)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
      canvas.restore();
    }

    leaf(Offset(cx, h * 0.3), w * 0.34, -math.pi * 0.85, AppColors.sea);
    leaf(Offset(cx, h * 0.26), w * 0.38, -math.pi * 0.18, AppColors.seaDark);
    leaf(Offset(cx, h * 0.23), w * 0.16, -math.pi * 0.5, AppColors.sea);

    // Pot
    final potTop = h * 0.52;
    final pot = Path()
      ..moveTo(cx - w * 0.3, potTop + h * 0.08)
      ..lineTo(cx + w * 0.3, potTop + h * 0.08)
      ..lineTo(cx + w * 0.23, h * 0.93)
      ..quadraticBezierTo(cx, h * 0.96, cx - w * 0.23, h * 0.93)
      ..close();
    canvas.drawPath(pot, Paint()..color = AppColors.coral);
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w * 0.36, potTop, cx + w * 0.36, potTop + h * 0.1),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(rim, Paint()..color = AppColors.coralDark);

    // Face
    final eye = Paint()..color = AppColors.forest;
    final eyeY = h * 0.72;
    canvas.drawCircle(Offset(cx - w * 0.09, eyeY), w * 0.028, eye);
    canvas.drawCircle(Offset(cx + w * 0.09, eyeY), w * 0.028, eye);
    canvas.drawCircle(Offset(cx - w * 0.08, eyeY - w * 0.01), w * 0.009, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + w * 0.10, eyeY - w * 0.01), w * 0.009, Paint()..color = Colors.white);
    final smile = Path()
      ..moveTo(cx - w * 0.05, h * 0.78)
      ..quadraticBezierTo(cx, h * 0.815, cx + w * 0.05, h * 0.78);
    canvas.drawPath(
      smile,
      Paint()
        ..color = AppColors.forest
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round,
    );
    // Cheeks
    final cheek = Paint()..color = const Color(0x66FFC93C);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.16, h * 0.77), width: w * 0.08, height: w * 0.045), cheek);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + w * 0.16, h * 0.77), width: w * 0.08, height: w * 0.045), cheek);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
