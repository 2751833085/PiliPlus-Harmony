import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        title: const Text('播放列表'),
        leading: const Icon(Icons.playlist_play),
        trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
        onTap: () => setState(() => _expanded = !_expanded),
      ),
      if (_expanded)
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * .45).clamp(180.0, 400.0),
          child: widget.builder(context),
        ),
    ],
  );
}
