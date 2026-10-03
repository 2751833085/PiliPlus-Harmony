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
  });
  final ValueNotifier<bool> expanded;
  final Widget header;
  final WidgetBuilder playlistBuilder;
  final Widget related;
  final bool hasPlaylist;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, open, _) => Column(
        children: [
          if (hasPlaylist)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => expanded.value = !open,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(child: IgnorePointer(child: header)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          open ? Icons.expand_less : Icons.expand_more,
                          semanticLabel: open ? '收起合集' : '查看全部',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
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
