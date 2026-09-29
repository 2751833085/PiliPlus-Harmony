import 'package:PiliPlus/models_new/later/list.dart';
import 'dart:async';
import 'package:PiliPlus/pages/mine/recent_history.dart';
import 'package:PiliPlus/harmony_adapt/harmony_channel.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/models/user/stat.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/pages/common/common_data_controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class MineController extends CommonDataController<FavFolderData, FavFolderData>
    with AccountMixin {
  @override
  AccountService accountService = Get.find<AccountService>();

  final laterPreview = <LaterItemModel>[].obs;
  final laterLoading = false.obs;
  final laterError = RxnString();
  int _laterGeneration = 0;
  Future<void> refreshLaterPreview() async {
    final generation = ++_laterGeneration;
    final account = Accounts.main;
    if (!account.isLogin) {
      laterPreview.clear();
      laterLoading.value = false;
      laterError.value = null;
      return;
    }
    laterLoading.value = true;
    laterError.value = null;
    try {
      final result = await UserHttp.seeYouLater(page: 1);
      if (isClosed ||
          generation != _laterGeneration ||
          !identical(account, Accounts.main))
        return;
      if (result case Success(:final response)) {
        laterPreview.assignAll((response.list ?? <LaterItemModel>[]).take(8));
      } else {
        laterError.value = '稍后再看暂时无法加载';
      }
    } catch (_) {
      if (!isClosed && generation == _laterGeneration)
        laterError.value = '稍后再看暂时无法加载';
    } finally {
      if (!isClosed && generation == _laterGeneration)
        laterLoading.value = false;
    }
  }

  int? favFolderCount;
  int _favoritesGeneration = 0;
  final recentHistory = RecentHistory();
  StreamSubscription? _historyAccountChanges;
  StreamSubscription? _historySettingChanges;

  void syncHistoryPreview() {
    final account = Accounts.history;
    recentHistory.configure(
      enabled: Pref.showMineHistory,
      account: account.isLogin ? account : null,
      load: () => UserHttp.historyList(type: 'all', account: account),
    );
  }

  // 用户信息 头像、昵称、lv
  final Rx<UserInfoData> userInfo = UserInfoData().obs;
  // 用户状态 动态、关注、粉丝
  final Rx<UserStat> userStat = const UserStat().obs;

  final Rx<ThemeType> themeType = Pref.themeType.obs;

  ThemeType get nextThemeType =>
      ThemeType.values[(themeType.value.index + 1) % ThemeType.values.length];

  static RxBool anonymity =
      (Accounts.account.isNotEmpty && !Accounts.heartbeat.isLogin).obs;

  late final list = <({IconData icon, String title, VoidCallback onTap})>[
    (
      icon: CustomIcons.folderDownloadOutline,
      title: '离线缓存',
      onTap: () => Get.toNamed('/download'),
    ),
    (
      icon: CustomIcons.history,
      title: '观看记录',
      onTap: () {
        if (isLogin) {
          Get.toNamed('/history');
        }
      },
    ),
    (
      icon: CustomIcons.subscriptions_outlined,
      title: '我的订阅',
      onTap: () {
        if (isLogin) {
          Get.toNamed('/subscription');
        }
      },
    ),
    (
      icon: CustomIcons.watch_later_outlined,
      title: '稍后再看',
      onTap: () {
        if (isLogin) {
          Get.toNamed('/later');
        }
      },
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    refreshLaterPreview();
    syncHistoryPreview();
    _historyAccountChanges = Accounts.account.watch().listen(
      (_) => syncHistoryPreview(),
    );
    _historySettingChanges = GStorage.setting
        .watch(key: SettingBoxKey.showMineHistory)
        .listen((_) => syncHistoryPreview());
    UserInfoData? userInfoCache = Pref.userInfoCache;
    if (userInfoCache != null) {
      userInfo.value = userInfoCache;
      queryData();
      queryUserInfo();
    }
  }

  bool get isLogin {
    if (!accountService.isLogin.value) {
      SmartDialog.showToast('请先登录');
      return false;
    }
    return true;
  }

  Future<void> queryUserInfo() async {
    final account = Accounts.main;
    final res = await UserHttp.userInfo();
    if (isClosed || !identical(account, Accounts.main)) return;
    if (res case Success(:final response)) {
      if (response.isLogin == true) {
        userInfo.value = response;
        if (response != Pref.userInfoCache) {
          GStorage.userInfo.put('userInfoCache', response);
        }
        accountService
          ..face.value = response.face!
          ..isLogin.value = true;
      } else {
        _onLogoutMain();
        return;
      }
    } else {
      final errMsg = res.toString();
      SmartDialog.showToast(errMsg);
      if (errMsg == '账号未登录') {
        _onLogoutMain();
        return;
      }
    }
    queryUserStatOwner();
  }

  void _onLogoutMain() => Accounts.deleteAll({Accounts.main});

  Future<void> queryUserStatOwner() async {
    final account = Accounts.main;
    final res = await UserHttp.userStatOwner();
    if (isClosed || !identical(account, Accounts.main)) return;
    if (res case Success(:final response)) {
      userStat.value = response;
    }
  }

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    if (isLoading || isClosed || !Accounts.main.isLogin) return;
    final generation = ++_favoritesGeneration;
    final account = Accounts.main;
    isLoading = true;
    try {
      final response = await customGetData();
      if (isClosed ||
          generation != _favoritesGeneration ||
          !identical(account, Accounts.main)) {
        return;
      }
      if (response case Success<FavFolderData>()) {
        customHandleResponse(isRefresh, response);
      } else {
        loadingState.value = response;
      }
    } catch (_) {
      if (!isClosed && generation == _favoritesGeneration) {
        loadingState.value = const Error('收藏暂时无法加载，请重试');
      }
    } finally {
      if (generation == _favoritesGeneration) isLoading = false;
    }
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<FavFolderData> response) {
    favFolderCount = response.response.count;
    loadingState.value = response;
    return true;
  }

  @override
  Future<LoadingState<FavFolderData>> customGetData() async {
    final account = Accounts.main;
    final response = await FavHttp.userfavFolder(
      pn: 1,
      ps: 20,
      mid: account.mid,
    );
    if (isClosed || !identical(account, Accounts.main)) {
      return const Error(null);
    }
    return response;
  }

  static void onChangeAnonymity() {
    if (Accounts.account.isEmpty) {
      SmartDialog.showToast('请先登录');
      return;
    }
    final newVal = !anonymity.value;
    anonymity.value = newVal;
    HarmonyChannel.setShellBarsHidden(true);
    if (newVal) {
      SmartDialog.dismiss();
      SmartDialog.show<bool>(
        clickMaskDismiss: false,
        usePenetrate: true,
        displayTime: const Duration(seconds: 2),
        alignment: Alignment.bottomCenter,
        onDismiss: () {
          HarmonyChannel.setShellBarsHidden(false);
        },
        builder: (context) {
          final theme = Theme.of(context);
          final style = TextStyle(
            color: theme.colorScheme.onSurface,
          );
          return ImmersiveSurface(
            blurBackground: true,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(
                top: 15,
                left: 20,
                right: 20,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(MdiIcons.incognito, size: 20),
                      const SizedBox(width: 10),
                      Text('已进入无痕模式', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '搜索不携带身份信息\n'
                    '不产生查询或播放记录\n'
                    '点赞等其它操作不受影响\n'
                    '播放进度信息跟随视频取流\n'
                    '上次观看分p信息跟随主账号\n'
                    '(前往隐私设置了解详情)',
                    style: theme.textTheme.bodySmall,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          SmartDialog.dismiss(result: true);
                          SmartDialog.showToast('已设为永久无痕模式');
                        },
                        child: Text('保存为永久', style: style),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          SmartDialog.dismiss();
                          SmartDialog.showToast('已设为临时无痕模式');
                        },
                        child: Text('仅本次（默认）', style: style),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ).then((res) {
        if (res == false) {
          return;
        }
        res == true
            ? Accounts.set(AccountType.heartbeat, AnonymousAccount())
            : Accounts.accountMode[AccountType.heartbeat.index] =
                  AnonymousAccount();
      });
    } else {
      Accounts.set(AccountType.heartbeat, Accounts.main);
      SmartDialog.dismiss(result: false);
      SmartDialog.show(
        clickMaskDismiss: false,
        usePenetrate: true,
        displayTime: const Duration(seconds: 1),
        alignment: Alignment.bottomCenter,
        onDismiss: () {
          HarmonyChannel.setShellBarsHidden(false);
        },
        builder: (context) {
          final theme = Theme.of(context);
          return ImmersiveSurface(
            blurBackground: true,
            color: theme.colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.only(
                top: 15,
                left: 20,
                right: 20,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 15,
              ),
              child: Row(
                children: [
                  const Icon(MdiIcons.incognitoOff, size: 20),
                  const SizedBox(width: 10),
                  Text('已退出无痕模式', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void onChangeTheme() {
    final newVal = nextThemeType;
    themeType.value = newVal;
    GStorage.setting.put(SettingBoxKey.themeMode, newVal.index);
    Get.changeThemeMode(ThemeUtils.themeMode = newVal.toThemeMode);
    ThemeUtils.syncColorModeToNative();
  }

  void push(String name) {
    late final mid = userInfo.value.mid;
    if (isLogin && mid != null) {
      Get.toNamed('/$name?mid=$mid');
    }
  }

  void onLogin([bool longPress = false]) {
    if (!accountService.isLogin.value || longPress) {
      Get.toNamed('/loginPage');
    } else {
      Get.toNamed('/member?mid=${userInfo.value.mid}');
    }
  }

  Future<void>? _refreshTask;
  @override
  Future<void> onRefresh({bool isManual = true}) {
    if (!accountService.isLogin.value) return Future.value();
    if (_refreshTask != null) return _refreshTask!;
    late final Future<void> task;
    task = _refreshMine().whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
    return _refreshTask = task;
  }

  Future<void> _refreshMine() async {
    syncHistoryPreview();
    await Future.wait([
      queryUserInfo(),
      super.onRefresh(),
      recentHistory.refresh(),
      refreshLaterPreview(),
    ]);
  }

  @override
  void onChangeAccount(bool isLogin) {
    _refreshTask = null;
    _favoritesGeneration++;
    _laterGeneration++;
    laterPreview.clear();
    laterError.value = null;
    laterLoading.value = false;
    isLoading = false;
    favFolderCount = null;
    loadingState.value = LoadingState.loading();
    syncHistoryPreview();
    if (isLogin) {
      onRefresh();
    } else {
      favFolderCount = null;
      userInfo.value = UserInfoData();
      userStat.value = const UserStat();
      loadingState.value = LoadingState.loading();
    }
  }

  @override
  void onClose() {
    _historyAccountChanges?.cancel();
    _historySettingChanges?.cancel();
    recentHistory.dispose();
    super.onClose();
  }
}
