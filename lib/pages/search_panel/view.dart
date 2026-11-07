import 'dart:math' show max;

import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

abstract class CommonSearchPanel extends StatefulWidget {
  const CommonSearchPanel({
    super.key,
    required this.keyword,
    required this.searchType,
    required this.tag,
  });

  final String keyword;
  final SearchType searchType;
  final String tag;
}

abstract class CommonSearchPanelState<
  S extends CommonSearchPanel,
  R extends SearchNumData<T>,
  T
>
    extends State<S>
    with AutomaticKeepAliveClientMixin {
  SearchPanelController<R, T> get controller;

  late ColorScheme colorScheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    controller.cancelListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: controller.onRefresh,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ?buildHeader(),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
            sliver: Obx(() => _buildBody(controller.loadingState.value)),
          ),
        ],
      ),
    );
  }

  bool get useSingleColumnResults => HarmonyStyle.enabled(context);

  double scaledRowExtent(double baseExtent, int textLines) =>
      baseExtent +
      max(0, MediaQuery.textScalerOf(context).scale(14) - 14) * textLines;

  // A 172 × 97 cover with space above and below, or more room for larger text.
  double get mediaRowExtent {
    final scaler = MediaQuery.textScalerOf(context);
    return max(122, scaler.scale(16) * 2.9 + scaler.scale(12) * 3.4 + 27);
  }

  Widget buildResultRows({
    required int itemCount,
    required double itemExtent,
    required IndexedWidgetBuilder itemBuilder,
  }) => SliverFixedExtentList.builder(
    itemExtent: itemExtent,
    itemCount: itemCount,
    itemBuilder: (context, index) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .1),
          ),
        ),
      ),
      child: itemBuilder(context, index),
    ),
  );

  bool get hasSupplementalResults => false;

  Widget get buildLoading;

  Widget _buildBody(LoadingState<List<T>?> loadingState) {
    return switch (loadingState) {
      Loading() => buildLoading,
      Success(:final response) =>
        response?.isNotEmpty == true || hasSupplementalResults
            ? buildList(response ?? <T>[])
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget? buildHeader() => null;

  Widget buildList(List<T> list);
}
