import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/pgc/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class SearchPgcPanel extends CommonSearchPanel {
  const SearchPgcPanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchPgcPanel> createState() => _SearchPgcPanelState();
}

class _SearchPgcPanelState
    extends
        CommonSearchPanelState<
          SearchPgcPanel,
          SearchPgcData,
          SearchPgcItemModel
        > {
  @override
  late final SearchPanelController<SearchPgcData, SearchPgcItemModel>
  controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchPanelController<SearchPgcData, SearchPgcItemModel>(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
  }

  late final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
    mainAxisExtent: 158,
  );

  double get _rowExtent => scaledRowExtent(158, 5);

  @override
  Widget buildList(List<SearchPgcItemModel> list) {
    Widget itemBuilder(BuildContext context, int index) {
      if (index == list.length - 1) controller.onLoadMore();
      return SearchPgcItem(item: list[index]);
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
}
