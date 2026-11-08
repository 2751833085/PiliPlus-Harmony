import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/dyn/common_dyn_page.dart';
import 'package:material_ui/material_ui.dart';

/// Action chrome shared only by article and dynamic detail pages.
mixin SplitDetailActions<T extends StatefulWidget> on CommonDynPageMixin<T> {
  static const _stripHeight = 48.0;
  static const _replySize = 56.0;
  static const _itemMinWidth = 72.0;
  bool? _lastPortraitLayout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastPortraitLayout != isPortrait) {
      _lastPortraitLayout = isPortrait;
      showFab();
    }
  }

  @override
  bool get useDetailReplyChrome => HarmonyStyle.enabled(context);

  @override
  bool get restoreFabAfterReply => true;

  @override
  Color get replyChromeBackground => useDetailReplyChrome
      ? theme.scaffoldBackgroundColor
      : super.replyChromeBackground;

  @override
  Color get replySortForeground => useDetailReplyChrome
      ? theme.colorScheme.onSurfaceVariant
      : super.replySortForeground;

  Color get detailActionForeground => useDetailReplyChrome
      ? theme.colorScheme.onSurfaceVariant
      : theme.colorScheme.outline;

  double detailActionInset(bool hasStrip) =>
      padding.bottom +
      kFloatingActionButtonMargin +
      _replySize +
      (hasStrip ? _stripHeight : 0);

  Widget detailScrollTracking(Widget child) =>
      NotificationListener<UserScrollNotification>(
        onNotification: (notification) =>
            notification.metrics.axis == Axis.vertical
            ? onNotification(notification)
            : false,
        child: child,
      );

  Widget detailActionsTransition(Widget child) =>
      SlideTransition(position: fabAnimation, child: child);

  Widget splitDetailPane({required Widget body, required Widget actions}) =>
      MiniScaffold(
        body: ClipRect(
          child: ScaffoldLayout(
            body: detailScrollTracking(body),
            fab: detailActionsTransition(actions),
          ),
        ),
      );

  Widget splitReplyList(LoadingState<List<ReplyInfo>?> state, bool hasStrip) {
    final sliver = replyList(state);
    // Populated replies already have a 125-point footer plus the safe area.
    if (state.dataOrNull?.isNotEmpty == true) return sliver;
    return SliverPadding(
      padding: EdgeInsets.only(bottom: detailActionInset(hasStrip)),
      sliver: sliver,
    );
  }

  Widget detailActions(List<Widget> items) {
    final hasStrip = items.isNotEmpty;
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: isPortrait && hasStrip ? padding.left : 0,
        right: isPortrait && hasStrip ? padding.right : 0,
        bottom: padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              right: kFloatingActionButtonMargin,
              bottom: kFloatingActionButtonMargin,
            ),
            child: SizedBox.square(
              dimension: _replySize,
              child: useDetailReplyChrome
                  ? Theme(
                      data: theme.copyWith(
                        floatingActionButtonTheme: theme
                            .floatingActionButtonTheme
                            .copyWith(
                              backgroundColor: scheme.surfaceContainerHigh,
                              foregroundColor: scheme.onSurface,
                            ),
                      ),
                      child: replyButton,
                    )
                  : replyButton,
            ),
          ),
          if (hasStrip)
            DecoratedBox(
              decoration: BoxDecoration(
                color: replyChromeBackground,
                border: Border(
                  top: BorderSide(
                    color: useDetailReplyChrome
                        ? scheme.outlineVariant
                        : scheme.outline.withValues(alpha: .08),
                    width: .5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: _stripHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = MediaQuery.textScalerOf(context)
                        .scale(_itemMinWidth)
                        .clamp(_itemMinWidth, double.infinity);
                    if (constraints.maxWidth >= itemWidth * items.length) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in items) Expanded(child: item),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in items)
                            SizedBox(width: itemWidth, child: item),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
