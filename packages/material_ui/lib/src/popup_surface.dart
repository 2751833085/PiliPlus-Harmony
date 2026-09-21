import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide PopupMenuButton, showMenu;

/// Opt-in surface styling only; the SDK still owns positioning, focus, keyboard
/// navigation, dismissal and menu item callbacks.
@immutable
class PopupSurfaceStyle extends ThemeExtension<PopupSurfaceStyle> {
  const PopupSurfaceStyle();
  @override
  PopupSurfaceStyle copyWith() => this;
  @override
  PopupSurfaceStyle lerp(covariant PopupSurfaceStyle? other, double t) => this;
}

List<PopupMenuEntry<T>> _surfaceItems<T>(
  BuildContext context,
  List<PopupMenuEntry<T>> items,
) {
  if (Theme.of(context).extension<PopupSurfaceStyle>() == null) return items;
  return [for (final entry in items) _SurfaceEntry<T>(entry)];
}

class _SurfaceEntry<T> extends PopupMenuEntry<T> {
  const _SurfaceEntry(this.entry);
  final PopupMenuEntry<T> entry;
  @override
  double get height => entry.height;
  @override
  bool represents(T? value) => entry.represents(value);
  @override
  State<_SurfaceEntry<T>> createState() => _SurfaceEntryState<T>();
}

class _SurfaceEntryState<T> extends State<_SurfaceEntry<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    if (MediaQuery.highContrastOf(context))
      return ColoredBox(color: theme.colorScheme.surface, child: widget.entry);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withValues(alpha: dark ? .88 : .9),
                theme.colorScheme.surface.withValues(alpha: dark ? .76 : .8),
              ],
            ),
          ),
          child: widget.entry,
        ),
      ),
    );
  }
}

class PopupMenuButton<T> extends m.PopupMenuButton<T> {
  PopupMenuButton({
    super.key,
    required PopupMenuItemBuilder<T> itemBuilder,
    super.initialValue,
    super.onOpened,
    super.onSelected,
    super.onCanceled,
    super.tooltip,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.padding,
    super.menuPadding,
    super.child,
    super.borderRadius,
    super.splashRadius,
    super.icon,
    super.iconSize,
    super.offset,
    super.enabled,
    super.shape,
    super.color,
    super.iconColor,
    super.enableFeedback,
    super.constraints,
    super.position,
    super.clipBehavior = Clip.antiAlias,
    super.useRootNavigator,
    super.popUpAnimationStyle,
    super.routeSettings,
    super.style,
    super.requestFocus,
  }) : super(
         itemBuilder: (context) => _surfaceItems(context, itemBuilder(context)),
       );
}

Future<T?> showMenu<T>({
  required BuildContext context,
  RelativeRect? position,
  PopupMenuPositionBuilder? positionBuilder,
  required List<PopupMenuEntry<T>> items,
  T? initialValue,
  double? elevation,
  Color? shadowColor,
  Color? surfaceTintColor,
  String? semanticLabel,
  ShapeBorder? shape,
  EdgeInsetsGeometry? menuPadding,
  Color? color,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  Clip clipBehavior = Clip.antiAlias,
  RouteSettings? routeSettings,
  AnimationStyle? popUpAnimationStyle,
  bool? requestFocus,
}) => m.showMenu<T>(
  context: context,
  position: position,
  positionBuilder: positionBuilder,
  items: _surfaceItems(context, items),
  initialValue: initialValue,
  elevation: elevation,
  shadowColor: shadowColor,
  surfaceTintColor: surfaceTintColor,
  semanticLabel: semanticLabel,
  shape: shape,
  menuPadding: menuPadding,
  color: color,
  useRootNavigator: useRootNavigator,
  constraints: constraints,
  clipBehavior: clipBehavior,
  routeSettings: routeSettings,
  popUpAnimationStyle: popUpAnimationStyle,
  requestFocus: requestFocus,
);
