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
    builder: (_, height, _) => AbsorbPointer(
      // Native ArkUI and Flutter can both receive the same physical touch.
      // Reserve AND absorb the full bar area so a tab tap cannot open a card
      // painted underneath Scaffold.extendBody, including during tab changes.
      child: SizedBox(
        width: double.infinity,
        height: height > 0 ? height / scale : fallback,
      ),
    ),
  );
}
