import 'dart:math' as math;
import 'package:PiliPlus/pages/video/shorts/metrics.dart';
import 'package:material_ui/material_ui.dart';

/// Resizes the existing video above comments (beside them on expanded screens).
/// The closing panel stays mounted until its animation completes.
class ShortCommentsLayout extends StatefulWidget {
  const ShortCommentsLayout({
    super.key,
    required this.panel,
    required this.builder,
  });
  final Widget? panel;
  final Widget Function(BuildContext context, bool compact) builder;
  @override
  State<ShortCommentsLayout> createState() => _ShortCommentsLayoutState();
}

class _ShortCommentsLayoutState extends State<ShortCommentsLayout>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.panel == null ? 0 : 1,
  );
  late Widget? _panel = widget.panel;
  @override
  void didUpdateWidget(ShortCommentsLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panel != null) _panel = widget.panel;
    if ((oldWidget.panel == null) == (widget.panel == null)) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = widget.panel == null ? 0 : 1;
      _panel = widget.panel;
    } else if (widget.panel != null) {
      _animation.forward();
    } else {
      _animation.reverse().then((_) {
        if (mounted && widget.panel == null) setState(() => _panel = null);
      });
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final side =
            size.maxWidth >= 700 ||
            (size.maxWidth >= 600 && size.maxWidth > size.maxHeight);
        final metrics = ShortVideoMetrics.of(context);
        final minimumVideo = metrics.footerHeight + metrics.controlHeight + 96;
        final extent = side
            ? math.min(420.0, size.maxWidth * .42)
            : math.min(
                size.maxHeight * .66,
                math.max(
                  0.0,
                  size.maxHeight - math.min(minimumVideo, size.maxHeight * .7),
                ),
              );
        final occupied =
            extent * Curves.easeOutCubic.transform(_animation.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              right: side ? occupied : 0,
              bottom: side ? 0 : occupied,
              child: widget.builder(context, _panel != null),
            ),
            if (_panel != null)
              Positioned(
                right: side ? occupied - extent : 0,
                left: side ? null : 0,
                bottom: side ? 0 : occupied - extent,
                top: side ? 0 : null,
                width: side ? extent : null,
                height: side ? null : extent,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  child: _panel!,
                ),
              ),
          ],
        );
      },
    ),
  );
}
