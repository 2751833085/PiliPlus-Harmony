import 'package:PiliPlus/pages/whisper/widgets/message_split.dart';
import 'package:PiliPlus/pages/msg_feed_top/reply_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/at_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/like_me/view.dart';
import 'package:PiliPlus/pages/msg_feed_top/sys_msg/view.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/pages/whisper_detail/view.dart';
import 'package:PiliPlus/common/widgets/flutter/text_field/controller.dart'
    show RichTextItem;
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/pages/whisper/widgets/message_surface.dart';
import 'package:PiliPlus/common/widgets/loading_widget/loading_widget.dart';
import 'package:PiliPlus/common/skeleton/whisper_item.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/grpc/bilibili/app/im/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/whisper/controller.dart';
import 'package:PiliPlus/pages/whisper/widgets/item.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/extension/three_dot_ext.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class WhisperPage extends StatefulWidget {
  const WhisperPage({super.key});

  @override
  State<WhisperPage> createState() => _WhisperPageState();
}

class _WhisperPageState extends State<WhisperPage> {
  final _controller = Get.put(WhisperController());
  Map<String, dynamic>? _selected;
  String? _notification;
  final _drafts = <String, List<RichTextItem>>{};
  String _draftKey(Map<String, dynamic> conversation) =>
      '${Accounts.main.mid}:${conversation['talkerId']}';

  void _openConversation(Map<String, dynamic> conversation) {
    if (_selected?['talkerId'] == conversation['talkerId']) return;
    setState(() {
      _notification = null;
      _selected = conversation;
    });
  }

