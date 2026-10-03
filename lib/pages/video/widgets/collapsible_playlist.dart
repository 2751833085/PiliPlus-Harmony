import 'package:flutter/material.dart';
import 'package:PiliPlus/pages/episode_panel/layout.dart';

/// Build the expensive episode list only while it is open, with bounded height.
class CollapsiblePlaylist extends StatefulWidget {
  const CollapsiblePlaylist({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<CollapsiblePlaylist> createState() => _CollapsiblePlaylistState();
}

class _CollapsiblePlaylistState extends State<CollapsiblePlaylist>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _keepContent = false;
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 240),
      )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && !_expanded && mounted) {
          setState(() => _keepContent = false);
        }
      });
  late final _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _keepContent = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('播放列表'),
            leading: const Icon(Icons.playlist_play),
            trailing: AnimatedRotation(
              turns: _expanded ? .5 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.expand_more),
            ),
            onTap: _toggle,
          ),
          SizeTransition(
            sizeFactor: _progress,
            alignment: Alignment.topCenter,
            child: !_keepContent
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, bounds) => SizedBox(
                      height: EpisodeLayout.playlistHeight(
                        MediaQuery.sizeOf(context),
                        bounds.maxWidth,
                      ),
                      child: widget.builder(context),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
