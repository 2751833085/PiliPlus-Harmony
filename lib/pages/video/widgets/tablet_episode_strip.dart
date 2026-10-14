import 'package:flutter/material.dart';

/// A bounded, lazy horizontal selector beneath the wide-screen player.
class TabletEpisodeStrip extends StatefulWidget {
  const TabletEpisodeStrip({
    super.key,
    required this.title,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.onExpand,
  });
  final String title;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onExpand;

  @override
  State<TabletEpisodeStrip> createState() => _TabletEpisodeStripState();
}

class _TabletEpisodeStripState extends State<TabletEpisodeStrip> {
  final _scroll = ScrollController();
  static const _extent = 176.0;
  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(TabletEpisodeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.labels.length != widget.labels.length) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.selectedIndex < 0) return;
      _scroll.jumpTo(
        (widget.selectedIndex * _extent).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height = 28.0 + MediaQuery.textScalerOf(context).scale(28);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.playlist_play, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.onExpand != null)
                    TextButton.icon(
                      onPressed: widget.onExpand,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: Text('展开全部 · ${widget.labels.length}'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: height,
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _extent,
                  itemCount: widget.labels.length,
                  itemBuilder: (context, index) {
                    final selected = index == widget.selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        selected: selected,
                        child: Material(
                          color: selected
                              ? colors.secondaryContainer
                              : colors.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: selected
                                  ? colors.primary.withValues(alpha: .65)
                                  : colors.outlineVariant.withValues(
                                      alpha: .75,
                                    ),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: selected
                                ? null
                                : () => widget.onSelected(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${index + 1}. ${widget.labels[index]}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: selected
                                        ? colors.onSecondaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