  void _closeConversation() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _notification = null;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final harmony = HarmonyStyle.enabled(context);
    final split =
        MediaQuery.sizeOf(context).width >=
        840 * MediaQuery.textScalerOf(context).scale(16) / 16;
    final selected = _selected;
    final hasSelection = selected != null || _notification != null;
    final draftKey = selected == null ? null : _draftKey(selected);
    return PopScope(
      canPop: !hasSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && hasSelection) _closeConversation();
      },
      child: SimpleScaffold(
        backgroundColor: harmony ? theme.scaffoldBackgroundColor : null,
        appBar: !split && hasSelection
            ? null
            : AppBar(
                title: const Text('消息'),
                actions: [
                  messageActionSurface(
                    context,
                    IconButton(
                      tooltip: '新增粉丝',
                      onPressed: () => Get.toNamed(
                        '/webview',
                        parameters: {
                          'url':
                              'https://www.bilibili.com/h5/follow/newFans?navhide=1&${ThemeUtils.themeUrl(theme.isDark)}',
                        },
                      ),
                      icon: const Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  Obx(() {
                    final outsideItem = _controller.outsideItem.value;
                    if (outsideItem != null && outsideItem.isNotEmpty) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: outsideItem.map((e) {
                          return messageActionSurface(
                            context,
                            IconButton(
                              tooltip: e.hasTitle() ? e.title : null,
                              onPressed: () => e.type.action(
                                context: context,
                                controller: _controller,
                                item: e,
                              ),
                              icon: e.type.icon,
                            ),
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    final threeDotItems = _controller.threeDotItems.value;
                    if (threeDotItems != null && threeDotItems.isNotEmpty) {
                      return messageActionSurface(
                        context,
                        PopupMenuButton(
                          tooltip: '更多',
                          itemBuilder: (context) {
                            return threeDotItems
                                .map(
                                  (e) => PopupMenuItem(
                                    onTap: () => e.type.action(
                                      context: context,
                                      controller: _controller,
                                      item: e,
                                    ),
                                    child: Row(
                                      children: [
                                        e.type.icon,
                                        Text('  ${e.title}'),
                                      ],
                                    ),
                                  ),
                                )
                                .toList();
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(width: 8),
                ],
              ),
        body: MessageSplit(
          split: split,
          hasSelection: hasSelection,
          list: refreshIndicator(
            onRefresh: _controller.onRefresh,
            child: CustomScrollView(
              key: const PageStorageKey('message-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildTopItems(theme, padding),
                SliverPadding(
                  padding: EdgeInsets.only(bottom: padding.bottom + 24),
                  sliver: Obx(() => _buildBody(_controller.loadingState.value)),
                ),
              ],
            ),
          ),
          detail: MediaQuery.removePadding(
            context: context,
            removeTop: split,
            child: _notification != null
                ? _notificationPage(_notification!)
                : selected == null
                ? (split
                      ? const Center(child: Text('选择一条消息，开始查看'))
                      : const SizedBox.shrink())
                : WhisperDetailPage(
                    key: ValueKey(draftKey),
                    conversation: selected,
                    items: _drafts[draftKey],
                    onClose: _closeConversation,
                    onDraftChanged: (items) {
                      if (items.isEmpty) {
                        _drafts.remove(draftKey);
                      } else {
                        _drafts[draftKey!] = items;
                      }
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _notificationPage(String route) => switch (route) {
    '/replyMe' => ReplyMePage(
      key: const ValueKey('replyMe'),
      onClose: _closeConversation,
    ),
    '/atMe' => AtMePage(
      key: const ValueKey('atMe'),
      onClose: _closeConversation,
    ),
    '/likeMe' => LikeMePage(
      key: const ValueKey('likeMe'),
      onClose: _closeConversation,
    ),
    _ => SysMsgPage(key: const ValueKey('sysMsg'), onClose: _closeConversation),
  };

  Widget _buildBody(LoadingState<List<Session>?> loadingState) {
    switch (loadingState) {
      case Loading():
        if (HarmonyStyle.enabled(context)) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: m3eLoading),
          );
        }
        return const SliverPrototypeExtentList(
          prototypeItem: WhisperItemSkeleton(),
          delegate: SliverSingleChildDelegate(
            count: 12,
            child: WhisperItemSkeleton(),
          ),
        );
      case Success(:final response):
        if (response != null && response.isNotEmpty) {
          final divider = Divider(
            indent: 72,
            endIndent: 20,
            height: 0,
            color: Colors.grey.withValues(alpha: 0.1),
          );
          return SliverList.separated(
            itemCount: response.length,
            itemBuilder: (context, index) {
              if (index == response.length - 1) {
                _controller.onLoadMore();
              }
              final item = response[index];
              return WhisperSessionItem(
                item: item,
                onOpen: _openConversation,
                selected:
                    _selected?['talkerId'] ==
                    item.id.privateId.talkerUid.toInt(),
                onSetTop: (isTop, id) =>
                    _controller.onSetTop(item, index, isTop, id),
                onSetMute: (isMuted, talkerUid) =>
                    _controller.onSetMute(item, isMuted, talkerUid),
                onRemove: (talkerId) => _controller.onRemove(index, talkerId),
              );
            },
            separatorBuilder: (context, index) => divider,
          );
        }
        return HttpError(onReload: _controller.onReload);
      case Error(:final errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _controller.onReload,
        );
    }
  }

  Widget _buildTopItems(ThemeData theme, EdgeInsets padding) {
    final harmony = HarmonyStyle.enabled(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        padding.left + 12,
        12,
        padding.right + 12,
        18,
      ),
      sliver: SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final columns =
                bounds.maxWidth <
                    MediaQuery.textScalerOf(context).scale(13) * 21
                ? 2
                : 4;
            return Wrap(
              children: List.generate(_controller.msgFeedTopItems.length, (
                index,
              ) {
                final item = _controller.msgFeedTopItems[index];
                return SizedBox(
                  width: bounds.maxWidth / columns,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      if (!item.enabled) {
                        SmartDialog.showToast('已禁用');
                        return;
                      }
                      _controller.unreadCounts[index] = 0;
                      setState(() {
                        _selected = null;
                        _notification = item.route;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Obx(() {
                            final count = _controller.unreadCounts[index];
                            final icon = SizedBox.square(
                              dimension: 48,
                              child: Icon(
                                item.icon,
                                size: 23,
                                color: theme.colorScheme.onSurface,
                              ),
                            );
                            return Badge(
                              isLabelVisible: count > 0,
                              label: Text('$count'),
                              child: harmony
                                  ? ImmersiveSurface(
                                      borderRadius: BorderRadius.circular(24),
                                      child: icon,
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          theme.colorScheme.onInverseSurface,
                                      child: icon,
                                    ),
                            );
                          }),
                          const SizedBox(height: 9),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
