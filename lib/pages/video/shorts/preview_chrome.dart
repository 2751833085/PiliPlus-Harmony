import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/pages/video/shorts/metrics.dart';

/// Read-only controls travel with a neighbour's preview, never act on the old
/// playback owner. The live page takes over at the same coordinates on settle.
class ShortPreviewChrome extends StatelessWidget {
  const ShortPreviewChrome({
    super.key,
    required this.showDetails,
  });
  final bool showDetails;
  @override
  Widget build(BuildContext context) {
    final metrics = ShortVideoMetrics.of(context);
    Widget icon(IconData icon) => SizedBox(
      width: ShortVideoMetrics.touchWidth,
      height: metrics.controlHeight,
      child: Icon(icon, color: Colors.white, size: metrics.icon),
    );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: ShortVideoMetrics.gutter,
              right: ShortVideoMetrics.gutter,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: metrics.playbackHeight,
                    child: Column(
                      children: [
                        Expanded(
                          child: showDetails
                              ? const SizedBox()
                              : Row(
                                  children: [
                                    icon(Icons.pause_rounded),
                                    Text(
                                      '00:00',
                                      style: ShortVideoMetrics.time,
                                    ),
                                  ],
                                ),
                        ),
                        SizedBox(
                          height: ShortVideoMetrics.seekTarget,
                          child: Center(
                            child: Container(
                              height: ShortVideoMetrics.track,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: metrics.controlHeight,
                    child: LayoutBuilder(
                      builder: (context, bounds) => Row(
                        children: [
                          Container(
                            width: math.min(
                              ShortVideoMetrics.inputMaxWidth,
                              math.max(
                                0,
                                bounds.maxWidth -
                                    4 * ShortVideoMetrics.touchWidth -
                                    ShortVideoMetrics.gap,
                              ),
                            ),
                            height: metrics.controlHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF242527),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              '发弹幕',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: ShortVideoMetrics.control.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const SizedBox(width: ShortVideoMetrics.gap),
                          icon(CustomIcons.dm_on),
                          icon(CustomIcons.dm_settings),
                          const Spacer(),
                          icon(Icons.close_fullscreen_rounded),
                          icon(Icons.open_in_full_rounded),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
