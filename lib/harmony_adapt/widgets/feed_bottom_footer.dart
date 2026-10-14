import 'package:flutter/material.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';

/// The list paints behind native navigation, but must scroll past its height.
/// Reserve a stable loading slot so finishing pagination does not snap the end.
class FeedBottomFooter extends StatelessWidget {
  const FeedBottomFooter({super.key, required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: 48,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: loading
              ? const RepaintBoundary(
                  key: ValueKey('feed-loading-more'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HarmonyLoadingIndicator(size: 22),
                      SizedBox(width: 8),
                      Text('正在加载…', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('feed-more-idle')),
        ),
      ),
    ),
  );
}
