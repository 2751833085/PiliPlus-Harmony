import 'package:material_ui/material_ui.dart';
import 'session.dart';

/// Only the selected page owns the live player. Neighbours contain covers only.
/// The last page remains playable when recommendations fail or are exhausted.
class ShortVideoPager extends StatefulWidget {
  const ShortVideoPager({
    super.key,
    required this.session,
    required this.builder,
    this.onError,
    this.enabled = true,
  });
  final ShortVideoSession session;
  final Widget Function(BuildContext context, int index, bool active) builder;
  final ValueChanged<String>? onError;
  final bool enabled;
  @override
  State<ShortVideoPager> createState() => _ShortVideoPagerState();
}

class _ShortVideoPagerState extends State<ShortVideoPager> {
  late final PageController _pages = PageController(
    initialPage: widget.session.index,
  );
  double _pull = 0;
  bool _armed = false;
  bool _startedAtFirst = false;
  ShortVideoSession get session => widget.session;
  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) session.loadMore();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  Future<void> _select(int index) async {
    final accepted = await session.select(index);
    if (!mounted) return;
    if (!accepted && _pages.hasClients) _pages.jumpToPage(session.index);
    if (session.error case final message?) widget.onError?.call(message);
    if (session.entries.length - session.index <= 3) session.loadMore();
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (event is ScrollStartNotification) {
      _pull = 0;
      _armed = false;
      _startedAtFirst = session.index == 0 && event.metrics.pixels <= 0;
    }
    if (event.metrics.pixels > 0) _armed = false;
    if (event is OverscrollNotification &&
        event.dragDetails != null &&
        _startedAtFirst &&
        session.index == 0 &&
        event.metrics.pixels <= 0 &&
        widget.enabled &&
        !session.switching &&
        !session.interacting &&
        !session.refreshing) {
      _pull = (_pull - event.overscroll).clamp(0, 160);
      if (_pull >= 72 && session.loadFresh != null) _armed = true;
    }
    if (event is ScrollEndNotification && _armed) {
      _armed = false;
      session.refresh().then((_) {
        if (mounted && session.error != null)
          widget.onError?.call(session.error!);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          physics:
              !widget.enabled ||
                  session.switching ||
                  session.refreshing ||
                  session.interacting
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
          onPageChanged: _select,
          itemCount: session.entries.length,
          itemBuilder: (context, index) => _RetainedVideoPage(
            active: index == session.index,
            child: widget.builder(context, index, index == session.index),
          ),
        ),
      );
}

/// A slow network request can outlast the page animation. Retain the old live
/// view until its GlobalKey moves to the newly accepted page in the same frame.
/// Cover-only pages never opt into keep-alive.
class _RetainedVideoPage extends StatefulWidget {
  const _RetainedVideoPage({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  State<_RetainedVideoPage> createState() => _RetainedVideoPageState();
}

class _RetainedVideoPageState extends State<_RetainedVideoPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.active;
  @override
  void didUpdateWidget(_RetainedVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
