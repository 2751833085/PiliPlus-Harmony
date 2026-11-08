import 'package:flutter/material.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';

/// First-load handoff: one centered indicator leaves before the feed fades in.
/// Existing data refreshes stay in the scroll view and retain their position.
class InitialFeedContent extends StatefulWidget {
  const InitialFeedContent({
    super.key,
    required this.loading,
    required this.builder,
    this.onReady,
  }) : _sliver = false;

  /// Keeps headers, scroll position and lazy result rows in their viewport.
  const InitialFeedContent.sliver({
    super.key,
    required this.loading,
    required this.builder,
  }) : _sliver = true,
       onReady = null;
  final bool _sliver;
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
    child: Builder(builder: widget.builder),
    builder: (context, content) {
      final progress = _transition.value;
      final showLoading = progress <= .35;
      if (showLoading) {
        final indicator = IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.1),
              child: HarmonyLoadingIndicator(
                size: 32,
                opacity: (1 - progress / .35).clamp(0.0, 1.0),
              ),
            ),
          ),
        );
        return widget._sliver
            ? SliverFillRemaining(hasScrollBody: false, child: indicator)
            : SizedBox.expand(child: indicator);
      }
      final opacity = Curves.easeOut.transform(
        ((progress - .35) / .65).clamp(0.0, 1.0),
      );
      return widget._sliver
          ? SliverOpacity(opacity: opacity, sliver: content)
          : SizedBox.expand(
              child: Opacity(
                opacity: opacity,
                child: RepaintBoundary(child: content!),
              ),
            );
    },
  );
}
