import 'dart:async';
import 'package:flutter/material.dart';

/// Mount immediate neighbours on a later event-loop turn after route/tab motion.
/// A cancellable timer avoids low-priority scheduler tasks spinning while busy.
class IdleTabPreload extends StatefulWidget {
  const IdleTabPreload({super.key, required this.builder, this.controller});
  final Widget Function(BuildContext, bool) builder;
  final TabController? controller;
  @override
  State<IdleTabPreload> createState() => _IdleTabPreloadState();
}

class _IdleTabPreloadState extends State<IdleTabPreload> {
  ModalRoute<dynamic>? _route;
  TabController? _tabs;
  bool _prepared = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _route?.animation?.removeStatusListener(_status);
      _route?.secondaryAnimation?.removeStatusListener(_status);
      _route = route;
      route?.animation?.addStatusListener(_status);
      route?.secondaryAnimation?.addStatusListener(_status);
    }
    _tabs = widget.controller ?? DefaultTabController.maybeOf(context);
    _schedule();
  }

  @override
  void didUpdateWidget(IdleTabPreload oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tabs = widget.controller ?? DefaultTabController.maybeOf(context);
    _schedule();
  }

  void _status(AnimationStatus _) => _schedule();

  bool get _idleRoute =>
      _route == null ||
      (_route!.isCurrent &&
          _route!.animation?.status == AnimationStatus.completed);
  bool get _idleTab {
    final value = _tabs?.animation?.value;
    return _tabs?.indexIsChanging != true &&
        (value == null || (value - value.round()).abs() < .001);
  }

  void _schedule() {
    if (_prepared || _timer != null || !_idleRoute) return;
    _timer = Timer(const Duration(milliseconds: 32), () {
      _timer = null;
      if (!mounted || _prepared || !_idleRoute) return;
      if (_idleTab) {
        setState(() => _prepared = true);
      } else {
        _schedule();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _route?.animation?.removeStatusListener(_status);
    _route?.secondaryAnimation?.removeStatusListener(_status);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _prepared);
}
