import 'package:flutter/material.dart';

/// Fades + lifts a child in after [delay]. Kept short and small so screens
/// settle calmly. Shows the child straight away when the system asks for
/// reduced motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.offset = 12});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Runs 0→1 once after [delay]; handy for the self-drawing squiggle.
class DelayedProgress extends StatefulWidget {
  const DelayedProgress({super.key, required this.builder, this.delay = Duration.zero,
      this.duration = const Duration(milliseconds: 700)});
  final Widget Function(BuildContext, double) builder;
  final Duration delay;
  final Duration duration;

  @override
  State<DelayedProgress> createState() => _DelayedProgressState();
}

class _DelayedProgressState extends State<DelayedProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (ctx, _) => widget.builder(ctx, Curves.easeInOut.transform(_c.value)),
      );
}
