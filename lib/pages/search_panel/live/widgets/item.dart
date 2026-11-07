import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h_layout.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class LiveItem extends StatelessWidget {
  final SearchLiveItemModel liveItem;
  final bool horizontal;

  const LiveItem({super.key, required this.liveItem, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void onLongPress() => imageSaveDialog(
      title: liveItem.title.map((item) => item.text).join(),
      cover: liveItem.cover,
    );
    if (horizontal) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => PageUtils.toLiveRoom(liveItem.roomid),
          onLongPress: onLongPress,
          onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Style.safeSpace,
              vertical: VideoCardHLayout.searchVerticalPadding,
            ),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final width = VideoCardHLayout.searchCoverWidth(
                  bounds.maxWidth,
                );
                final metadataStyle = TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                );
                return Row(
                  spacing: 10,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        NetworkImgLayer(
                          src: liveItem.cover,
                          width: width,
                          height: width / Style.aspectRatio16x9,
                        ),
                        const PBadge(text: '直播中', top: 6, right: 6),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _title(theme)),
                          Text(
                            liveItem.uname ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metadataStyle,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (liveItem.online != null)
                                '${NumUtils.numFormat(liveItem.online)}围观',
                              if (liveItem.cateName case final category?
                                  when category.isNotEmpty)
                                category,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metadataStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => PageUtils.toLiveRoom(liveItem.roomid),
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Column(
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
                      NetworkImgLayer(
                        src: liveItem.cover,
                        width: maxWidth,
                        height: maxHeight,
                        borderRadius: BorderRadius.zero, // 此处应为非表情类型，且默认不需要圆角
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 200),
                          child: liveStat(
                            liveItem.online,
                            liveItem.cateName,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            liveContent(theme),
          ],
        ),
      ),
    );
  }

  Widget liveContent(ThemeData theme) => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _title(theme),
          Text(
            liveItem.uname!,
            maxLines: 1,
            style: TextStyle(
              fontSize: theme.textTheme.labelMedium!.fontSize,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _title(ThemeData theme) => Text.rich(
    maxLines: horizontal ? 2 : null,
    overflow: horizontal ? TextOverflow.ellipsis : null,
    TextSpan(
      children: liveItem.title
          .map(
            (e) => TextSpan(
              text: e.text,
              style: TextStyle(
                color: e.isEm
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget liveStat(int? online, String? cateName) {
    return Container(
      height: 45,
      padding: const EdgeInsets.only(top: 22, left: 8, right: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black54,
          ],
          tileMode: TileMode.mirror,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            cateName!,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          Text(
            '${NumUtils.numFormat(online)}围观',
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
