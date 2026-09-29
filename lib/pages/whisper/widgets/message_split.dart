import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';
import 'package:material_ui/material_ui.dart';

/// Both slots keep their position in the tree when folding. The hidden list
/// keeps a valid width so offstage layout never squeezes its rows to zero.
class MessageSplit extends StatefulWidget {
  const MessageSplit({
    super.key,
    required this.split,
    required this.hasSelection,
    required this.list,
    required this.detail,
    this.selectionKey,
  });
  final bool split, hasSelection;
  final Widget list, detail;
  final Object? selectionKey;

  @override
  State<MessageSplit> createState() => _MessageSplitState();
}

class _MessageSplitState extends State<MessageSplit>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: HarmonyMotion.duration,
    value: widget.hasSelection ? 0 : 1,
  );
  late final _position = _animation
      .drive(CurveTween(curve: HarmonyMotion.curve))
      .drive(Tween(begin: const Offset(1, 0), end: Offset.zero));
  @override
  void initState() {
    super.initState();
    if (widget.hasSelection) _animation.forward();
  }

  @override
  void didUpdateWidget(MessageSplit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasSelection &&
        (!oldWidget.hasSelection ||
            oldWidget.selectionKey != widget.selectionKey)) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final listWidth = widget.split ? 352.0 : bounds.maxWidth;
      final detailLeft = widget.split ? listWidth + 1 : 0.0;
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: listWidth,
            child: AnimatedBuilder(
              animation: _animation,
              child: widget.list,
              builder: (context, child) => Offstage(
                offstage:
                    !widget.split &&
                    widget.hasSelection &&
                    _animation.isCompleted,
                child: IgnorePointer(
                  ignoring: !widget.split && widget.hasSelection,
                  child: child!,
                ),
              ),
            ),
          ),
          Positioned(
            left: listWidth,
            top: 0,
            bottom: 0,
            width: widget.split ? 1 : 0,
            child: VerticalDivider(
              width: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: .12),
            ),
          ),
          Positioned(
            left: detailLeft,
            right: 0,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: !widget.split && !widget.hasSelection,
              child: ClipRect(
                child: SlideTransition(
                  position: MediaQuery.disableAnimationsOf(context)
                      ? const AlwaysStoppedAnimation(Offset.zero)
                      : _position,
                  child: RepaintBoundary(child: widget.detail),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
