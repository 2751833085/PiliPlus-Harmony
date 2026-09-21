import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small orbital indicator. Only the paint layer ticks; lists do not rebuild.
/// A value renders pull/determinate progress without running another ticker.
class HarmonyLoadingIndicator extends StatefulWidget {
  const HarmonyLoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.value,
  });
  final double size;
  final Color? color;
  final double? value;

  @override
  State<HarmonyLoadingIndicator> createState() =>
      _HarmonyLoadingIndicatorState();
}

class _HarmonyLoadingIndicatorState extends State<HarmonyLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  void _syncAnimation() {
    if (widget.value == null &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context)) {
      if (!_orbit.isAnimating) _orbit.repeat();
    } else {
      _orbit.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(HarmonyLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载',
    value: widget.value == null
        ? null
        : '${(widget.value!.clamp(0.0, 1.0) * 100).round()}%',
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _PlanetPainter(
            _orbit,
            widget.color ?? Theme.of(context).colorScheme.primary,
            widget.value,
          ),
        ),
      ),
    ),
  );
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.orbit, this.color, this.value) : super(repaint: orbit);
  final Animation<double> orbit;
  final Color color;
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) * .34;
    final angle = (value?.clamp(0.0, 1.0) ?? orbit.value) * math.pi * 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 7);
    final oval = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2,
      height: radius * 1.12,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.shortestSide * .035)
      ..color = color.withValues(alpha: .35);
    canvas.drawOval(oval, ring);
    final dot = Offset(
      math.cos(angle) * radius,
      math.sin(angle) * radius * .56,
    );
    final dotRadius = size.shortestSide * (.055 + .016 * (math.sin(angle) + 1));
    final planet = Paint()..color = color;
    if (dot.dy < 0) canvas.drawCircle(dot, dotRadius, planet);
    canvas.drawCircle(Offset.zero, radius * .45, planet);
    if (dot.dy >= 0) canvas.drawCircle(dot, dotRadius, planet);
  }

  @override
  bool shouldRepaint(_PlanetPainter old) =>
      old.color != color || old.value != value || old.orbit != orbit;
}
