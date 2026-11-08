import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/subscription_detail/view.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SubItem extends StatelessWidget {
  final SubItemModel item;
  final VoidCallback cancelSub;
  const SubItem({
    super.key,
    required this.item,
    required this.cancelSub,
  });

  @override
  Widget build(BuildContext context) {
    final id = item.id;
    final heroTag = Utils.makeHeroTag(id);
    final type = switch (item.type) {
      11 => '收藏夹',
      21 => '合集',
      _ => '其它(${item.type})',
    };
    final title = item.title ?? (item.state == 1 ? '已失效的$type' : '未命名订阅');
    void onLongPress() => imageSaveDialog(
      title: title,
      cover: item.cover,
    );
    final surface = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          if (item.state == 1 || id == null) {
            SmartDialog.showToast('该$type已失效');
            return;
          }
          if (item.type == 11) {
            Get.toNamed(
              '/favDetail',
              parameters: {
                'mediaId': id.toString(),
                'heroTag': heroTag,
              },
            );
          } else {
            SubDetailPage.toSubDetailPage(
              id,
              heroTag: heroTag,
              subInfo: item,
            );
          }
        },
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: Style.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    double maxWidth = boxConstraints.maxWidth;
                    double maxHeight = boxConstraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Hero(
                          tag: heroTag,
                          child: NetworkImgLayer(
                            src: item.cover,
                            width: maxWidth,
                            height: maxHeight,
                          ),
                        ),
                        PBadge(
                          right: 6,
                          top: 6,
                          text: type,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _content(context, title),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ImmersiveSurface(
        borderRadius: BorderRadius.circular(16),
        child: surface,
      ),
    );
  }

  Widget _content(BuildContext context, String title) {
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: 13,
      color: theme.colorScheme.outline,
    );
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                'UP主: ${item.upper?.name ?? '未知'}',
                textAlign: TextAlign.start,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.mediaCount == null ? '视频数量未知' : '${item.mediaCount}个视频',
                textAlign: TextAlign.start,
                style: style,
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            height: 35,
            width: 35,
            child: IconButton(
              onPressed: item.id == null || item.type == null
                  ? null
                  : cancelSub,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.outline,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
