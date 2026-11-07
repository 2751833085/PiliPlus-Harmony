import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/search/search_rcmd/data.dart';
import 'package:PiliPlus/pages/search/controller.dart';
import 'package:PiliPlus/pages/search/widgets/hot_keyword.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class SearchKeywordSection extends StatelessWidget {
  const SearchKeywordSection({
    super.key,
    required this.controller,
    required this.isTrending,
    required this.padding,
    required this.onClick,
    this.columns = 2,
  });

  final BaseSearchController controller;
  final bool isTrending;
  final EdgeInsets padding;
  final ValueChanged<String> onClick;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      isTrending ? 'bilibili热搜' : '搜索发现',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      strutStyle: const StrutStyle(leading: 0, height: 1),
      style: theme.textTheme.titleMedium!.copyWith(
        height: 1,
        fontWeight: .bold,
      ),
    );
    final outline = theme.colorScheme.outline;
    final secondary = theme.colorScheme.secondary;
    final style = TextStyle(
      height: 1,
      fontSize: 13,
      color: outline,
    );
    return SliverPadding(
      padding: padding,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const .fromLTRB(6, 0, 6, 6),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Expanded(
                    child: isTrending
                        ? Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(child: text),
                              TextButton(
                                style: const ButtonStyle(
                                  visualDensity: .compact,
                                  tapTargetSize: .shrinkWrap,
                                  padding: WidgetStatePropertyAll(
                                    .symmetric(horizontal: 10),
                                  ),
                                ),
                                onPressed: () => Get.toNamed('/searchTrending'),
                                child: Row(
                                  children: [
                                    Text(
                                      '完整榜单',
                                      strutStyle: const StrutStyle(
                                        leading: 0,
                                        height: 1,
                                      ),
                                      style: style,
                                    ),
                                    Icon(
                                      size: 18,
                                      Icons.keyboard_arrow_right,
                                      color: outline,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : text,
                  ),
                  if (!isTrending)
                    TextButton.icon(
                      style: const ButtonStyle(
                        visualDensity: .compact,
                        tapTargetSize: .shrinkWrap,
                        padding: WidgetStatePropertyAll(
                          .symmetric(horizontal: 10),
                        ),
                      ),
                      onPressed: controller.queryRecommendList,
                      icon: Icon(
                        Icons.refresh_outlined,
                        size: 18,
                        color: secondary,
                      ),
                      label: Text(
                        '刷新',
                        strutStyle: const StrutStyle(leading: 0, height: 1),
                        style: TextStyle(height: 1, color: secondary),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Obx(
            () => _buildHotKey(
              isTrending
                  ? controller.trendingState.value
                  : controller.recommendData.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotKey(
    LoadingState<SearchRcmdData> loadingState,
  ) {
    return switch (loadingState) {
      Success(:final response) when (response.list?.isNotEmpty ?? false) =>
        SliverHotKeyword(
          hotSearchList: response.list!,
          filled: !isTrending,
          onClick: onClick,
          columns: columns,
        ),
      Error(:final errMsg) => HttpError(
        safeArea: false,
        errMsg: errMsg,
        onReload: isTrending
            ? controller.queryTrendingList
            : controller.queryRecommendList,
      ),
      _ => const SliverToBoxAdapter(),
    };
  }
}
