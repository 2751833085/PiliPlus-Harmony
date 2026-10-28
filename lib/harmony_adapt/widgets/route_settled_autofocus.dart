import 'package:flutter/widgets.dart';

/// Requests initial text focus after the current route's entrance has settled.
/// Starting an IME can launch a native service and relayout the page for its
/// insets; keep that work out of the route's first moving frames. This does not
/// delay an explicit tap, change the transition or own/dispose the focus node.
class RouteSettledAutofocus extends StatefulWidget {
  const RouteSettledAutofocus({
    super.key,
    required this.focusNode,
    required this.child,
    this.enabled = true,
  });

  final FocusNode focusNode;
  final Widget child;
  final bool enabled;

  @override
  State<RouteSettledAutofocus> createState() => _RouteSettledAutofocusState();
}

class _RouteSettledAutofocusState extends State<RouteSettledAutofocus> {
  ModalRoute<dynamic>? _route;
  bool _requested = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToRoute(ModalRoute.of(context));
    _schedule();
  }

  @override
  void didUpdateWidget(RouteSettledAutofocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _requested = false;
    }
    _schedule();
  }

  void _listenToRoute(ModalRoute<dynamic>? route) {
    if (identical(route, _route)) return;
    _route?.animation?.removeStatusListener(_onStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onStatus);
    _route = route;
    route?.animation?.addStatusListener(_onStatus);
    route?.secondaryAnimation?.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus _) => _schedule();

  void _onFocusChanged() {
    // A user may start typing before the entrance ends. Do not request again
    // later (e.g. after the keyboard has been dismissed by that user).
    if (widget.focusNode.hasFocus) _requested = true;
  }

  bool get _ready {
    final route = _route;
    return widget.enabled &&
        !_requested &&
        widget.focusNode.canRequestFocus &&
        (route == null ||
            (route.isActive &&
                route.isCurrent &&
                !route.offstage &&
                (route.animation == null ||
                    route.animation!.status == AnimationStatus.completed) &&
                (route.secondaryAnimation?.value ?? 0) == 0));
  }

  void _schedule() {
    if (_scheduled || !_ready) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_ready) return;
      _requested = true;
      widget.focusNode.requestFocus();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _listenToRoute(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
