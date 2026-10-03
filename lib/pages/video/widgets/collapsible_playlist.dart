import 'package:flutter/material.dart';
import 'package:PiliPlus/pages/episode_panel/layout.dart';

/// Build the expensive episode list only while it is open, with bounded height.
class CollapsiblePlaylist extends StatefulWidget {
  const CollapsiblePlaylist({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<CollapsiblePlaylist> createState() => _CollapsiblePlaylistState();
}

class _CollapsiblePlaylistState extends State<CollapsiblePlaylist> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: const Text('播放列表'),
            leading: const Icon(Icons.playlist_play),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            LayoutBuilder(
              builder: (context, bounds) => SizedBox(
                height: EpisodeLayout.playlistHeight(
                  MediaQuery.sizeOf(context),
                  bounds.maxWidth,
                ),
                child: widget.builder(context),
              ),
            ),
        ],
      ),
    ),
  );
}
