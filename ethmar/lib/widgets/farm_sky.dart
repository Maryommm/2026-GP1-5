import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/sun_times.dart';
import '../theme/app_colors.dart';

/// Virtual Farm's backdrop: a soft sky over rolling hills, by day or by
/// night. The same landscape in both, so night looks like the day scene
/// after sunset. Drawn to fill the screen; it doesn't move with the farm,
/// and it's only repainted when its size or phase changes.
///
/// Until [ready] (the real phase is known, see SkyClock.settled) nothing
/// is drawn, so the page's own cream shows for those few milliseconds
/// instead of the wrong scene. The first scene then appears as it is; only
/// later changes (sunrise, sunset) fade.
class FarmSky extends StatelessWidget {
  const FarmSky({super.key, required this.phase, this.ready = true});
  final SkyPhase phase;
  final bool ready;

  static const fade = Duration(milliseconds: 1200);

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox.expand();
    final night = phase == SkyPhase.night;
    // The day scene stays underneath; the night one fades in over it.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _SkyPainter(_SkyColors.day)),
          AnimatedOpacity(
            opacity: night ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : fade,
            curve: Curves.easeInOut,
            child: const CustomPaint(painter: _SkyPainter(_SkyColors.night)),
          ),
        ],
      ),
    );
  }
}

/// The colours of one version of the scene.
class _SkyColors {
  const _SkyColors({
    required this.sky,
    required this.farHill,
    required this.nearHill,
    required this.ground,
    required this.cloud,
    this.moonAndStars = false,
  });

  /// Top to bottom.
  final List<Color> sky;
  final Color farHill;
  final Color nearHill;

  /// What the hills fade into at the bottom of the screen.
  final Color ground;
  final Color cloud;

  final bool moonAndStars;

  static const day = _SkyColors(
    sky: [Color(0xFFD3F0EE), Color(0xFFE4F4EE), AppColors.background],
    farHill: Color(0xFFDCEDD6),
    nearHill: Color(0xFFCFE6C9),
    ground: AppColors.background,
    cloud: Color(0xB3FFFFFF),
  );

  static const night = _SkyColors(
    sky: [Color(0xFF303C74), Color(0xFF4A5894), Color(0xFF8A8FC6)],
    farHill: Color(0xFF4B5B98),
    nearHill: Color(0xFF55669F),
    ground: Color(0xFF8A8FC6),
    cloud: Color(0x2E9EA9D8),
    moonAndStars: true,
  );
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.colors);
  final _SkyColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final all = Offset.zero & size;

    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.sky,
          stops: const [0, 0.45, 1],
        ).createShader(all),
    );

    // Sizes follow the shorter side, so tablets and phones look alike.
    final unit = math.min(w, h * 0.6);

    if (colors.moonAndStars) _stars(canvas, size, unit);

    // A few small, faint clouds, low in the sky.
    final cloud = Paint()..color = colors.cloud;
    _cloud(canvas, Offset(w * 0.2, h * 0.22), unit * 0.3, cloud);
    _cloud(canvas, Offset(w * 0.86, h * 0.2), unit * 0.26, cloud);
    _cloud(canvas, Offset(w * 0.6, h * 0.25), unit * 0.16, cloud);

    // The moon sits above the clouds, clear of the header.
    if (colors.moonAndStars) {
      _moon(canvas, Offset(w * 0.76, h * 0.145), unit * 0.05);
    }

    // Two rolling hills, fading into the ground lower down.
    _hill(canvas, size, h * 0.31, h * 0.035, 0.4, colors.farHill);
    _hill(canvas, size, h * 0.37, h * 0.04, 2.1, colors.nearHill);
  }

  void _hill(
    Canvas canvas,
    Size size,
    double top,
    double rise,
    double phase,
    Color color,
  ) {
    final w = size.width, h = size.height;
    double y(double x) {
      final t = x / w * 2 * math.pi;
      return top +
          rise * (0.65 * math.sin(t * 0.9 + phase) +
              0.35 * math.sin(t * 1.7 + phase * 1.3));
    }

    final path = Path()..moveTo(0, y(0));
    const steps = 48;
    for (var i = 1; i <= steps; i++) {
      final x = w * i / steps;
      path.lineTo(x, y(x));
    }
    path
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final area = Rect.fromLTRB(0, top - rise, w, h);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color, colors.ground.withValues(alpha: 0)],
          stops: const [0, 0.35, 0.8],
        ).createShader(area),
    );
  }

  /// A soft, flat cloud: a long base with low bumps, [width] wide.
  void _cloud(Canvas canvas, Offset at, double width, Paint paint) {
    final r = width / 8;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: width, height: r * 1.1),
          Radius.circular(r * 0.55),
        ),
      )
      ..addOval(
        Rect.fromCircle(center: at + Offset(-r * 1.4, -r * 0.4), radius: r),
      )
      ..addOval(
        Rect.fromCircle(center: at + Offset(r * 0.2, -r * 0.8), radius: r * 1.4),
      )
      ..addOval(
        Rect.fromCircle(center: at + Offset(r * 1.8, -r * 0.3), radius: r * 0.9),
      );
    // One shape, so overlaps aren't darker.
    path.fillType = PathFillType.nonZero;
    canvas.drawPath(path, paint);
  }

  /// A small crescent moon with a faint glow.
  void _moon(Canvas canvas, Offset at, double r) {
    canvas.drawCircle(
      at,
      r * 3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.22),
            const Color(0x00FFF3C4),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r * 3)),
    );
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: at, radius: r)),
      Path()..addOval(
        Rect.fromCircle(center: at + Offset(r * 0.45, -r * 0.3), radius: r),
      ),
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFF5E6B8));
  }

  /// A few small, faint stars in the upper sky; the same ones every time.
  void _stars(Canvas canvas, Size size, double unit) {
    final rand = math.Random(11);
    final paint = Paint();
    for (var i = 0; i < 22; i++) {
      final at = Offset(
        rand.nextDouble() * size.width,
        size.height * (0.03 + rand.nextDouble() * 0.27),
      );
      paint.color = Colors.white.withValues(
        alpha: 0.3 + rand.nextDouble() * 0.4,
      );
      canvas.drawCircle(at, unit * (0.0018 + rand.nextDouble() * 0.0022), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.colors != colors;
}
