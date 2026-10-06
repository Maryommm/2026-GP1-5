import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ethmar_logo.dart';
import '../widgets/page_routes.dart';
import 'welcome_screen.dart';

/// 3-second animated splash, matching the approved video preview:
///  0.30–1.30s  word forms right → left
///  0.75–1.38s  plant-shaped Alif stem grows up from its base
///  1.22–1.82s  its two leaves unfold
///  1.60–2.26s  the three dots of ث fall like little leaves
///  2.70–3.00s  gentle fade, then the Welcome screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  @override
  void initState() {
    super.initState();
    // Don't start the clock until the first frame is actually on screen.
    // Otherwise the engine's start-up time eats the beginning of the
    // animation and it appears to begin half-way through.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(fadeRoute(const WelcomeScreen()));
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final logoW = math.min(w * 0.72, 420.0);
    // Extra room above the logo for the falling dots.
    final b = EthmarLogoData.bounds;
    final area = Rect.fromLTRB(b.left, b.top - 50, b.right, b.bottom);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: logoW,
          height: logoW * area.height / area.width,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: SplashLogoPainter(t: _c.value * 3.0, area: area),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

double _clamp01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
double _seg(double t, double a, double b) => _clamp01((t - a) / (b - a));
double _easeOutSine(double u) => math.sin(u * math.pi / 2);
double _easeInOutSine(double u) => -(math.cos(math.pi * u) - 1) / 2;
double _easeOutCubic(double u) => 1 - math.pow(1 - u, 3).toDouble();

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

// Regions (logo space) that split the plant-shaped Alif from the word.
final Path _leafLeft =
    _poly([140, 120, 215.5, 120, 215.5, 197, 206.5, 210, 206.5, 245, 140, 245]);
final Path _branchRight =
    _poly([215.5, 120, 320, 120, 320, 245, 230.5, 245, 230.5, 205, 215.5, 197]);
final Path _stem = _poly(
    [206.5, 210, 215.5, 197, 230.5, 205, 236, 205, 236, 270.5, 206.5, 270.5]);
final Path _plantArea = _poly([
  140,
  120,
  320,
  120,
  320,
  245,
  236,
  245,
  236,
  269.3,
  206.5,
  269.3,
  206.5,
  245,
  140,
  245,
]);

class _Dot {
  const _Dot(this.path, this.cx, this.cy, this.t0, this.rot, this.dx);
  final Path Function() path;
  final double cx, cy, t0, rot, dx;
}

final List<_Dot> _dots = [
  _Dot(() => EthmarLogoData.dotRight, 393, 256, 1.60, -14, 6),
  _Dot(() => EthmarLogoData.dotTop, 380, 236, 1.70, 10, -4),
  _Dot(() => EthmarLogoData.dotLeft, 362, 256, 1.80, 14, -6),
];

class SplashLogoPainter extends CustomPainter {
  SplashLogoPainter({required this.t, required this.area});

  final double t; // seconds, 0..3
  final Rect area;

  static const _color = AppColors.forest;

  Paint _fill(double opacity) => Paint()
    ..isAntiAlias = true
    ..color = _color.withAlpha((255 * _clamp01(opacity)).round());

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    applyLogoFit(canvas, size, content: area);

    final fade = 1 - _easeInOutSine(_seg(t, 2.70, 3.00));
    final done = t >= 1.84;

    // 1) Word forms from right to left (soft-edged wipe).
    final w = _easeOutSine(_seg(t, 0.30, 1.30));
    const feather = 34.0;
    final edge = 500 - (500 - 100 + feather) * w;
    final layerBounds = Rect.fromLTRB(
        area.left - 20, area.top - 20, area.right + 20, area.bottom + 20);

    if (w > 0) {
      canvas.saveLayer(layerBounds, Paint());
      final paint = _fill(fade);
      if (done) {
        canvas.drawPath(EthmarLogoData.body, paint);
      } else {
        canvas.save();
        canvas.clipPath(Path.combine(
          PathOperation.difference,
          Path()..addRect(layerBounds),
          _plantArea,
        ));
        canvas.drawPath(EthmarLogoData.body, paint);
        canvas.restore();
      }
      canvas.drawPath(EthmarLogoData.alif, paint);
      canvas.drawPath(EthmarLogoData.hamza, paint);
      canvas.drawPath(EthmarLogoData.ra, paint);
      // Mask: transparent left of the edge, opaque to its right.
      canvas.drawRect(
        layerBounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            colors: const [Color(0x00000000), Color(0xFF000000)],
          ).createShader(Rect.fromLTWH(edge, 0, feather, 1)),
      );
      canvas.restore();
    }

    if (!done) {
      // 2) Stem grows upward, base fixed, with a rounded shoot tip.
      final g = _easeInOutSine(_seg(t, 0.75, 1.38));
      final top = 271.5 - (271.5 - 186) * g;
      if (g > 0) {
        canvas.save();
        canvas.clipPath(_stem);
        canvas.clipRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(205, top, 238, 285),
          const Radius.elliptical(16.5, 11),
        ));
        canvas.drawPath(EthmarLogoData.body, _fill(fade));
        canvas.restore();
      }

      // Leaves unfold from the joint.
      void leaf(
          Path region, double t0, double t1, double px, double py, double r0) {
        final u = _easeOutCubic(_seg(t, t0, t1));
        if (u <= 0) return;
        final s = 0.08 + 0.92 * u;
        final r = r0 * (1 - u) * math.pi / 180;
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(r);
        canvas.scale(s);
        canvas.translate(-px, -py);
        canvas.clipPath(region);
        canvas.drawPath(EthmarLogoData.body, _fill(_clamp01(u * 3) * fade));
        canvas.restore();
      }

      leaf(_leafLeft, 1.22, 1.72, 209, 206, 38);
      leaf(_branchRight, 1.32, 1.82, 221, 201, -38);
    }

    // 3) Dots of ث fall like small leaves.
    for (final d in _dots) {
      final u = _seg(t, d.t0, d.t0 + 0.46);
      if (u <= 0) continue;
      final e = _easeOutCubic(u);
      final y = -46 * (1 - e);
      final sway = math.sin(u * math.pi * 1.5) * (1 - e);
      final x = d.dx * sway;
      final r = d.rot * math.cos(u * math.pi * 1.2) * (1 - e) * math.pi / 180;
      canvas.save();
      canvas.translate(x, y);
      canvas.translate(d.cx, d.cy);
      canvas.rotate(r);
      canvas.translate(-d.cx, -d.cy);
      canvas.drawPath(d.path(), _fill(_clamp01(u * 2.5) * fade));
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashLogoPainter old) => old.t != t;
}
