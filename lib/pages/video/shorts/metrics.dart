import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// One visual scale for feed chrome. Text keeps the user's scaler and font;
/// container heights follow it instead of inheriting app-wide button defaults.
class ShortVideoMetrics {
  const ShortVideoMetrics(this.scaler);
  final TextScaler scaler;
  factory ShortVideoMetrics.of(BuildContext context) =>
      ShortVideoMetrics(MediaQuery.textScalerOf(context));

  static const gutter = 16.0;
  static const gap = 8.0;
  static const touchWidth = 44.0;
  static const seekTarget = 28.0;
  static const inputMaxWidth = 200.0;
  static const actionWidth = 64.0;
  static const informationRight = actionWidth + 16;
  static const track = 2.0;
  static const activeTrack = 4.0;
  static const thumb = 3.0;
  static const activeThumb = 6.0;
  static const thumbGlow = 16.0;

  double get fieldHeight =>
      math.max(32, (scaler.scale(14) * 1.25 + 12).ceilToDouble());
  double get controlHeight => math.max(44, fieldHeight + 8);
  double get footerHeight => seekTarget + controlHeight;
  double get playbackHeight => controlHeight + seekTarget;
  double get captionHeight => (scaler.scale(12) * 1.25).ceilToDouble();
  double get icon =>
      24 + ((scaler.scale(14) / 14 - 1).clamp(0.0, 1.0) * 4).roundToDouble();
  double get actionIcon => icon + 4;
  double get avatar => icon + 12;
  double get pauseButton => 56 + (icon - 24) * 2;

  static const caption = TextStyle(
    color: Colors.white70,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const control = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const author = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const time = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.25,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
  );

  ButtonStyle get iconButtonStyle => IconButton.styleFrom(
    minimumSize: Size(touchWidth, controlHeight),
    maximumSize: Size(touchWidth, controlHeight),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// A compact painted capsule inside a full-size touch target.
class ShortVideoPillButton extends StatelessWidget {
  const ShortVideoPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Colors.white12,
    this.foreground = Colors.white70,
    this.centered = false,
    this.trailing,
  });
  final String label;
  final VoidCallback onPressed;
  final Color color, foreground;
  final bool centered;
  final Widget? trailing;

  Widget _label() => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: ShortVideoMetrics.control.copyWith(color: foreground),
  );

  @override
  Widget build(BuildContext context) {
    final metrics = ShortVideoMetrics.of(context);
    return Semantics(
      button: true,
      child: SizedBox(
        height: metrics.controlHeight,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(metrics.controlHeight / 2),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: metrics.fieldHeight,
                alignment: centered ? Alignment.center : Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(metrics.fieldHeight / 2),
                ),
                child: trailing == null
                    ? _label()
                    : Row(
                        children: [
                          Expanded(child: _label()),
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
