import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/mine/widgets/later_preview.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/harmony_adapt/widgets/initial_feed_content.dart';
import 'package:PiliPlus/pages/mine/widgets/recent_history.dart';
import 'package:PiliPlus/pages/history/open_item.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_quick_actions.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'dart:async';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    if (HarmonyStyle.enabled(context))
      return Obx(
        () => InitialFeedContent(
          loading:
              controller.accountService.isLogin.value &&
              controller.loadingState.value is Loading,
          builder: (_) => _buildHarmonyPage(theme, secondary),
        ),
      );
    return SafeArea(
      // 避让安全区
      child: Column(
        children: [
          Padding(
            padding: const .symmetric(vertical: 10),
            child: _buildHeaderActions,
          ),
          Expanded(
            child: Material(
              type: .transparency,
              child: onBuild(
                ListView(
                  padding: const .only(bottom: 100),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    _buildUserInfo(theme, secondary),
                    _buildActions(secondary),
                    _buildRecentHistory(),
                    Obx(
                      () => controller.loadingState.value is Loading
                          ? const SizedBox.shrink()
                          : _buildFav(theme, secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarmonyPage(ThemeData theme, Color accent) => ColoredBox(
    color: theme.scaffoldBackgroundColor,
    child: _buildHarmonyContent(theme, accent),
  );

  Widget _buildHarmonyContent(ThemeData theme, Color accent) => SafeArea(
    // Paint behind the translucent bar, but reserve its actual Scaffold inset
    // at the end of the scroll view (viewPadding only contains system insets).
    bottom: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildHeaderActions,
            ),
            Expanded(
              child: onBuild(
                LayoutBuilder(
                  builder: (context, constraints) {
                    final split =
                        constraints.maxWidth >=
                        840 * MediaQuery.textScalerOf(context).scale(16) / 16;
                    Widget panel(
                      Widget child, {
                      EdgeInsets padding = const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                    }) => ImmersiveSurface(
                      blurBackground: false,
                      borderRadius: HarmonyTheme.cardRadius,
                      child: Padding(padding: padding, child: child),
                    );
                    final account = panel(
                      _buildUserInfo(theme, accent),
                      padding: const EdgeInsets.only(top: 18, bottom: 10),
                    );
                    final actions = panel(
                      HarmonyQuickActions(
                        actions: [
                          for (final action in controller.list)
                            HarmonyQuickAction(
                              action.title,
                              action.icon,
                              action.onTap,
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                    );
                    final favorites = Obx(
                      () => controller.loadingState.value is Loading
                          ? const SizedBox.shrink()
                          : panel(
                              _buildFav(theme, accent),
                              padding: EdgeInsets.zero,
                            ),
                    );
                    final services = panel(
                      _buildLaterPreview(theme),
                      padding: EdgeInsets.zero,
                    );
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        if (split)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: (constraints.maxWidth - 46) * .43,
                                child: Column(
                                  children: [
                                    account,
                                    const SizedBox(height: 10),
                                    actions,
                                    const SizedBox(height: 10),
                                    favorites,
                                    const SizedBox(height: 10),
                                    services,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildRecentHistory(
                                      harmony: true,
                                      expanded: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          account,
                          const SizedBox(height: 10),
                          actions,
                          const SizedBox(height: 10),
                          _buildRecentHistory(harmony: true),
                          favorites,
                          const SizedBox(height: 10),
                          services,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildRecentHistory({bool harmony = false, bool expanded = false}) =>
      ListenableBuilder(
        listenable: controller.recentHistory,
        builder: (context, _) {
          if (!controller.recentHistory.enabled) return const SizedBox.shrink();
          final child = MineHistoryPreview(
            expanded: expanded,
            history: controller.recentHistory,
            onOpen: (item) async {
              await openHistoryItem(item);
              if (mounted) controller.recentHistory.refresh();
            },
            onViewAll: () => Get.toNamed('/history')?.whenComplete(() {
              if (mounted) controller.recentHistory.refresh();
            }),
            onLogin: () => Get.toNamed('/loginPage'),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: harmony
                ? SizedBox(
                    width: double.infinity,
                    child: ImmersiveSurface(
                      blurBackground: false,
                      borderRadius: HarmonyTheme.cardRadius,
                      child: child,
                    ),
                  )
                : child,
          );
        },
      );

  Widget _buildActions(Color primary) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: controller.list
          .map(
            (e) => Flexible(
              child: InkWell(
                onTap: e.onTap,
                borderRadius: Style.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Column(
                      spacing: 6,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      children: [
                        Icon(e.icon, color: primary),
                        Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    final harmony = HarmonyStyle.enabled(context);
    return PlayerBar(
      children: [
        if (widget.showBackBtn)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: BackButton(),
          )
        else if (harmony)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Text(
              '我的',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          spacing: 5,
          mainAxisSize: .min,
          children:
              [
                    if (!_mainController.hasHome) ...[
                      IconButton(
                        iconSize: iconSize,
                        padding: padding,
                        style: style,
                        tooltip: '搜索',
                        onPressed: () => Get.toNamed('/search'),
                        icon: const Icon(Icons.search),
                      ),
                      msgBadge(_mainController),
                    ],
                    if (GStorage.reply != null)
                      IconButton(
                        iconSize: iconSize,
                        padding: padding,
                        style: style,
                        tooltip: '评论记录',
                        onPressed: () => Get.toNamed('/myReply'),
                        icon: const Icon(Icons.message_outlined),
                      ),
                    Obx(
                      () {
                        final anonymity = MineController.anonymity.value;
                        return IconButton(
                          iconSize: iconSize,
                          padding: padding,
                          style: style,
                          tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
                          onPressed: MineController.onChangeAnonymity,
                          icon: anonymity
                              ? const Icon(MdiIcons.incognito)
                              : const Icon(MdiIcons.incognitoOff),
                        );
                      },
                    ),
                    IconButton(
                      iconSize: iconSize,
                      padding: padding,
                      style: style,
                      tooltip: '切换账号',
                      onPressed: () =>
                          LoginPageController.switchAccountDialog(context),
                      icon: const Icon(Icons.switch_account_outlined),
                    ),
                    Obx(
                      () => IconButton(
                        iconSize: iconSize,
                        padding: padding,
                        style: style,
                        tooltip: '切换至${controller.nextThemeType.label}主题',
                        onPressed: controller.onChangeTheme,
                        icon: controller.themeType.value.icon,
                      ),
                    ),
                    IconButton(
                      iconSize: iconSize,
                      padding: padding,
                      style: style,
                      tooltip: '设置',
                      onPressed: () =>
                          Get.toNamed('/setting', preventDuplicates: false),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                    const SizedBox(width: 16),
                  ]
                  .map(
                    (child) => harmony && child is! SizedBox
                        ? ImmersiveInteraction(
                            borderRadius: BorderRadius.circular(24),
                            child: child,
                          )
                        : child,
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: HarmonyStyle.enabled(context) ? 14 : 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                SizedBox(width: HarmonyStyle.enabled(context) ? 14 : 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          trackGap: hasLevel ? null : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh() => Timer(
    const Duration(milliseconds: 150),
    () => controller.onRefresh(isManual: false),
  );

  Widget _buildLaterPreview(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        dense: true,
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '稍后再看',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          if (controller.isLogin)
            Get.toNamed('/later')?.whenComplete(controller.refreshLaterPreview);
        },
      ),
      Obx(() {
        final items = controller.laterPreview;
        if (items.isEmpty)
          return Padding(
            padding: const EdgeInsets.fromLTRB(26, 4, 20, 16),
            child: Text(
              controller.laterError.value ??
                  (controller.laterLoading.value ? '正在加载…' : '暂无稍后再看的视频'),
              style: theme.textTheme.bodySmall,
            ),
          );
        return MineLaterPreviewList(items: items, onOpen: _openLaterItem);
      }),
    ],
  );

  Future<void> _openLaterItem(LaterItemModel item) async {
    if (item.isPugv == true) {
      PageUtils.viewPugv(seasonId: item.aid);
      return;
    }
    if (item.isPgc == true) {
      if (item.bangumi?.epId != null)
        PageUtils.viewPgc(epId: item.bangumi!.epId);
      else if (item.redirectUrl?.isNotEmpty == true)
        PageUtils.viewPgcFromUri(item.redirectUrl!);
      return;
    }
    final cid =
        item.cid ??
        await SearchHttp.ab2c(
          aid: item.aid,
          bvid: item.bvid,
        ).catchError((_) => null);
    if (!mounted || cid == null) return;
    PageUtils.toVideoPage(
      bvid: item.bvid,
      cid: cid,
      cover: item.pic,
      title: item.title,
      dimension: item.dimension,
      extraArguments: const {'viewLater': true},
    );
  }

  Widget _buildFav(ThemeData theme, Color secondary) {
    return Column(
      children: [
        if (!HarmonyStyle.enabled(context))
          Divider(
            height: 20,
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ListTile(
          onTap: () => Get.toNamed('/fav')?.whenComplete(_autoRefresh),
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '我的收藏  ',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium!.fontSize,
                      fontWeight: .bold,
                    ),
                  ),
                  if (controller.favFolderCount != null)
                    TextSpan(
                      text: "${controller.favFolderCount}  ",
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall!.fontSize,
                        color: secondary,
                      ),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildFavBody(theme, secondary, controller.loadingState.value),
      ],
    );
  }

  Widget _buildFavBody(
    ThemeData theme,
    Color secondary,
    LoadingState loadingState,
  ) {
    return switch (loadingState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => Builder(
        builder: (context) {
          List<FavFolderInfo>? favFolderList = response.list;
          if (favFolderList == null || favFolderList.isEmpty) {
            return const SizedBox.shrink();
          }
          bool flag = (controller.favFolderCount ?? 0) > favFolderList.length;
          return SizedBox(
            height:
                148 +
                MediaQuery.textScalerOf(
                      context,
                    ).scale(theme.textTheme.bodyMedium?.fontSize ?? 14) *
                    1.5 +
                MediaQuery.textScalerOf(
                      context,
                    ).scale(theme.textTheme.labelSmall?.fontSize ?? 11) *
                    1.5,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const .only(left: 20, top: 10, right: 20),
              itemCount: response.list.length + (flag ? 1 : 0),
              itemBuilder: (context, index) {
                if (flag && index == favFolderList.length) {
                  return Padding(
                    padding: const .only(bottom: 35),
                    child: Center(
                      child: IconButton(
                        tooltip: '查看更多',
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(.zero),
                          backgroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/fav')?.whenComplete(_autoRefresh),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ),
                  );
                } else {
                  return FavFolderItem(
                    heroTag: Utils.generateRandomString(8),
                    item: response.list[index],
                    onPop: _autoRefresh,
                  );
                }
              },
              scrollDirection: .horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
            ),
          );
        },
      ),
      Error(:final errMsg) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            errMsg ?? '',
            textAlign: .center,
          ),
        ),
      ),
    };
  }
}
