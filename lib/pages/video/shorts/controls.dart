import 'dart:math' as math;
import 'package:PiliPlus/pages/video/shorts/metrics.dart';
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
  static double heightFor(TextScaler scaler) =>
      ShortVideoMetrics(scaler).footerHeight;

  Widget _button(
    ShortVideoMetrics metrics,
    String tooltip,
    IconData icon,
    VoidCallback onPressed,
  ) => IconButton(
    style: metrics.iconButtonStyle,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: metrics.icon, color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final metrics = ShortVideoMetrics.of(context);
    return SizedBox(
      height: metrics.controlHeight,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final inputWidth = math.min(
            ShortVideoMetrics.inputMaxWidth,
            math.max(
              0.0,
              bounds.maxWidth -
                  4 * ShortVideoMetrics.touchWidth -
                  ShortVideoMetrics.gap,
            ),
          );
          return Row(
            children: [
              SizedBox(
                key: const ValueKey('short-danmaku-input'),
                width: inputWidth,
                child: ShortVideoPillButton(label: '发弹幕', onPressed: onSend),
              ),
              const SizedBox(width: ShortVideoMetrics.gap),
              _button(
                metrics,
                danmaku ? '关闭弹幕' : '开启弹幕',
                danmaku ? CustomIcons.dm_on : CustomIcons.dm_off,
                onDanmaku,
              ),
              _button(
                metrics,
                '弹幕设置',
                CustomIcons.dm_settings,
                onDanmakuSettings,
              ),
              const Spacer(),
              _button(metrics, '普通详情', Icons.fullscreen_exit, onDetails),
              _button(metrics, '全屏', Icons.fullscreen, onFullscreen),
            ],
          );
        },
      ),
    );
  }
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
        constraints: BoxConstraints(
          minHeight: ShortVideoMetrics.of(context).controlHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShortVideoMetrics.control.copyWith(
                    color: Colors.white,
                  ),
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
