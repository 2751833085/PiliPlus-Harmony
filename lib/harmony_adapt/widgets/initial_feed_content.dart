import 'package:flutter/material.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';

/// First-load handoff: one bottom indicator leaves before the feed fades in.
/// Existing data refreshes stay in the scroll view and retain their position.
class InitialFeedContent extends StatefulWidget {
  const InitialFeedContent({
    super.key,
    required this.loading,
    required this.builder,
    this.onReady,
  });
  final bool loading;
  final WidgetBuilder builder;
  final VoidCallback? onReady;
  @override
  State<InitialFeedContent> createState() => _InitialFeedContentState();
}

class _InitialFeedContentState extends State<InitialFeedContent>
    with SingleTickerProviderStateMixin {
  late final _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.loading ? 0 : 1,
  );
  @override
  void didUpdateWidget(InitialFeedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) {
      if (widget.loading) {
        _transition.value = 0;
      } else if (MediaQuery.disableAnimationsOf(context)) {
        _transition.value = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.loading) widget.onReady?.call();
        });
      } else {
        _transition.forward().whenComplete(() {
          if (mounted && !widget.loading) widget.onReady?.call();
        });
      }
    }
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _transition,
    builder: (context, _) {
      final progress = _transition.value;
      return SizedBox.expand(
        child: Stack(
          children: [
            if (progress > .35)
              Positioned.fill(
                child: Opacity(
                  opacity: Curves.easeOut.transform(
                    ((progress - .35) / .65).clamp(0.0, 1.0),
                  ),
                  child: widget.builder(context),
                ),
              ),
            if (progress <= .35)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 116,
                      ),
                      child: Opacity(
                        opacity: (1 - progress / .35).clamp(0.0, 1.0),
                        child: const HarmonyLoadingIndicator(size: 32),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
