import 'package:material_ui/material_ui.dart';

/// Touch light only: row geometry, fill, semantics and gesture handlers stay put.
/// Disabled/accessible modes avoid allocating another feedback controller.
class ImmersiveRowInteraction extends StatelessWidget {
  const ImmersiveRowInteraction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).extension<PopupSurfaceStyle>() == null ||
        MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return ImmersiveInteraction(
      allowMovement: false,
      borderRadius: BorderRadius.zero,
      child: child,
    );
  }
}
