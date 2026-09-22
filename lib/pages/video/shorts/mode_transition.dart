import 'package:material_ui/material_ui.dart';

/// Fade through the layout change with only one live player in the tree.
/// Keeping both layouts in an AnimatedSwitcher would duplicate its GlobalKey.
class PlayerModeTransition extends StatefulWidget {
  const PlayerModeTransition({super.key, required this.child});
  final Widget child;

  @override
  State<PlayerModeTransition> createState() => PlayerModeTransitionState();
}

class PlayerModeTransitionState extends State<PlayerModeTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  bool _changing = false;

  Future<bool> change(VoidCallback updateLayout) async {
    if (_changing || !mounted) return false;
    if (MediaQuery.disableAnimationsOf(context)) {
      updateLayout();
      return true;
    }
    setState(() => _changing = true);
    try {
      await _controller
          .animateTo(0, duration: const Duration(milliseconds: 85))
          .orCancel;
      if (!mounted) return false;
      updateLayout();
      await _controller
          .animateTo(
            1,
            duration: const Duration(milliseconds: 195),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      return mounted;
    } on TickerCanceled {
      return false;
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: IgnorePointer(
      ignoring: _changing,
      child: FadeTransition(opacity: _controller, child: widget.child),
    ),
  );
}
