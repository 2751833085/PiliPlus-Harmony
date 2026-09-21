import 'package:flutter/material.dart';

/// Renders the stroke independently of media_kit's platform-specific config API.
class OutlinedSubtitles extends StatelessWidget {
  const OutlinedSubtitles({
    super.key,
    required this.subtitles,
    required this.initialSubtitles,
    required this.style,
    required this.strokeWidth,
    this.visible = true,
    this.textAlign = TextAlign.center,
    this.textScaler = TextScaler.noScaling,
  });

  final Stream<List<String>> subtitles;
  final List<String> initialSubtitles;
  final TextStyle style;
  final double strokeWidth;
  final bool visible;
  final TextAlign textAlign;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<String>>(
    stream: subtitles,
    initialData: initialSubtitles,
    builder: (context, snapshot) {
      final text = (snapshot.data ?? const <String>[])
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      if (!visible || text.isEmpty) return const SizedBox.shrink();
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (strokeWidth > 0)
              ExcludeSemantics(
                child: Text(
                  text,
                  textAlign: textAlign,
                  textScaler: textScaler,
                  style: style.copyWith(
                    background: Paint()..color = Colors.transparent,
                    foreground: Paint()
                      ..color = Colors.black
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = strokeWidth,
                  ),
                ),
              ),
            Text(
              text,
              style: style,
              textAlign: textAlign,
              textScaler: textScaler,
            ),
          ],
        ),
      );
    },
  );
}
