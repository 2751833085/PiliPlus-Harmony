import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:PiliPlus/common/widgets/flutter/page/tabs.dart' as paging;

final _pendingNavigations = Expando<_PendingNavigation>();

/// Resolve a card's destination once, and never navigate from a stale card/tab.
/// The weak context key avoids retaining removed feed cards after completion.
Future<void> runGuardedNavigation(
  BuildContext context,
  Future<void> Function(bool Function() isCurrent) action,
) {
  final pending = _pendingNavigations[context];
  if (pending != null && pending.guard.isCurrent()) return pending.future;
  final guard = _NavigationGuard(context);
  late Future<void> future;
  future =
      Future<void>.sync(() async {
        if (guard.isCurrent()) await action(guard.isCurrent);
      }).whenComplete(() {
        guard.dispose();
        if (identical(_pendingNavigations[context]?.future, future)) {
          _pendingNavigations[context] = null;
        }
      });
  _pendingNavigations[context] = _PendingNavigation(guard, future);
  return future;
}

class _PendingNavigation {
  const _PendingNavigation(this.guard, this.future);
  final _NavigationGuard guard;
  final Future<void> future;
}

class _NavigationGuard {
  _NavigationGuard(this.context)
    : originalWidget = context.widget,
      route = ModalRoute.of(context),
      ticker = TickerMode.getValuesNotifier(context) {
    localHistory = route?.willHandlePopInternally ?? false;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is TabBarView) {
        tabs = widget.controller ?? DefaultTabController.maybeOf(element);
        return false;
      }
      if (widget is paging.TabBarView<HorizontalDragGestureRecognizer>) {
        tabs = widget.controller ?? DefaultTabController.maybeOf(element);
        return false;
      }
      return true;
    });
    tabIndex = tabs?.index;
    tabs?.addListener(_checkTabs);
    tabs?.animation?.addListener(_checkTabs);
    ticker.addListener(_checkTicker);
    route?.animation?.addStatusListener(_primaryStatus);
    route?.secondaryAnimation?.addStatusListener(_secondaryStatus);
  }
  final BuildContext context;
  final Widget originalWidget;
  final ModalRoute<dynamic>? route;
  final ValueListenable<TickerModeData> ticker;
  late final bool localHistory;
  TabController? tabs;
  int? tabIndex;
  bool _valid = true;

  void _checkTicker() {
    if (!ticker.value.enabled) _valid = false;
  }

  void _checkTabs() {
    final value = tabs?.animation?.value;
    if (tabs?.index != tabIndex ||
        tabs?.indexIsChanging == true ||
        (value != null &&
            tabIndex != null &&
            (value - tabIndex!).abs() > .001)) {
      _valid = false;
    }
  }

  void _primaryStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _valid = false;
    }
  }

  void _secondaryStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      _valid = false;
    }
  }

  bool isCurrent() {
    if (!_valid || !context.mounted) return false;
    _checkTabs();
    return _valid &&
        identical(context.widget, originalWidget) &&
        ticker.value.enabled &&
        (route == null ||
            (route!.isCurrent &&
                route!.isActive &&
                route!.willHandlePopInternally == localHistory));
  }

  void dispose() {
    _valid = false;
    tabs?.removeListener(_checkTabs);
    tabs?.animation?.removeListener(_checkTabs);
    ticker.removeListener(_checkTicker);
    route?.animation?.removeStatusListener(_primaryStatus);
    route?.secondaryAnimation?.removeStatusListener(_secondaryStatus);
  }
}
