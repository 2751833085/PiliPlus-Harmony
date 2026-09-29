import 'package:flutter/material.dart';

/// Immediate navigation, retaining visited pages and their scroll positions.
class CachedNavigationView extends StatefulWidget {
  const CachedNavigationView({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  State<CachedNavigationView> createState() => _CachedNavigationViewState();
}

class _CachedNavigationViewState extends State<CachedNavigationView> {
  final Set<int> _visited = {};
  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          _visited.contains(index)
              ? HeroMode(
                  enabled: index == widget.index,
                  child: TickerMode(
                    enabled: index == widget.index,
                    child: RepaintBoundary(child: widget.children[index]),
                  ),
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}
