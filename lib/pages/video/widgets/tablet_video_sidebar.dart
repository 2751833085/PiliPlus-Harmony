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
            Row(
              children: [
                Expanded(child: header),
                IconButton(
                  tooltip: open ? '收起合集' : '查看全部',
                  onPressed: () => expanded.value = !open,
                  icon: Icon(open ? Icons.close : Icons.playlist_play),
                ),
              ],
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              layoutBuilder: (current, previous) =>
                  current ?? const SizedBox.shrink(),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
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
