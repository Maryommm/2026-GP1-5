import 'package:flutter/material.dart';

import '../models/daily_task.dart' show TaskType;
import 'ethmar_logo.dart' show parseSvgPath;

/// The icon of a care task, the same everywhere in the app: a water drop
/// for watering and a fertilizer bag ([FertilizerIcon]) for fertilizing.
class CareTypeIcon extends StatelessWidget {
  const CareTypeIcon(this.type, {super.key, this.size = 24, this.color});

  final TaskType type;
  final double size;

  /// Defaults to the surrounding icon colour.
  final Color? color;

  @override
  Widget build(BuildContext context) => switch (type) {
    TaskType.watering => Icon(
      Icons.water_drop_rounded,
      size: size,
      color: color,
    ),
    TaskType.fertilizing => FertilizerIcon(size: size, color: color),
  };
}

/// A fertilizer bag icon with a leaf on the front (Material doesn't have
/// one). Use [CareTypeIcon] to pick the icon by task type.
class FertilizerIcon extends StatelessWidget {
  const FertilizerIcon({super.key, this.size = 24, this.color});
  final double size;

  /// Defaults to the surrounding icon colour, like an [Icon].
  final Color? color;

  // Drawn on a 24 × 24 grid, like Material icons.
  static final _path = parseSvgPath(
    // Tied top.
    'M9 6L8 2.8L10.5 4.1L12 2.4L13.5 4.1L16 2.8L15 6Z'
    // Tie band.
    'M8.6 6.3H15.4A0.7 0.7 0 0 1 15.4 7.7H8.6A0.7 0.7 0 0 1 8.6 6.3Z'
    // Bag.
    'M7.2 8.2C4.6 10.3 4 14 4.5 18C4.8 20.4 6.5 21.6 8.6 21.6H15.4'
    'C17.5 21.6 19.2 20.4 19.5 18C20 14 19.4 10.3 16.8 8.2Z'
    // A leaf cut out of the bag, with its middle vein. It's a leaf and not a
    // drop so it isn't confused with watering.
    'M9.2 18.4C9.2 14.6 11.4 12.4 15.2 12.1C15.2 15.9 13 18.2 9.2 18.4Z'
    'M9.7 17.7L13.6 13.5L14 13.9L10.1 18.1Z',
  );

  @override
  Widget build(BuildContext context) {
    final paint = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FertilizerPainter(_path, paint)),
    );
  }
}

class _FertilizerPainter extends CustomPainter {
  const _FertilizerPainter(this.path, this.color);
  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    // evenOdd makes the leaf a hole in the bag.
    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FertilizerPainter old) => old.color != color;
}
