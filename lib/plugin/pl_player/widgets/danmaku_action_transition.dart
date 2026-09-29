import 'package:flutter/widgets.dart';

/// Animate the anchored menu without moving its position relative to a danmaku.
/// Outgoing actions stop accepting input immediately, while their pixels fade.
class DanmakuActionTransition extends StatelessWidget {
  const DanmakuActionTransition({super.key, required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
      reverseDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 130),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: FadeTransition(opacity: animation, child: child),
        builder: (_, child) => IgnorePointer(
          ignoring: animation.status == AnimationStatus.reverse,
          child: child,
        ),
      ),
      child: child ?? const SizedBox.expand(key: ValueKey('closed')),
    );
  }
}
