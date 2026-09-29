import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Fixed tool surfaces reuse the same light, cached finish as the home page.
Widget messageActionSurface(BuildContext context, Widget child) =>
    HarmonyStyle.enabled(context)
    ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ImmersiveInteraction(
          borderRadius: BorderRadius.circular(24),
          child: child,
        ),
      )
    : child;
