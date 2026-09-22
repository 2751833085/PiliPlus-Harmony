import 'package:flutter/material.dart';
import '../harmony_theme.dart';

/// Grouped settings rows stay lazy even on long settings pages. Only the first
/// and last row in a section round their outer corners; dividers join the rest.
class HarmonySettingsList extends StatelessWidget {
  const HarmonySettingsList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.sectionBuilder,
    this.bareIndices = const {},
    this.padding = EdgeInsets.zero,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? Function(int index)? sectionBuilder;
  final Set<int> bareIndices;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final harmony = HarmonyStyle.enabled(context);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: harmony ? 840 : double.infinity),
        child: ListView.builder(
          padding:
              padding +
              (harmony
                  ? const EdgeInsets.fromLTRB(16, 8, 16, 20)
                  : EdgeInsets.zero),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final child = itemBuilder(context, index);
            if (!harmony || bareIndices.contains(index)) return child;
            final section = sectionBuilder?.call(index);
            final first =
                index == 0 ||
                bareIndices.contains(index - 1) ||
                sectionBuilder?.call(index - 1) != section;
            final last =
                index == itemCount - 1 ||
                bareIndices.contains(index + 1) ||
                sectionBuilder?.call(index + 1) != section;
            const radius = Radius.circular(20);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (first && section != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      section,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: first ? radius : Radius.zero,
                    bottom: last ? radius : Radius.zero,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      child,
                      if (!last)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1),
                        ),
                    ],
                  ),
                ),
                if (last) const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HarmonySettingsSearch extends StatelessWidget {
  const HarmonySettingsSearch({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '搜索设置',
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
