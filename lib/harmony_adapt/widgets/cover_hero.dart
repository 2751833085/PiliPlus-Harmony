import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:flutter/material.dart';

/// Only the cover flies. Text and the page body never contribute to its bounds.
class CoverHero extends StatelessWidget {
  const CoverHero({
    super.key,
    required this.tag,
    required this.cover,
    required this.aspectRatio,
    required this.child,
  });
  final Object? tag;
  final String? cover;
  final double aspectRatio;
  final Widget child;

  static RectTween rectTween(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  /// Keep the live player mounted while a separate cached cover is in flight.
  static Widget playerPlaceholder(
    BuildContext context,
    Size size,
    Widget child,
  ) => SizedBox.fromSize(
    size: size,
    child: Offstage(child: TickerMode(enabled: false, child: child)),
  );

  @override
  Widget build(BuildContext context) {
    if (tag == null || MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: tag!,
      createRectTween: rectTween,
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          ClipRect(
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 320,
                  height: 320 / aspectRatio,
                  child: NetworkImgLayer(
                    src: cover,
                    width: 320,
                    height: 320 / aspectRatio,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ),
          ),
      child: RepaintBoundary(child: child),
    );
  }
}
