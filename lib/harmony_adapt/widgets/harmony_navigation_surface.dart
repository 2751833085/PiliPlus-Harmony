import 'package:material_ui/material_ui.dart';

/// Solid fallback for older SDKs and the first frame before native shell setup.
/// Native Harmony bars own the backdrop; Flutter never duplicates that blur.
class HarmonyNavigationSurface extends StatelessWidget {
  const HarmonyNavigationSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF25262A)
        : const Color(0xFFF7F8FA),
    child: RepaintBoundary(
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}
