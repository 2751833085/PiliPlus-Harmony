import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Reserve native navigation space without changing it when another route or
/// popup covers the home screen. Like Scaffold's normal bar, it lets extendBody
/// paint underneath while giving lists the correct bottom padding.
class NativeNavigationSpacer extends StatelessWidget {
  const NativeNavigationSpacer({
    super.key,
    required this.extent,
    required this.scale,
    required this.fallback,
  });
  final ValueListenable<double> extent;
  final double scale;
  final double fallback;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: extent,
    builder: (_, height, _) => SizedBox(
      height: height > 0 ? height / scale : fallback,
    ),
  );
}
