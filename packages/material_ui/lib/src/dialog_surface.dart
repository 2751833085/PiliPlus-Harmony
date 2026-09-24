import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide showDialog;
import 'package:material_ui/src/immersive_surface.dart';
import 'package:material_ui/src/popup_surface.dart' show PopupSurfaceStyle;

/// Keep the SDK's focus, barrier, keyboard and result behavior. Only the
/// already constrained dialog surface changes; fullscreen editors stay intact.
Future<T?> showDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) => m.showDialog<T>(
  context: context,
  builder: (context) => _DialogSurface(child: builder(context)),
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor,
  barrierLabel: barrierLabel,
  useSafeArea: useSafeArea,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
  anchorPoint: anchorPoint,
  traversalEdgeBehavior: traversalEdgeBehavior,
  fullscreenDialog: fullscreenDialog,
  requestFocus: requestFocus,
  animationStyle: animationStyle,
);

class _DialogSurface extends StatelessWidget {
  const _DialogSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).extension<PopupSurfaceStyle>() == null) return child;
    final Widget built = switch (child) {
      AlertDialog dialog => dialog.build(context),
      SimpleDialog dialog => dialog.build(context),
      _ => child,
    };
    if (built is! Dialog ||
        built.child == null ||
        (built.insetPadding == EdgeInsets.zero && built.elevation == 0))
      return child;
    final shape = built.shape ?? DialogTheme.of(context).shape;
    if (shape is! RoundedRectangleBorder) return child;
    final radius = shape.borderRadius.resolve(Directionality.of(context));
    return Dialog(
      key: built.key,
      backgroundColor: Colors.transparent,
      elevation: built.elevation,
      shadowColor: built.shadowColor,
      surfaceTintColor: Colors.transparent,
      insetAnimationDuration: built.insetAnimationDuration,
      insetAnimationCurve: built.insetAnimationCurve,
      insetPadding: built.insetPadding,
      clipBehavior: Clip.antiAlias,
      shape: shape,
      alignment: built.alignment,
      constraints: built.constraints,
      semanticsRole: built.semanticsRole,
      child: ImmersiveSurface(borderRadius: radius, child: built.child!),
    );
  }
}
