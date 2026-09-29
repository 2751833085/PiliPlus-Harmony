import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/models_new/search/search_trending/list.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/rendering.dart'
    show
        ContainerRenderObjectMixin,
        MultiChildLayoutParentData,
        RenderBoxContainerDefaultsMixin,
        BoxHitTestResult;
import 'package:material_ui/material_ui.dart';

class SliverHotKeyword extends StatelessWidget {
  final List<SearchTrendingItemModel> hotSearchList;
  final Function? onClick;
  final bool filled;
  const SliverHotKeyword({
    super.key,
    required this.hotSearchList,
    this.onClick,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    late final style = TextStyle(
      fontSize: 14,
      color: ColorScheme.of(context).outline,
    );

    late final cacheHeight = (MediaQuery.devicePixelRatioOf(context) * 15.0)
        .round();

    return SliverToBoxAdapter(
      child: _HotKeywordGrid(
        mainAxisSpacing: 8,
        crossAxisSpacing: filled ? 8 : 4,
        crossAxisCount: 2,
        children: hotSearchList
            .map(
              (i) => Material(
                type: filled ? MaterialType.canvas : MaterialType.transparency,
                color: filled
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : null,
                borderRadius: const .all(.circular(3)),
                child: InkWell(
                  borderRadius: const .all(.circular(3)),
                  onTap: () => onClick?.call(i.keyword),
                  child: Padding(
                    padding: const .only(left: 2, right: 10),
                    child: Tooltip(
                      message: i.showName,
                      child: Row(
                        children: [
                          Flexible(
                            child: Padding(
                              padding: const .fromLTRB(6, 8, 0, 8),
                              child: Text(
                                i.showName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          if (!i.icon.isNullOrEmpty)
                            Padding(
                              padding: const .only(left: 4),
                              child: CachedNetworkImage(
                                height: 15,
                                memCacheHeight: cacheHeight,
                                imageUrl: ImageUtils.thumbnailUrl(i.icon!),
                                placeholder: (_, _) => const SizedBox.shrink(),
                              ),
                            )
                          else if (i.showLiveIcon == true)
                            Padding(
                              padding: const .only(left: 4),
                              child: Image.asset(
                                Assets.livingRect,
                                width: 48,
                                height: 15,
                                cacheHeight: cacheHeight,
                              ),
                            )
                          else if (i.recommendReason?.isNotEmpty == true)
                            Text(i.recommendReason!, style: style),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HotKeywordGrid extends MultiChildRenderObjectWidget {
  const _HotKeywordGrid({
    required this.crossAxisCount,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    required super.children,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0.0),
       assert(crossAxisSpacing >= 0.0);

  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHotKeywordGrid(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHotKeywordGrid renderObject,
  ) {
    renderObject
      ..crossAxisCount = crossAxisCount
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing;
  }
}

class _RenderHotKeywordGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  _RenderHotKeywordGrid({
    required int crossAxisCount,
    required double mainAxisSpacing,
    required double crossAxisSpacing,
  }) : _crossAxisCount = crossAxisCount,
       _mainAxisSpacing = mainAxisSpacing,
       _crossAxisSpacing = crossAxisSpacing;

  int _crossAxisCount;
  int get crossAxisCount => _crossAxisCount;
  set crossAxisCount(int value) {
    if (_crossAxisCount == value) return;
    _crossAxisCount = value;
    markNeedsLayout();
  }

  double _mainAxisSpacing;
  double get mainAxisSpacing => _mainAxisSpacing;
  set mainAxisSpacing(double value) {
    if (_mainAxisSpacing == value) return;
    _mainAxisSpacing = value;
    markNeedsLayout();
  }

  double _crossAxisSpacing;
  double get crossAxisSpacing => _crossAxisSpacing;
  set crossAxisSpacing(double value) {
    if (_crossAxisSpacing == value) return;
    _crossAxisSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final childWidth =
        (constraints.maxWidth - mainAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
    final c = BoxConstraints(maxWidth: childWidth);
    var child = firstChild;
    double? childHeight;
    int index = 0;
    while (child != null) {
      if (childHeight == null) {
        childHeight = (child..layout(c, parentUsesSize: true)).size.height;
      } else {
        child.layout(c);
      }
      final parentData = child.parentData as MultiChildLayoutParentData
        ..offset = Offset(
          (childWidth + mainAxisSpacing) * (index % crossAxisCount),
          (childHeight + crossAxisSpacing) * (index ~/ crossAxisCount),
        );
      child = parentData.nextSibling;
      index++;
    }
    final row = (index / crossAxisCount).ceil();
    size = constraints.constrainDimensions(
      constraints.maxWidth,
      row == 0 ? 0 : row * childHeight! + crossAxisSpacing * (row - 1),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
