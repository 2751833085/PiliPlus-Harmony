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
    this.onTargetChanged,
    this.enabled = true,
  });
  final ShortVideoSession session;
  final Widget Function(BuildContext context, int index, bool active) builder;
  final ValueChanged<String>? onError;
  final ValueChanged<int>? onTargetChanged;
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
  bool _scrolling = false;
  bool _selecting = false;
  late int _desiredIndex = session.index;
  late int _playerIndex = session.index;
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
    if (mounted) {
      _adoptSettledPlayer();
      setState(() {});
    }
  }

  void _adoptSettledPlayer() {
    // A superseded target may already be outside PageView's built range.
    // Keep the live GlobalKey in its retained page until the final visible
    // target is ready, so rapid paging cannot dispose/recreate the player.
    if (!_scrolling && !session.switching && session.index == _desiredIndex) {
      _playerIndex = session.index;
    }
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    _pages.dispose();
    super.dispose();
  }

  // PageView.onPageChanged fires halfway through a drag. Opening a new source
  // there changes the old page's texture and interrupts the snap animation.
  // Commit only settled pages, coalescing further swipes during a slow open.
  Future<void> _selectSettled() async {
    if (_selecting || _scrolling || !mounted) return;
    _selecting = true;
    try {
      while (mounted &&
          !_scrolling &&
          !session.refreshing &&
          !session.interacting &&
          _desiredIndex != session.index) {
        final index = _desiredIndex;
        final accepted = await session.select(index);
        if (!mounted) return;
        if (!accepted && _desiredIndex == index && !_scrolling) {
          _desiredIndex = session.index;
          if (_pages.hasClients) {
            await _pages.animateToPage(
              session.index,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          }
        }
        if (session.error case final message?) widget.onError?.call(message);
        if (session.entries.length - session.index <= 3) session.loadMore();
      }
    } finally {
      _selecting = false;
      if (mounted) {
        _adoptSettledPlayer();
        setState(() {});
      }
    }
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (event is ScrollStartNotification) {
      _scrolling = true;
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
    if (event is ScrollEndNotification) {
      _scrolling = false;
      _desiredIndex = (event.metrics as PageMetrics).page!.round();
      final refresh = _armed;
      _armed = false;
      // Scroll notifications arrive during layout. Defer state changes until
      // the frame has painted, without adding a delay to the gesture itself.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scrolling) return;
        if (refresh) {
          session.refresh().then((_) {
            if (mounted && session.error != null) {
              widget.onError?.call(session.error!);
            }
          });
        } else {
          _selectSettled();
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          // Begin network preparation while dragging, but never switch the
          // live source until the page settles.
          onPageChanged: widget.onTargetChanged,
          controller: _pages,
          // Decode adjacent covers before the user's drag; these pages never
          // create extra video players.
          allowImplicitScrolling: true,
          scrollDirection: Axis.vertical,
          physics:
              !widget.enabled ||
                  session.refreshing ||
                  session.interacting ||
                  session.dismissing
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
          itemCount: session.entries.length,
          itemBuilder: (context, index) => _RetainedVideoPage(
            active: index == _playerIndex,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.builder(context, index, false),
                if (index == _playerIndex)
                  Offstage(
                    offstage: session.switching || index != session.index,
                    child: widget.builder(context, index, true),
                  ),
              ],
            ),
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
