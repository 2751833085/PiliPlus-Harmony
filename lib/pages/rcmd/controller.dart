import 'package:PiliPlus/pages/rcmd/refresh_batch.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int visibleColumns = 2;
  int _nextFreshIndex = 0;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    final target = recommendationBatchSize(visibleColumns);
    return collectRecommendationBatch<BaseRcmdVideoItemModel>(
      target: target,
      parallelism: appRcmd ? 2 : 1,
      keyOf: (item) => item.bvid ?? item.aid?.toString(),
      fetch: () {
        final index = _nextFreshIndex++;
        return appRcmd
            ? VideoHttp.rcmdVideoListApp(freshIdx: index)
            : VideoHttp.rcmdVideoList(freshIdx: index, ps: target);
      },
    );
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData &&
        loadingState.value.dataOrNull?.isNotEmpty == true;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    if (isLoading) return Future<void>.value();
    _nextFreshIndex = 0;
    lastRefreshAt = null;
    page = 0;
    isEnd = false;
    return queryData();
  }
}
