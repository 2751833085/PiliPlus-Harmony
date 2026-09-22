import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../harmony_channel.dart';

/// Moves only the existing controls. A seek/drag keeps its original geometry.
class HarmonyHandDock extends StatefulWidget {
  const HarmonyHandDock({
    super.key,
    required this.enabled,
    required this.width,
    required this.builder,
    this.preserveWidth = false,
  });
  final bool enabled;

  /// A seek timeline must retain the full playback viewport on either hand.
  final bool preserveWidth;
  final double width;
  final Widget Function(double width) builder;
  @override
  State<HarmonyHandDock> createState() => _HarmonyHandDockState();
}

class _HarmonyHandDockState extends State<HarmonyHandDock> {
  final Set<int> _pointers = {};
  HarmonyHandSide _side = HarmonyChannel.handSide.value;
  @override
  void initState() {
    super.initState();
    HarmonyChannel.handSide.addListener(_changed);
  }

  void _changed() {
    if (_pointers.isEmpty && _side != HarmonyChannel.handSide.value)
      setState(() => _side = HarmonyChannel.handSide.value);
  }

  void _release(PointerEvent e) {
    _pointers.remove(e.pointer);
    _changed();
  }

  @override
  void dispose() {
    HarmonyChannel.handSide.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        widget.enabled && !widget.preserveWidth && widget.width >= 600;
    final width = active
        ? math.min(
            widget.width,
            640 * MediaQuery.textScalerOf(context).scale(14) / 14,
          )
        : widget.width;
    final alignment = !active
        ? Alignment.center
        : switch (_side) {
            HarmonyHandSide.left => Alignment.centerLeft,
            HarmonyHandSide.right => Alignment.centerRight,
            HarmonyHandSide.center => Alignment.center,
          };
    return Listener(
      onPointerDown: (e) => _pointers.add(e.pointer),
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedAlign(
        alignment: alignment,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        heightFactor: 1,
        child: SizedBox(width: width, child: widget.builder(width)),
      ),
    );
  }
}
