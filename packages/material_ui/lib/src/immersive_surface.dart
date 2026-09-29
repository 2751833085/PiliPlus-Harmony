import 'dart:ui' show ImageFilter;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'popup_surface.dart' show PopupSurfaceStyle;

/// One clipped backdrop per surface. High contrast and reduced motion
/// use an opaque fill; content and hit targets are unchanged.
class ImmersiveSurface extends StatelessWidget {
  const ImmersiveSurface({
    super.key,
    required this.child,
    this.color,
    this.blurBackground = false,
    this.interactive = true,
    this.allowMovement = false,
    this.showBorder = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });
  final bool interactive;
  final bool allowMovement;
  final bool showBorder;
  final Widget child;
  final Color? color;

  /// Page surfaces default to a cached finish. Opt in only for overlays
  /// that actually need to sample the content behind them.
  final bool blurBackground;

  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.surface;
    final immersive =
        theme.extension<PopupSurfaceStyle>() != null &&
        !MediaQuery.highContrastOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    final content = Material(type: MaterialType.transparency, child: child);
    final surface = ClipRRect(
      borderRadius: borderRadius,
      child: immersive
          ? _withBlur(
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: !showBorder
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? .12
                                : .75,
                          ),
                        ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (theme.brightness == Brightness.dark
                              ? const Color(0xFF25262A)
                              : const Color(0xFFF7F8FA))
                          .withValues(alpha: .82),
                      (theme.brightness == Brightness.dark
                              ? const Color(0xFF25262A)
                              : const Color(0xFFF7F8FA))
                          .withValues(alpha: .72),
                    ],
                  ),
                ),
                child: content,
              ),
            )
          : ColoredBox(color: base, child: content),
    );
    return interactive
        ? ImmersiveInteraction(
            borderRadius: borderRadius,
            allowMovement: allowMovement,
            child: surface,
          )
        : surface;
  }

  Widget _withBlur(Widget child) => blurBackground
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: child,
        )
      : RepaintBoundary(child: child);
}

/// Pointer feedback never joins the gesture arena: scrolling, sliders and
/// button actions retain their own recognizers. Only the deepest surface responds. Movement is opt-in for search fields.
class ImmersiveInteraction extends StatefulWidget {
  const ImmersiveInteraction({
    super.key,
    required this.child,
    this.allowMovement = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });
  final Widget child;

  /// Reserved for search fields. Panels and controls only track touch light.
  final bool allowMovement;
  final BorderRadius borderRadius;
  @override
  State<ImmersiveInteraction> createState() => _ImmersiveInteractionState();
}

class _ImmersiveInteractionState extends State<ImmersiveInteraction>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _owners = <int, _ImmersiveInteractionState>{};
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(_tick);
  final _revision = ValueNotifier<int>(0);
  int? _pointer;
  Offset _start = Offset.zero, _point = Offset.zero, _shift = Offset.zero;
  Offset _released = Offset.zero;
  double _light = 0;
  bool _enabled = false;
  @override
  void initState() {
    super.initState();
    _motion; // Initialize ticker while the element is active, never in dispose.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        Theme.of(context).extension<PopupSurfaceStyle>() != null &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.highContrastOf(context);
    if (!enabled) _reset();
    _enabled = enabled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _reset();
  }

  void _reset() {
    _owners.removeWhere((_, value) => identical(value, this));
    _pointer = null;
    _motion.stop();
    _shift = Offset.zero;
    _light = 0;
    _revision.value++;
  }

  void _tick() {
    final t = _motion.value;
    _shift = _released * (math.exp(-7 * t) * math.cos(10 * t));
    _light = (1 - t).clamp(0.0, 1.0);
    if (t == 1) {
      _shift = Offset.zero;
      _light = 0;
    }
    _revision.value++;
  }

  void _down(PointerDownEvent e) {
    if (!_enabled || _pointer != null || _owners.containsKey(e.pointer)) return;
    _owners[e.pointer] = this;
    _pointer = e.pointer;
    _motion.stop();
    _start = _point = e.localPosition;
    _shift = Offset.zero;
    _light = 1;
    _revision.value++;
  }

  void _move(PointerMoveEvent e) {
    if (_pointer != e.pointer) return;
    _point = e.localPosition;
    final delta = e.localPosition - _start;
    // Beyond a small exploratory pull, leave scrolling/slider gestures alone.
    if (delta.distance > 22) {
      _release(e);
      return;
    }
    _shift = widget.allowMovement
        ? Offset(delta.dx * .18, delta.dy * .18)
        : Offset.zero;
    _revision.value++;
  }

  void _release(PointerEvent e) {
    if (_pointer != e.pointer) return;
    _owners.remove(e.pointer);
    _pointer = null;
    _released = _shift;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _owners.removeWhere((_, value) => identical(value, this));
    _motion.dispose();
    _revision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _release,
    onPointerCancel: _release,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _revision,
        child: widget.child,
        builder: (_, child) => Transform.translate(
          offset: _shift,
          child: CustomPaint(
            foregroundPainter: _TouchLight(_point, _light, widget.borderRadius),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _TouchLight extends CustomPainter {
  _TouchLight(this.point, this.strength, this.radius);
  final Offset point;
  final double strength;
  final BorderRadius radius;
  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;
    canvas.save();
    canvas.clipRRect(radius.toRRect(Offset.zero & size));
    final extent = math.min(110.0, math.max(32.0, size.shortestSide * 1.4));
    canvas.drawCircle(
      point,
      extent,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .20 * strength),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: point, radius: extent)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TouchLight old) =>
      old.point != point || old.strength != strength || old.radius != radius;
}
