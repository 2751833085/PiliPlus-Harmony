import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The side column switches independently; the player and comments stay mounted.
class TabletVideoSidebar extends StatelessWidget {
  const TabletVideoSidebar({
    super.key,
    required this.expanded,
    required this.header,
    required this.playlistBuilder,
    required this.related,
    required this.hasPlaylist,
    this.playlistPending = false,
  });
  final ValueNotifier<bool> expanded;
  final Widget header;
  final WidgetBuilder playlistBuilder;
  final Widget related;
  final bool hasPlaylist;
  final bool playlistPending;

  double _headerHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: '合集', style: Theme.of(context).textTheme.bodyMedium),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = math.max(48.0, painter.height + 32);
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, open, _) => Column(
        children: [
          if (hasPlaylist || playlistPending)
            SizedBox(
              height: _headerHeight(context),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: hasPlaylist ? 1 : 0),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                builder: (_, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: !hasPlaylist
                    ? const SizedBox.expand()
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => expanded.value = !open,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              children: [
                                Expanded(child: IgnorePointer(child: header)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Icon(
                                    open
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    semanticLabel: open ? '收起合集' : '查看全部',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              layoutBuilder: (current, previous) =>
                  current ?? const SizedBox.shrink(),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation.drive(Tween(begin: .8, end: 1.0)),
                child: child,
              ),
              child: open && hasPlaylist
                  ? KeyedSubtree(
                      key: const ValueKey('playlist'),
                      child: playlistBuilder(context),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('related'),
                      child: related,
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

abstract final class TabletVideoLayout {
  static bool enabled(Size window) =>
      window.width >= 680 && window.height >= 560;
  static double sidebarWidth(double width) => (width * .365).clamp(260, 440);
}
