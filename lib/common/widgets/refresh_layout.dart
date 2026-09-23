import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart'
    show displacement, kIndicatorSize;
import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, ClipRectLayer;
import 'package:material_ui/material_ui.dart' hide RefreshIndicatorStatus;

enum RefreshType { indicator, body }

class RefreshLayout
    extends SlottedMultiChildRenderObjectWidget<RefreshType, RenderBox> {
  const RefreshLayout({
    super.key,
    required this.scale,
    required this.position,
    required this.indicator,
    required this.body,
    this.edgeOffset = 0.0,
    this.bodyOverscroll,
    this.holdExtent,
  });

  final double? holdExtent;
  final Animation<double> scale;
  final Animation<double> position;
  final Widget? indicator;
  final Widget body;
  final ValueListenable<double>? bodyOverscroll;

  /// 指示器出现位置相对顶边的下移量，对应 RefreshIndicator.edgeOffset。
  /// 上游 RefreshLayout 无此参数；鸿蒙沉浸顶栏下列表顶边在 ArkTS 顶栏
  /// 后面，须把指示器下移到顶栏底边，否则整个被顶栏盖住。
  final double edgeOffset;

  @override
  Iterable<RefreshType> get slots => RefreshType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .indicator => indicator,
    .body => body,
  };

  @override
  RenderRefreshLayout createRenderObject(BuildContext context) {
    return RenderRefreshLayout(
      scale: scale,
      holdExtent: holdExtent,
      position: position,
      edgeOffset: edgeOffset,
      bodyOverscroll: bodyOverscroll,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRefreshLayout renderObject,
  ) {
    renderObject
      ..scale = scale
      ..position = position
      ..holdExtent = holdExtent
      ..edgeOffset = edgeOffset
      ..bodyOverscroll = bodyOverscroll;
  }
}

class RenderRefreshLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<RefreshType, RenderBox> {
  RenderRefreshLayout({
    required Animation<double> scale,
    required Animation<double> position,
    double edgeOffset = 0.0,
    double? holdExtent,
    ValueListenable<double>? bodyOverscroll,
  }) : _scale = scale,
       _position = position,
       _edgeOffset = edgeOffset,
       _holdExtent = holdExtent {
    this.bodyOverscroll = bodyOverscroll;
    _scaleFactor = scale.value;
    _heightFactor = position.value;
    scale.addListener(_scaleListener);
    position.addListener(_positionListener);
  }

  Animation<double> _scale;
  Animation<double> get scale => _scale;
  set scale(Animation<double> value) {
    if (_scale == value) return;
    _scale.removeListener(_scaleListener);
    _scale = value..addListener(_scaleListener);
    _scaleListener();
  }

  Animation<double> _position;
  Animation<double> get position => _position;
  set position(Animation<double> value) {
    if (_position == value) return;
    _position.removeListener(_positionListener);
    _position = value..addListener(_positionListener);
    _positionListener();
  }

  double? _holdExtent;
  set holdExtent(double? value) {
    if (_holdExtent == value) return;
    _holdExtent = value;
    _bodyPositionChanged();
  }

  double get _target =>
      (_holdExtent ?? (kIndicatorSize + displacement)) *
      heightFactor *
      scaleFactor;

  ValueListenable<double>? _bodyOverscroll;
  set bodyOverscroll(ValueListenable<double>? value) {
    if (_bodyOverscroll == value) return;
    _bodyOverscroll?.removeListener(_bodyPositionChanged);
    _bodyOverscroll = value;
    value?.addListener(_bodyPositionChanged);
    _bodyPositionChanged();
  }

  void _bodyPositionChanged() {
    if (!hasSize) return;
    final target = _target;
    // A bouncing viewport already shifts its contents. Only supply the missing
    // displacement, then hold it after the viewport springs back to zero.
    final shift = _bodyOverscroll == null
        ? 0.0
        : ((target > _bodyOverscroll!.value ? target : _bodyOverscroll!.value)
                  .clamp(0.0, 88.0) -
              _bodyOverscroll!.value);
    setOffset(body, Offset(0, shift));
    _layoutIndicator();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  double _edgeOffset;
  double get edgeOffset => _edgeOffset;
  set edgeOffset(double value) {
    if (_edgeOffset == value) {
      return;
    }
    _edgeOffset = value;
    _layoutIndicator();
    _bodyPositionChanged();
    markNeedsPaint();
  }

  double _heightFactor = 0;
  double get heightFactor => _heightFactor;
  set heightFactor(double value) {
    if (_heightFactor == value) {
      return;
    }
    _heightFactor = value;
    _layoutIndicator();
    _bodyPositionChanged();
    markNeedsPaint();
  }

  double _scaleFactor = 0;
  double get scaleFactor => _scaleFactor;
  set scaleFactor(double value) {
    if (_scaleFactor == value) {
      return;
    }
    _scaleFactor = value;
    _layoutIndicator();
    _bodyPositionChanged();
    markNeedsPaint();
  }

  void _scaleListener() {
    scaleFactor = scale.value;
  }

  void _positionListener() {
    heightFactor = position.value;
  }

  @override
  void dispose() {
    _bodyOverscroll?.removeListener(_bodyPositionChanged);
    scale.removeListener(_scaleListener);
    position.removeListener(_positionListener);
    super.dispose();
  }

  RenderBox? get indicator => childForSlot(.indicator);
  RenderBox get body => childForSlot(.body)!;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final body = this.body..layout(constraints);
    setOffset(body, .zero);
    _bodyPositionChanged();

    _layoutIndicator();
  }

  void _layoutIndicator() {
    final indicator = this.indicator;
    if (indicator == null) return;
    final scaleSize = kIndicatorSize * scaleFactor;
    final hold = _target;
    final gap = _bodyOverscroll == null
        ? 0.0
        : (_bodyOverscroll!.value > hold ? _bodyOverscroll!.value : hold);
    indicator.layout(
      BoxConstraints.tightFor(width: scaleSize, height: scaleSize),
    );
    setOffset(
      indicator,
      Offset(
        (constraints.maxWidth - scaleSize) / 2,
        _bodyOverscroll != null
            ? edgeOffset + (gap.clamp(0.0, 88.0) - scaleSize) / 2
            : edgeOffset +
                  (kIndicatorSize + displacement) * heightFactor -
                  kIndicatorSize +
                  (kIndicatorSize - scaleSize) / 2,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox child) {
      context.paintChild(child, getOffset(child) + offset);
    }

    doPaint(body);
    final indicator = this.indicator;
    if (indicator != null && heightFactor > 0 && scaleFactor > 0) {
      final indicatorOffset = getOffset(indicator);
      if (indicatorOffset.dy > edgeOffset) {
        context.paintChild(indicator, indicatorOffset + offset);
        layer = null;
      } else {
        layer = context.pushClipRect(
          needsCompositing,
          offset,
          Rect.fromLTRB(0, edgeOffset, size.width, size.height),
          (context, offset) {
            context.paintChild(indicator, indicatorOffset + offset);
          },
          clipBehavior: .hardEdge,
          oldLayer: layer as ClipRectLayer?,
        );
      }
    } else {
      layer = null;
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = getOffset(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final body = this.body;
    return result.addWithPaintOffset(
      offset: getOffset(body),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return body.hitTest(result, position: transformed);
      },
    );
  }
}
