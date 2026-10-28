import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/image/feed_image_budget.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h_layout.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/video/related/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RelatedVideoPanel extends StatefulWidget {
  const RelatedVideoPanel({
    super.key,
    required this.heroTag,
    this.sidebar = false,
    this.compactSidebar = false,
  });
  final String heroTag;
  final bool sidebar;
  final bool compactSidebar;
  @override
  State<RelatedVideoPanel> createState() => _RelatedVideoPanelState();
}

class _RelatedVideoPanelState extends State<RelatedVideoPanel> with GridMixin {
  late final RelatedController _relatedController;

  @override
  void initState() {
    super.initState();
    _relatedController = Get.putOrFind(
      RelatedController.new,
      tag: widget.heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: EdgeInsets.only(
          top: widget.sidebar ? 13 : 7,
          bottom: widget.sidebar ? 16 : 100,
        ),
        sliver: Obx(
          () => _buildBody(
            context,
            _relatedController.loadingState.value,
            constraints.crossAxisExtent,
          ),
        ),
      ),
    );
  }

  static const _sidebarDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 1,
    mainAxisExtent: 116,
    mainAxisSpacing: 2,
  );

  Widget _buildBody(
    BuildContext context,
    LoadingState<List<HotVideoItemModel>?> loadingState,
    double availableWidth,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final sidebarDelegate = widget.compactSidebar
        ? SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: VideoCardHLayout.compactRowExtent(
              availableWidth: availableWidth,
              titleFontSize: scaler.scale(
                Theme.of(context).textTheme.bodyMedium!.fontSize!,
              ),
              metadataFontSize: scaler.scale(12),
            ),
            mainAxisSpacing: 2,
          )
        : _sidebarDelegate;
    return switch (loadingState) {
      Loading() =>
        widget.sidebar
            ? SliverGrid(
                gridDelegate: sidebarDelegate,
                delegate: SliverSingleChildDelegate(
                  count: 10,
                  child: VideoCardHSkeleton(
                    adaptiveCover: true,
                    compactSidebar: widget.compactSidebar,
                  ),
                ),
              )
            : gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: widget.sidebar ? sidebarDelegate : gridDelegate,
                itemBuilder: (context, index) {
                  return FeedImageBudget(
                    child: VideoCardH(
                      videoItem: response[index],
                      adaptiveCover: widget.sidebar,
                      compactSidebar: widget.compactSidebar,
                      onRemove: () => _relatedController.loadingState
                        ..value.data!.removeAt(index)
                        ..refresh(),
                    ),
                  );
                },
                itemCount: response.length,
              )
            : const SliverToBoxAdapter(),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _relatedController.onReload,
      ),
    };
  }
}
