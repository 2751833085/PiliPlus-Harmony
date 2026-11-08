import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class DownloadPageController extends GetxController
    with BaseMultiSelectMixin<DownloadPageInfo> {
  final _downloadService = Get.find<DownloadService>();
  final pages = RxList<DownloadPageInfo>();
  final flag = RxInt(0);
  final initialLoad = Rx<LoadingState<void>>(LoadingState.loading());

  @override
  List<DownloadPageInfo> get list => pages;
  @override
  RxList<DownloadPageInfo> get state => pages;

  @override
  void onInit() {
    super.onInit();
    _loadList();
    _downloadService.flagNotifier.add(_loadList);
  }

  @override
  void onClose() {
    _downloadService.flagNotifier.remove(_loadList);
    super.onClose();
  }

  void onReload() {
    if (isClosed || initialLoad.value is! Error) return;
    initialLoad.value = LoadingState.loading();
    _downloadService.initDownloadList();
    _loadList();
  }

  Future<void> _loadList() async {
    final scan = _downloadService.waitForInitialization;
    bool isCurrent() =>
        !isClosed && identical(scan, _downloadService.waitForInitialization);
    try {
      await scan;
    } catch (_) {
      if (isCurrent()) initialLoad.value = const Error('无法读取离线缓存');
      return;
    }
    if (!isCurrent()) return;
    if (_downloadService.downloadList.isEmpty) {
      pages.clear();
      initialLoad.value = const Success(null);
      return;
    }
    final byPage = <String, DownloadPageInfo>{};
    for (final entry in _downloadService.downloadList) {
      final pageId = entry.pageId;
      final page = byPage[pageId];
      if (page != null) {
        final aSortKey = entry.sortKey;
        final bSortKey = page.sortKey;
        if (aSortKey < bSortKey) {
          page
            ..cover = entry.cover
            ..sortKey = aSortKey;
        }
        page.entries.add(entry);
      } else {
        byPage[pageId] = DownloadPageInfo(
          pageId: pageId,
          dirPath: entry.pageDirPath,
          title: entry.title,
          cover: entry.cover,
          sortKey: entry.sortKey,
          seasonType: entry.ep?.seasonType,
          entries: [entry],
        );
      }
    }
    pages.value = byPage.values.toList();
    flag.value++;
    initialLoad.value = const Success(null);
  }

  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定删除选中视频？'),
      onConfirm: () async {
        SmartDialog.showLoading();
        final watchProgress = GStorage.watchProgress;
        for (final page in allChecked) {
          await watchProgress.deleteAll(
            page.entries.map((e) => e.cid.toString()),
          );
          await _downloadService.deletePage(
            pageDirPath: page.dirPath,
            refresh: false,
          );
        }
        _downloadService.flagNotifier.refresh();
        if (enableMultiSelect.value) {
          rxCount.value = 0;
          enableMultiSelect.value = false;
        }
        SmartDialog.dismiss();
      },
    );
  }
}
