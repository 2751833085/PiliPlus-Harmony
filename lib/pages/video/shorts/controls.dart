import 'dart:math' as math;
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:material_ui/material_ui.dart';

/// Keep the footer's geometry fixed when the information layer fades.
class ShortVideoControls extends StatelessWidget {
  const ShortVideoControls({
    super.key,
    required this.danmaku,
    required this.onSend,
    required this.onDanmaku,
    required this.onDanmakuSettings,
    required this.onDetails,
    required this.onFullscreen,
  });
  final bool danmaku;
  final VoidCallback onSend,
      onDanmaku,
      onDanmakuSettings,
      onDetails,
      onFullscreen;
  static double heightFor(TextScaler scaler) => 72;

  Widget _button(String tooltip, IconData icon, VoidCallback onPressed) =>
      SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 24, color: Colors.white),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final inputWidth = math.min(
          220.0,
          math.max(0.0, bounds.maxWidth - 184),
        );
        return Row(
          children: [
            SizedBox(
              key: const ValueKey('short-danmaku-input'),
              width: inputWidth,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white70,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: onSend,
                child: inputWidth < 88
                    ? const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        semanticLabel: '发弹幕',
                      )
                    : const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '发弹幕',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _button(
              danmaku ? '关闭弹幕' : '开启弹幕',
              danmaku ? CustomIcons.dm_on : CustomIcons.dm_off,
              onDanmaku,
            ),
            _button('弹幕设置', CustomIcons.dm_settings, onDanmakuSettings),
            const Spacer(),
            _button('普通详情', Icons.fullscreen_exit, onDetails),
            _button('全屏', Icons.fullscreen, onFullscreen),
          ],
        );
      },
    ),
  );
}

/// Contextual search and collection rows share spacing and touch targets.
class ShortVideoContextLink extends StatelessWidget {
  const ShortVideoContextLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .10),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
            ],
          ),
        ),
      ),
    ),
  );
}
