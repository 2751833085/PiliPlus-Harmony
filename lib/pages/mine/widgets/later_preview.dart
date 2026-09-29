import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:material_ui/material_ui.dart';

class MineLaterPreviewList extends StatelessWidget {
  const MineLaterPreviewList({
    super.key,
    required this.items,
    required this.onOpen,
  });
  final List<LaterItemModel> items;
  final ValueChanged<LaterItemModel> onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height:
          110 +
          8 +
          16 +
          (MediaQuery.textScalerOf(
                        context,
                      ).scale(theme.textTheme.bodyMedium?.fontSize ?? 14) *
                      (theme.textTheme.bodyMedium?.height ?? 1.5))
                  .ceilToDouble() *
              2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: 180,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onOpen(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NetworkImgLayer(src: item.pic, width: 180, height: 110),
                  const SizedBox(height: 8),
                  Text(
                    item.title ?? '视频',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
