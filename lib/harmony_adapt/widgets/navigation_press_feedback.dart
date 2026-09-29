import 'package:material_ui/material_ui.dart';

/// Feedback stays local to a destination; never translates the navigation bar.
class NavigationPressFeedback extends StatefulWidget {
  const NavigationPressFeedback({super.key, required this.child});
  final Widget child;

  @override
  State<NavigationPressFeedback> createState() =>
      _NavigationPressFeedbackState();
}

class _NavigationPressFeedbackState extends State<NavigationPressFeedback> {
  final Set<int> _pointers = {};

  void _release(PointerEvent event) {
    if (_pointers.remove(event.pointer)) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) => setState(() => _pointers.add(event.pointer)),
      onPointerUp: _release,
      onPointerCancel: _release,
      child: ImmersiveInteraction(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: AnimatedScale(
          scale: !reduceMotion && _pointers.isNotEmpty ? .94 : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
