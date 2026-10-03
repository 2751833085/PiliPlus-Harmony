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
        context.mounted && route!.isActive
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
    return Future.value(route?.isActive ?? true);
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
      finish(route.isActive);
    if (status == AnimationStatus.dismissed) finish(false);
  };
  animation.addStatusListener(listener);
  route.popped.then((_) => finish(false));
  return result.future;
}
