import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Short videos expose the live frame and gestures immediately. Keep the plain
/// layout condition outside Obx: a branch with no Rx reads creates GetX's grey
/// release ErrorWidget, which covers the video and intercepts its gestures.
class PlaybackCover extends StatelessWidget {
  const PlaybackCover({
    super.key,
    required this.shortMode,
    required this.autoPlay,
    required this.builder,
  });
  final bool shortMode;
  final ValueGetter<bool> autoPlay;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => shortMode
      ? const SizedBox.shrink()
      : Obx(() => autoPlay() ? const SizedBox.shrink() : builder(context));
}
