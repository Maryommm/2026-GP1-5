import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'logo_paths.dart';

/// The Ethmar logo, parsed from the original SVG paths.
///
/// Everything is converted into "logo space": the SVG's 600 x 450 viewBox,
/// with y pointing down (like the screen).
class EthmarLogoData {
  EthmarLogoData._();

  static final List<Path> _paths = kEthmarSvgPaths.map((d) {
    // The SVG group transform: translate(0,450) scale(0.1,-0.1)
    final m = Float64List.fromList(<double>[
      0.1, 0, 0, 0, //
      0, -0.1, 0, 0, //
      0, 0, 1, 0, //
      0, 450, 0, 1, //
    ]);
    return parseSvgPath(d).transform(m);
  }).toList(growable: false);

  static Path get body => _paths[0]; // word body + plant-shaped Alif
  static Path get alif => _paths[1]; // right-most Alif (إ)
  static Path get dotTop => _paths[2]; // top dot of ث
  static Path get ra => _paths[3]; // ر
  static Path get dotRight => _paths[4];
  static Path get dotLeft => _paths[5];
  static Path get hamza => _paths[6]; // hamza under إ

  static List<Path> get all => _paths;

  /// Area of logo space that contains the logo (with a little air).
  static const Rect bounds = Rect.fromLTRB(96, 146, 496, 322);
}

/// Scales logo space into a widget of any size, centred.
void applyLogoFit(Canvas canvas, Size size, {Rect content = EthmarLogoData.bounds}) {
  final scale = (size.width / content.width) < (size.height / content.height)
      ? size.width / content.width
      : size.height / content.height;
  final dx = (size.width - content.width * scale) / 2;
  final dy = (size.height - content.height * scale) / 2;
  canvas.translate(dx, dy);
  canvas.scale(scale);
  canvas.translate(-content.left, -content.top);
}

/// Static logo (used in headers).
class EthmarLogo extends StatelessWidget {
  const EthmarLogo({super.key, this.width = 120, this.color = AppColors.forest});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = EthmarLogoData.bounds;
    return Semantics(
      label: 'Ethmar إثمار',
      image: true,
      child: SizedBox(
        width: width,
        height: width * b.height / b.width,
        child: CustomPaint(painter: _StaticLogoPainter(color)),
      ),
    );
  }
}

class _StaticLogoPainter extends CustomPainter {
  _StaticLogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    applyLogoFit(canvas, size);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    for (final p in EthmarLogoData.all) {
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaticLogoPainter old) => old.color != color;
}

/// Minimal SVG path-data parser (M, L, H, V, C, S, Q, Z – absolute & relative).
/// Enough for the Ethmar logo, no extra package needed.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsQqZz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();

  var i = 0;
  var cmd = 'M';
  double x = 0, y = 0, startX = 0, startY = 0;
  double lastCx = 0, lastCy = 0;

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
    }
    switch (cmd) {
      case 'M':
      case 'm': {
        final nx = n(), ny = n();
        x = cmd == 'm' ? x + nx : nx;
        y = cmd == 'm' ? y + ny : ny;
        path.moveTo(x, y);
        startX = x;
        startY = y;
        // Extra pairs after a move are treated as line-to.
        cmd = cmd == 'm' ? 'l' : 'L';
        lastCx = x;
        lastCy = y;
        break;
      }
      case 'L':
      case 'l': {
        final nx = n(), ny = n();
        x = cmd == 'l' ? x + nx : nx;
        y = cmd == 'l' ? y + ny : ny;
        path.lineTo(x, y);
        lastCx = x;
        lastCy = y;
        break;
      }
      case 'H':
      case 'h': {
        final nx = n();
        x = cmd == 'h' ? x + nx : nx;
        path.lineTo(x, y);
        lastCx = x;
        lastCy = y;
        break;
      }
      case 'V':
      case 'v': {
        final ny = n();
        y = cmd == 'v' ? y + ny : ny;
        path.lineTo(x, y);
        lastCx = x;
        lastCy = y;
        break;
      }
      case 'C':
      case 'c': {
        final rel = cmd == 'c';
        final x1 = n() + (rel ? x : 0.0), y1 = n() + (rel ? y : 0.0);
        final x2 = n() + (rel ? x : 0.0), y2 = n() + (rel ? y : 0.0);
        final ex = n() + (rel ? x : 0.0), ey = n() + (rel ? y : 0.0);
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lastCx = x2;
        lastCy = y2;
        x = ex;
        y = ey;
        break;
      }
      case 'S':
      case 's': {
        final rel = cmd == 's';
        final x1 = 2 * x - lastCx, y1 = 2 * y - lastCy;
        final x2 = n() + (rel ? x : 0.0), y2 = n() + (rel ? y : 0.0);
        final ex = n() + (rel ? x : 0.0), ey = n() + (rel ? y : 0.0);
        path.cubicTo(x1, y1, x2, y2, ex, ey);
        lastCx = x2;
        lastCy = y2;
        x = ex;
        y = ey;
        break;
      }
      case 'Q':
      case 'q': {
        final rel = cmd == 'q';
        final x1 = n() + (rel ? x : 0.0), y1 = n() + (rel ? y : 0.0);
        final ex = n() + (rel ? x : 0.0), ey = n() + (rel ? y : 0.0);
        path.quadraticBezierTo(x1, y1, ex, ey);
        lastCx = x1;
        lastCy = y1;
        x = ex;
        y = ey;
        break;
      }
      case 'Z':
      case 'z': {
        path.close();
        x = startX;
        y = startY;
        lastCx = x;
        lastCy = y;
        // Guard against malformed data (numbers straight after Z).
        if (i < tokens.length && !isCmd(tokens[i])) cmd = 'l';
        break;
      }
      default:
        i++;
    }
  }
  return path;
}
