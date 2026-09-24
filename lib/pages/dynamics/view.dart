import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:material_ui/material_ui.dart' hide DraggableScrollableSheet;
import 'package:get/get.dart';

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  UpPanelPosition get upPanelPosition => _dynamicsController.upPanelPosition;
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  Widget _createDynamicBtn(ThemeData theme, {bool isRight = true}) {
    final harmony = HarmonyStyle.enabled(context);
    final button = IconButton(
      tooltip: '发布动态',
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: harmony
            ? Colors.transparent
            : theme.colorScheme.secondaryContainer,
        foregroundColor: harmony
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSecondaryContainer,
        minimumSize: Size.square(harmony ? 40 : 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => CreateDynPanel.onCreateDyn(context),
      icon: Icon(Icons.add, size: harmony ? 22 : 18),
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: !isRight ? 16 : 0,
          right: isRight ? 16 : 0,
        ),
        child: harmony
            ? ImmersiveSurface(
                borderRadius: BorderRadius.circular(24),
                child: button,
              )
            : button,
      ),
    );
  }

  Widget _tabSurface(Widget child) => HarmonyStyle.enabled(context)
      ? Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: ImmersiveSurface(
            blurBackground: false,
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        )
      : child;

  Widget upPanelPart(ThemeData theme) {
    final isTop = upPanelPosition == .top;
    final needBg = upPanelPosition.index > 2;
    return Material(
      type: needBg ? .canvas : .transparency,
      color: needBg ? theme.colorScheme.surface : null,
      child: SizedBox(
        width: isTop ? null : 76,
        height: isTop ? 82 : null,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 300) {
              _dynamicsController.onLoadMore();
            }
            return false;
          },
          child: Obx(
            () => _buildUpPanel(_dynamicsController.loadingState.value),
          ),
        ),
      ),
    );
  }

  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != .dynamics &&
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

    Widget? drawer;
    Widget? endDrawer;

    Widget? leading;
    List<Widget>? actions;

    Widget child = tabBarView(
      controller: _dynamicsController.tabController,
      children: DynamicsTabType.values
          .map((e) => DynamicsTabPage(dynamicsType: e))
          .toList(),
    );

    switch (upPanelPosition) {
      case UpPanelPosition.top:
        child = Column(
          children: [
            upPanelPart(theme),
            Expanded(child: child),
          ],
        );
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.leftFixed:
        child = Row(
          children: [
            upPanelPart(theme),
            Expanded(child: child),
          ],
        );
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.rightFixed:
        child = Row(
          children: [
            Expanded(child: child),
            upPanelPart(theme),
          ],
        );
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.leftDrawer:
        drawer = upPanelPart(theme);
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.rightDrawer:
        endDrawer = upPanelPart(theme);
        leading = _createDynamicBtn(theme, isRight: false);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        primary: true, // 避让安全区
        leading: leading,
        leadingWidth: HarmonyStyle.enabled(context) ? 56 : 50,
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        title: _tabSurface(
          SizedBox(
            height: 44,
            child: TabBar(
              dividerHeight: 0,
              isScrollable: true,
              tabAlignment: .center,
              dividerColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.primary,
              controller: _dynamicsController.tabController,
              unselectedLabelColor: theme.colorScheme.onSurface,
              labelStyle:
                  TabBarTheme.of(context).labelStyle?.copyWith(fontSize: 13) ??
                  const TextStyle(fontSize: 13),
              tabs: DynamicsTabType.values
                  .map((e) => Tab(text: e.label))
                  .toList(),
              onTap: (index) {
                if (!_dynamicsController.tabController.indexIsChanging) {
                  _dynamicsController.animateToTop();
                }
              },
            ),
          ),
        ),
        actions: actions,
      ),
      drawer: drawer,
      endDrawer: endDrawer,
      body: onBuild(child),
    );
  }
}
