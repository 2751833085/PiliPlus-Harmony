// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// Refresh-space render object adapted from Flutter's Cupertino refresh control.
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';

/// The scroll position owns drag resistance and spring motion. This sliver only
/// reserves space during refresh; it never transforms the list or drives a
/// second scroll animation.
class ElasticRefreshSliver extends StatefulWidget {
  const ElasticRefreshSliver({
    super.key,
    required this.onRefresh,
    this.edgeOffset = 0,
  });
  final Future<void> Function() onRefresh;
  final double edgeOffset;
  @override
  State<ElasticRefreshSliver> createState() => ElasticRefreshSliverState();
}

class ElasticRefreshSliverState extends State<ElasticRefreshSliver>
    with SingleTickerProviderStateMixin {
  static const trigger = 72.0;
  static const heldExtent = 64.0;
  double _extent = 0;
  bool _holding = false;
  int? _pointer;
  Future<void>? _task;
  late final _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 280),
  );

  void pointerDown(PointerDownEvent event) {
    _pointer ??= event.pointer;
    if (_task == null && !_holding) _fade.value = 1;
  }

  void pointerCancel(PointerCancelEvent event) {
    if (_pointer == event.pointer) _pointer = null;
  }

  void pointerUp(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    // Pointer events can arrive before the first layout after a fast pull.
    // Read the live scroll position instead of the last painted header extent.
    final position = Scrollable.maybeOf(context)?.position;
    final pull = position != null && position.hasContentDimensions
        ? position.minScrollExtent - position.pixels
        : _extent;
    if (pull >= trigger && !_holding && _task == null) show();
  }

  Future<void> show({bool reveal = false}) {
    if (_task case final task?) return task;
    final completion = Completer<void>();
    _task = completion.future;
    _fade.value = 1;
    setState(() => _holding = true);
    if (reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_holding) return;
        final position = Scrollable.maybeOf(context)?.position;
        if (position != null && position.hasContentDimensions) {
          position.animateTo(
            position.minScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    Future<void>(() async {
      try {
        await widget.onRefresh();
      } catch (error) {
        debugPrint('Refresh failed: $error');
      } finally {
        if (mounted) {
          if (!MediaQuery.disableAnimationsOf(context)) {
            await _fade.reverse().orCancel.catchError((Object _) {});
          }
          if (mounted) setState(() => _holding = false);
        }
        _task = null;
        completion.complete();
      }
    });
    return completion.future;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ScrollRefreshSpace(
    refreshIndicatorLayoutExtent: heldExtent,
    hasLayoutExtent: _holding,
    child: LayoutBuilder(
      builder: (context, constraints) {
        _extent = constraints.maxHeight;
        if (_extent <= 0) return const SizedBox.shrink();
        // Paint below the native top bar without shifting the scrollable itself.
        return Transform.translate(
          offset: Offset(0, widget.edgeOffset),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  top: min((_extent - 24) / 2, _extent - 44),
                  left: 0,
                  right: 0,
                  height: 24,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _fade,
                      builder: (context, _) => HarmonyLoadingIndicator(
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        opacity:
                            _fade.value *
                            Curves.easeInOut.transform(
                              (_extent / trigger).clamp(0.0, 1.0),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ScrollRefreshSpace extends SingleChildRenderObjectWidget {
  const _ScrollRefreshSpace({
    this.refreshIndicatorLayoutExtent = 0.0,
    this.hasLayoutExtent = false,
    super.child,
  }) : assert(refreshIndicatorLayoutExtent >= 0.0);

  // The amount of space the indicator should occupy in the sliver in a
  // resting state when in the refreshing mode.
  final double refreshIndicatorLayoutExtent;

  // _RenderScrollRefreshSpace will paint the child in the available
  // space either way but this instructs the _RenderScrollRefreshSpace
  // on whether to also occupy any layoutExtent space or not.
  final bool hasLayoutExtent;

  @override
  _RenderScrollRefreshSpace createRenderObject(BuildContext context) {
    return _RenderScrollRefreshSpace(
      refreshIndicatorExtent: refreshIndicatorLayoutExtent,
      hasLayoutExtent: hasLayoutExtent,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderScrollRefreshSpace renderObject,
  ) {
    renderObject
      ..refreshIndicatorLayoutExtent = refreshIndicatorLayoutExtent
      ..hasLayoutExtent = hasLayoutExtent;
  }
}

// RenderSliver object that gives its child RenderBox object space to paint
// in the overscrolled gap and may or may not hold that overscrolled gap
// around the RenderBox depending on whether [layoutExtent] is set.
//
// The [layoutExtentOffsetCompensation] field keeps internal accounting to
// prevent scroll position jumps as the [layoutExtent] is set and unset.
class _RenderScrollRefreshSpace extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderScrollRefreshSpace({
    required double refreshIndicatorExtent,
    required bool hasLayoutExtent,
    RenderBox? child,
  }) : assert(refreshIndicatorExtent >= 0.0),
       _refreshIndicatorExtent = refreshIndicatorExtent,
       _hasLayoutExtent = hasLayoutExtent {
    this.child = child;
  }

  // The amount of layout space the indicator should occupy in the sliver in a
  // resting state when in the refreshing mode.
  double get refreshIndicatorLayoutExtent => _refreshIndicatorExtent;
  double _refreshIndicatorExtent;
  set refreshIndicatorLayoutExtent(double value) {
    assert(value >= 0.0);
    if (value == _refreshIndicatorExtent) {
      return;
    }
    _refreshIndicatorExtent = value;
    markNeedsLayout();
  }

  // The child box will be laid out and painted in the available space either
  // way but this determines whether to also occupy any
  // [SliverGeometry.layoutExtent] space or not.
  bool get hasLayoutExtent => _hasLayoutExtent;
  bool _hasLayoutExtent;
  set hasLayoutExtent(bool value) {
    if (value == _hasLayoutExtent) {
      return;
    }
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  // This keeps track of the previously applied scroll offsets to the scrollable
  // so that when [refreshIndicatorLayoutExtent] or [hasLayoutExtent] changes,
  // the appropriate delta can be applied to keep everything in the same place
  // visually.
  double layoutExtentOffsetCompensation = 0.0;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    // Only pulling to refresh from the top is currently supported.
    assert(constraints.axisDirection == AxisDirection.down);
    assert(constraints.growthDirection == GrowthDirection.forward);

    // The new layout extent this sliver should now have.
    final double layoutExtent =
        (_hasLayoutExtent ? 1.0 : 0.0) * _refreshIndicatorExtent;
    // If the new layoutExtent instructive changed, the SliverGeometry's
    // layoutExtent will take that value (on the next performLayout run). Shift
    // the scroll offset first so it doesn't make the scroll position suddenly jump.
    if (layoutExtent != layoutExtentOffsetCompensation) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: layoutExtent - layoutExtentOffsetCompensation,
      );
      layoutExtentOffsetCompensation = layoutExtent;
      // Return so we don't have to do temporary accounting and adjusting the
      // child's constraints accounting for this one transient frame using a
      // combination of existing layout extent, new layout extent change and
      // the overlap.
      return;
    }

    final bool active = constraints.overlap < 0.0 || layoutExtent > 0.0;
    final double overscrolledExtent = constraints.overlap < 0.0
        ? constraints.overlap.abs()
        : 0.0;
    // Layout the child giving it the space of the currently dragged overscroll
    // which may or may not include a sliver layout extent space that it will
    // keep after the user lets go during the refresh process.
    child!.layout(
      constraints.asBoxConstraints(
        maxExtent:
            layoutExtent
            // Plus only the overscrolled portion immediately preceding this
            // sliver.
            +
            overscrolledExtent,
      ),
      parentUsesSize: true,
    );
    if (active) {
      geometry = SliverGeometry(
        scrollExtent: layoutExtent,
        paintOrigin: -overscrolledExtent - constraints.scrollOffset,
        paintExtent: max(
          // Check child size (which can come from overscroll) because
          // layoutExtent may be zero. Check layoutExtent also since even
          // with a layoutExtent, the indicator builder may decide to not
          // build anything.
          max(child!.size.height, layoutExtent) - constraints.scrollOffset,
          0.0,
        ),
        maxPaintExtent: max(
          max(child!.size.height, layoutExtent) - constraints.scrollOffset,
          0.0,
        ),
        layoutExtent: max(layoutExtent - constraints.scrollOffset, 0.0),
      );
    } else {
      // If we never started overscrolling, return no geometry.
      geometry = SliverGeometry.zero;
    }
  }

  @override
  void paint(PaintingContext paintContext, Offset offset) {
    if (constraints.overlap < 0.0 ||
        constraints.scrollOffset + child!.size.height > 0) {
      paintContext.paintChild(child!, offset);
    }
  }

  // Nothing special done here because this sliver always paints its child
  // exactly between paintOrigin and paintExtent.
  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}
