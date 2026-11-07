import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/article/controller.dart';
import 'package:PiliPlus/pages/search_panel/article/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchArticlePanel extends CommonSearchPanel {
  const SearchArticlePanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchArticlePanel> createState() => _SearchArticlePanelState();
}

class _SearchArticlePanelState
    extends
        CommonSearchPanelState<
          SearchArticlePanel,
          SearchArticleData,
          SearchArticleItemModel
        >
    with GridMixin {
  @override
  late final SearchArticleController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchArticleController(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
  }

  @override
  Widget buildHeader() {
    return SliverFloatingHeaderWidget(
      backgroundColor: colorScheme.surface,
      child: Padding(
        padding: const .fromLTRB(25, 0, 12, 4),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Obx(
                () => Text(
                  '排序: ${controller.articleOrderType.value.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.outline),
                ),
              ),
            ),
            Expanded(
              child: Obx(
                () => Text(
                  '分区: ${controller.articleZoneType!.value.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.outline),
                ),
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                tooltip: '筛选',
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                onPressed: () => controller.onShowFilterDialog(context),
                icon: Icon(
                  Icons.filter_list_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _rowExtent => scaledRowExtent(110, 4);

  @override
  Widget buildList(List<SearchArticleItemModel> list) {
    Widget itemBuilder(BuildContext context, int index) {
      if (index == list.length - 1) controller.onLoadMore();
      return SearchArticleItem(item: list[index]);
    }

    return useSingleColumnResults
        ? buildResultRows(
            itemCount: list.length,
            itemExtent: _rowExtent,
            itemBuilder: itemBuilder,
          )
        : SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: list.length,
            itemBuilder: itemBuilder,
          );
  }

  @override
  Widget get buildLoading => useSingleColumnResults
      ? buildResultRows(
          itemCount: 10,
          itemExtent: _rowExtent,
          itemBuilder: (_, _) => const VideoCardHSkeleton(),
        )
      : gridSkeleton;
}
