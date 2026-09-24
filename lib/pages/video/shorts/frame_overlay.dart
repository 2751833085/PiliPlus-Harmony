import 'package:flutter/widgets.dart';

/// Paint the preview ABOVE the reused native texture until this source has a
/// frame. Keep two composited frames before fading, including after reparenting.
class ShortFrameOverlay extends StatefulWidget {
  const ShortFrameOverlay({
    super.key,
    required this.ready,
    required this.child,
  });
  final bool ready;
  final Widget child;
  @override
  State<ShortFrameOverlay> createState() => _ShortFrameOverlayState();
}

class _ShortFrameOverlayState extends State<ShortFrameOverlay> {
  bool _revealed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(ShortFrameOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) _update();
  }

  void _update() {
    final generation = ++_generation;
    if (!widget.ready) {
      _revealed = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation && widget.ready) {
          setState(() => _revealed = true);
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      opacity: _revealed ? 0 : 1,
      duration: _revealed ? const Duration(milliseconds: 120) : Duration.zero,
      child: widget.child,
    ),
  );
}
