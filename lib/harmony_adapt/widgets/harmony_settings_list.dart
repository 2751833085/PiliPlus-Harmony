import 'package:flutter/material.dart';
import '../harmony_theme.dart';

/// Lazily built, bounded panels avoid enormous rows on a three-panel display.
class HarmonySettingsList extends StatelessWidget {
  const HarmonySettingsList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final harmony = HarmonyStyle.enabled(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: harmony ? 840 : double.infinity),
        child: ListView.builder(
          padding:
              padding +
              (harmony
                  ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
                  : EdgeInsets.zero),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final child = itemBuilder(context, index);
            if (!harmony) return child;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: HarmonyTheme.cardRadius,
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
