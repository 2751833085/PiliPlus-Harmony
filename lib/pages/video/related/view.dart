import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
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
  });
  final String heroTag;
  final bool sidebar;
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
    return SliverPadding(
      padding: EdgeInsets.only(top: 7, bottom: widget.sidebar ? 16 : 100),
      sliver: Obx(() => _buildBody(_relatedController.loadingState.value)),
    );
  }

  static const _sidebarDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 1,
    mainAxisExtent: 110,
    mainAxisSpacing: 2,
  );

  Widget _buildBody(LoadingState<List<HotVideoItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() =>
        widget.sidebar
            ? const SliverGrid(
                gridDelegate: _sidebarDelegate,
                delegate: SliverSingleChildDelegate(
                  count: 10,
                  child: VideoCardHSkeleton(adaptiveCover: true),
                ),
              )
            : gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: widget.sidebar ? _sidebarDelegate : gridDelegate,
                itemBuilder: (context, index) {
                  return VideoCardH(
                    videoItem: response[index],
                    adaptiveCover: widget.sidebar,
                    onRemove: () => _relatedController.loadingState
                      ..value.data!.removeAt(index)
                      ..refresh(),
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
