import 'native_loading_opacity.dart';
import 'package:flutter/services.dart';
import 'package:os_type/os_type.dart';
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
    this.opacity = 1,
  });
  final double size;
  final Color? color;
  final double? value;
  final double opacity;

  @override
  State<HarmonyLoadingIndicator> createState() =>
      _HarmonyLoadingIndicatorState();
}

class _HarmonyLoadingIndicatorState extends State<HarmonyLoadingIndicator>
    with TickerProviderStateMixin {
  final _nativeOpacity = NativeLoadingOpacity();

  late final _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _entryStarted = false;
  late final _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_sendOpacity);

  double get _alpha =>
      widget.opacity.clamp(0.0, 1.0) * Curves.easeInOut.transform(_entry.value);

  void _sendOpacity() => _nativeOpacity.update(_alpha);

  void _startEntry() {
    _entryStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
    } else {
      _entry.forward(from: 0);
    }
  }

  void _syncAnimation() {
    if (!OS.isHarmony &&
        widget.value == null &&
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
    if (!OS.isHarmony && !_entryStarted) _startEntry();
    if (_entryStarted && MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
    }
  }

  @override
  void didUpdateWidget(HarmonyLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
    _sendOpacity();
  }

  @override
  void dispose() {
    _nativeOpacity.dispose();
    _orbit.dispose();
    _entry.dispose();
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
        child: OS.isHarmony
            ? LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1 || constraints.maxHeight < 1)
                    return const SizedBox.shrink();
                  final color =
                      (widget.color ?? Theme.of(context).colorScheme.primary)
                          .toARGB32();
                  final animate =
                      widget.value == null &&
                      !MediaQuery.disableAnimationsOf(context) &&
                      TickerMode.of(context);
                  return IgnorePointer(
                    child: OhosView(
                      key: ValueKey((color, animate)),
                      viewType: 'piliplus/native-loading',
                      creationParamsCodec: const StandardMessageCodec(),
                      creationParams: {
                        'color': color,
                        'animate': animate,
                        'opacity': 0.0,
                      },
                      onPlatformViewCreated: (id) {
                        if (!mounted) return;
                        // Native creation may finish after the pull is armed.
                        // Begin at zero only once the actual surface is ready.
                        _entry.value = 0;
                        _sendOpacity();
                        _nativeOpacity.attach(id);
                        _startEntry();
                      },
                    ),
                  );
                },
              )
            : AnimatedBuilder(
                animation: _entry,
                builder: (context, child) =>
                    Opacity(opacity: _alpha, child: child),
                child: CustomPaint(
                  painter: _PlanetPainter(
                    _orbit,
                    widget.color ?? Theme.of(context).colorScheme.primary,
                    widget.value,
                  ),
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
