import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/image/full_cover_preview.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:material_ui/material_ui.dart';

const _iconSize = 20.0;

void imageSaveDialog({
  required String? title,
  required String? cover,
  dynamic aid,
  String? bvid,
  WidgetBuilder? actionsBuilder,
  double coverAspectRatio = 16 / 9,
}) {
  Get.key.currentState!.push(
    PublishRoute(
      settings: const RouteSettings(name: 'harmony:coverPreview'),
      transitionDuration: const Duration(milliseconds: 160),
      barrierLabel: '关闭封面预览',
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        final colorScheme = ColorScheme.of(context);
        final screen = MediaQuery.sizeOf(context);
        final wide = actionsBuilder != null && screen.width >= 720;
        final panelWidth = (screen.width - 48).clamp(0.0, 860.0);
        final imgWidth = wide
            ? (panelWidth - 300).clamp(0.0, 560.0)
            : (screen.width - 64).clamp(0.0, 560.0);
        final preview = Container(
          width: imgWidth,
          margin: const .symmetric(horizontal: Style.safeSpace),
          child: Column(
            mainAxisSize: .min,
            children: [
              if (cover?.isNotEmpty == true)
                FullCoverPreview(
                  aspectRatio: coverAspectRatio,
                  image: ResizeImage.resizeIfNeeded(
                    1280,
                    null,
                    CachedNetworkImageProvider(
                      ImageUtils.thumbnailUrlWithSize(cover, 1280, null, 100),
                    ),
                  ),
                  width: imgWidth,
                  maxHeight: (screen.height - 192).clamp(120.0, 900.0),
                ),
              Padding(
                padding: const .fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: SelectionText(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (aid != null || bvid != null)
                      iconButton(
                        iconSize: _iconSize,
                        tooltip: '稍后再看',
                        onPressed: () => {
                          Get.back(),
                          UserHttp.toViewLater(aid: aid, bvid: bvid),
                        },
                        icon: const Icon(Icons.watch_later_outlined),
                      ),
                    if (cover != null && cover.isNotEmpty) ...[
                      if (PlatformUtils.isMobile)
                        iconButton(
                          iconSize: _iconSize,
                          tooltip: '分享',
                          onPressed: () {
                            Get.back();
                            ImageUtils.onShareImg(cover);
                          },
                          icon: const Icon(Icons.share),
                        )
                      else
                        iconButton(
                          iconSize: 18,
                          tooltip: '复制链接',
                          onPressed: () {
                            Get.back();
                            Utils.copyText(cover);
                          },
                          icon: const Icon(Icons.copy),
                        ),
                      iconButton(
                        iconSize: _iconSize,
                        tooltip: '保存封面图',
                        onPressed: () async {
                          bool saveStatus = await ImageUtils.downloadImg([
                            cover,
                          ]);
                          if (saveStatus) {
                            Get.back();
                          }
                        },
                        icon: const Icon(Icons.download),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        final actions = actionsBuilder == null ? null : actionsBuilder(context);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: panelWidth,
              maxHeight: screen.height - 96,
            ),
            child: Material(
              color: colorScheme.surface.withValues(alpha: 1),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: wide
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: SingleChildScrollView(child: preview)),
                        SizedBox(
                          width: 268,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: actions!,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          preview,
                          if (actions != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: actions,
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final motion = animation.drive(
          CurveTween(curve: Curves.easeInOutCubic),
        );
        return FadeTransition(
          opacity: motion,
          child: ScaleTransition(
            scale: motion.drive(Tween<double>(begin: .96, end: 1)),
            child: child,
          ),
        );
      },
    ),
  );
}
