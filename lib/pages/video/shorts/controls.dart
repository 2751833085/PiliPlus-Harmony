import 'package:PiliPlus/pages/video/shorts/chrome.dart';
import 'package:material_ui/material_ui.dart';

/// Secondary actions fade with the information layer. Reserve the same space
/// in minimal mode so neither the progress row nor the video moves.
class ShortVideoControls extends StatelessWidget {
  const ShortVideoControls({
    super.key,
    required this.danmaku,
    required this.onSend,
    required this.onDanmaku,
    required this.onDetails,
    required this.onFullscreen,
  });
  final bool danmaku;
  final VoidCallback onSend, onDanmaku, onDetails, onFullscreen;
  static double heightFor(TextScaler scaler) =>
      48 + ShortVideoMinimalControls.heightFor(scaler);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white12,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onSend,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '发弹幕',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '弹幕开关',
          onPressed: onDanmaku,
          icon: Icon(
            danmaku ? Icons.subtitles : Icons.subtitles_off,
            color: Colors.white,
          ),
        ),
        IconButton(
          tooltip: '普通详情',
          onPressed: onDetails,
          icon: const Icon(
            Icons.fullscreen_exit,
            color: Colors.white,
          ),
        ),
        IconButton(
          tooltip: '全屏',
          onPressed: onFullscreen,
          icon: const Icon(Icons.fullscreen, color: Colors.white),
        ),
      ],
    ),
  );
}
