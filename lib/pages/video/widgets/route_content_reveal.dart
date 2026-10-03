import 'dart:async';
import 'package:flutter/material.dart';

/// Networking may start immediately; expensive presentation waits for the route.
/// Returning before entrance completes cancels presentation rather than starting
/// a player underneath the previous page.
Future<bool> waitForVideoEntrance(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route?.offstage == true) {
    final pending = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      pending.complete(
        context.mounted && route!.isCurrent
            ? await waitForVideoEntrance(context)
            : false,
      );
    });
    return pending.future;
  }
  final animation = route?.animation;
  if (route == null ||
      animation == null ||
      MediaQuery.disableAnimationsOf(context) ||
      (!route.offstage && animation.status == AnimationStatus.completed)) {
    return Future.value(route?.isCurrent ?? true);
  }
  final result = Completer<bool>();
  late AnimationStatusListener listener;
  void finish(bool entered) {
    if (result.isCompleted) return;
    animation.removeStatusListener(listener);
    result.complete(entered);
  }

  listener = (status) {
    if (status == AnimationStatus.completed && !route.offstage)
      finish(route.isCurrent);
    if (status == AnimationStatus.dismissed) finish(false);
  };
  animation.addStatusListener(listener);
  route.popped.then((_) => finish(false));
  return result.future;
}

/// A single short reveal, with no placeholder size change or outgoing overlay.
/// The parent owns the panel's fixed bounds. Sliver mode retains lazy lists.
class RouteContentReveal extends StatefulWidget {
  const RouteContentReveal({
    super.key,
    required this.ready,
    required this.builder,
    this.sliver = false,
  });
  final bool ready;
  final WidgetBuilder builder;
  final bool sliver;
  @override
  State<RouteContentReveal> createState() => _RouteContentRevealState();
}

class _RouteContentRevealState extends State<RouteContentReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  bool _listening = false;
  bool _entered = false;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listening) return;
    _listening = true;
    waitForVideoEntrance(context).then((entered) {
      if (!mounted || !entered) return;
      setState(() {
        _entered = true;
        _reveal();
      });
    });
  }

  void _reveal() {
    if (!_entered || !widget.ready || _visible) return;
    _visible = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RouteContentReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reveal();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible)
      return widget.sliver
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.expand();
    final child = widget.builder(context);
    return widget.sliver
        ? SliverFadeTransition(opacity: _fade, sliver: child)
        : FadeTransition(
            opacity: _fade,
            child: RepaintBoundary(child: child),
          );
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }
}
