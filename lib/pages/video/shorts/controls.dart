import 'package:material_ui/material_ui.dart';

/// A full-width seek bar is placed above this footer by the player. Keeping
/// the time on its own line leaves all touch targets available on narrow folds.
class ShortVideoControls extends StatelessWidget {
  const ShortVideoControls({
    super.key,
    required this.position,
    required this.duration,
    required this.danmaku,
    required this.onSend,
    required this.onDanmaku,
    required this.onDetails,
    required this.onFullscreen,
  });
  final String position, duration;
  final bool danmaku;
  final VoidCallback onSend, onDanmaku, onDetails, onFullscreen;
  static double heightFor(TextScaler scaler) => 64 + scaler.scale(12) + 8;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$position / $duration',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      Row(
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
              Icons.featured_play_list_outlined,
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
    ],
  );
}
