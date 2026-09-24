import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'dart:math' as math;
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/mine/recent_history.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:material_ui/material_ui.dart';

class MineHistoryPreview extends StatelessWidget {
  const MineHistoryPreview({
    super.key,
    required this.history,
    this.expanded = false,
    required this.onOpen,
    required this.onViewAll,
    required this.onLogin,
  });
  final RecentHistory history;
  final bool expanded;
  final ValueChanged<HistoryItemModel> onOpen;
  final VoidCallback onViewAll, onLogin;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: history,
    builder: (context, _) {
      if (!history.enabled) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: history.loggedIn ? onViewAll : onLogin,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '观看历史',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (history.loggedIn)
                  Builder(
                    builder: (context) {
                      final button = IconButton(
                        tooltip: '刷新观看历史',
                        onPressed: history.loading ? null : history.refresh,
                        icon: const Icon(Icons.refresh, size: 20),
                      );
                      return HarmonyStyle.enabled(context)
                          ? ImmersiveSurface(
                              borderRadius: BorderRadius.circular(24),
                              child: button,
                            )
                          : button;
                    },
                  ),
              ],
            ),
          ),
          if (!history.loggedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextButton(
                onPressed: onLogin,
                child: const Text('登录后查看观看历史'),
              ),
            )
          else if (history.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                history.error ?? (history.loading ? '正在读取观看历史…' : '暂无观看历史'),
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context);
                final width = expanded
                    ? (constraints.maxWidth - 54) / 2
                    : math.min(
                        192.0,
                        math.max(120.0, constraints.maxWidth - 48),
                      );
                // Text layout rounds each line independently. Reserve whole
                // line boxes so fractional font scales cannot overflow.
                final height =
                    width * 9 / 16 +
                    (scale.scale(14) * 1.35).ceilToDouble() * 2 +
                    (scale.scale(12) * 1.35).ceilToDouble() +
                    28;
                Widget buildItem(BuildContext context, int index) {
                  final item = history.items[index];
                  final progress = item.progress == -1
                      ? '已看完'
                      : item.duration != null && item.duration! > 0
                      ? '${DurationUtils.formatDuration(item.progress ?? 0)} / ${DurationUtils.formatDuration(item.duration)}'
                      : item.authorName ?? item.badge ?? '继续观看';
                  return SizedBox(
                    width: width,
                    child: Semantics(
                      button: true,
                      label: '继续观看：${item.title ?? '视频'}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpen(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: NetworkImgLayer(
                                src: item.cover?.isNotEmpty == true
                                    ? item.cover
                                    : item.covers?.firstOrNull,
                                width: width,
                                height: width * 9 / 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title ?? '视频',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              progress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (expanded) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    itemCount: math.min(6, history.items.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: height,
                    ),
                    itemBuilder: buildItem,
                  );
                }
                return SizedBox(
                  height: height,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: history.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: buildItem,
                  ),
                );
              },
            ),
          if (history.error != null && history.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(history.error!, style: theme.textTheme.bodySmall),
            ),
        ],
      );
    },
  );
}
