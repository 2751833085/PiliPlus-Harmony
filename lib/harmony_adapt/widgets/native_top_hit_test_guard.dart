import 'package:flutter/widgets.dart';

/// Native ArkUI controls and Flutter can receive the same physical pointer.
/// Unlike a sliver spacer, this invisible hit region never scrolls out of view.
/// It adds no layout space and exists only on the retained home page.
class NativeTopHitTestGuard extends StatelessWidget {
  const NativeTopHitTestGuard({
    super.key,
    required this.active,
    required this.hideTopBar,
    required this.collapsed,
    required this.scaleFactor,
    required this.child,
  });
  final bool active;
  final bool hideTopBar;
  final bool collapsed;
  final double scaleFactor;
  final Widget child;

  // These dimensions include the status/header area and mirror Index.ets.
  // Do not substitute NativeTopSpacer's content-only sliver dimensions here.
  static double extent({
    required bool hideTopBar,
    required bool collapsed,
    required double scaleFactor,
  }) {
    final scale = scaleFactor.isFinite && scaleFactor > 0 ? scaleFactor : 1.0;
    return (hideTopBar && collapsed ? 80.0 : 144.0) / scale;
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      if (active)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedContainer(
            // Native host geometry animates on collapse even though this widget
            // paints nothing. Scale changes instead take effect immediately.
            key: ValueKey(scaleFactor),
            duration: const Duration(milliseconds: 300),
            curve: const Cubic(.2, 0, 0, 1),
            height: extent(
              hideTopBar: hideTopBar,
              collapsed: collapsed,
              scaleFactor: scaleFactor,
            ),
            child: const AbsorbPointer(child: SizedBox.expand()),
          ),
        ),
    ],
  );
}
