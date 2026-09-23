import 'dart:ui' show SemanticsRole;
import 'dart:ui' show ImageFilter;
import 'immersive_surface.dart';
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

/// Harmony menus use an edge-attached sheet even when translucency is off.
@immutable
class PopupSheetStyle extends ThemeExtension<PopupSheetStyle> {
  const PopupSheetStyle();
  @override
  PopupSheetStyle copyWith() => this;
  @override
  PopupSheetStyle lerp(covariant PopupSheetStyle? other, double t) => this;
}

Future<T?> _showMenuSheet<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
  T? selected,
  Color? color,
  String? title,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  bool? requestFocus,
}) => m.showModalBottomSheet<T>(
  context: context,
  useRootNavigator: useRootNavigator,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: false,
  backgroundColor: Colors.transparent,
  elevation: 0,
  constraints: const BoxConstraints(maxWidth: 640),
  routeSettings: routeSettings,
  requestFocus: requestFocus,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .78,
    ),
    child: ImmersiveSurface(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '选择',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              for (final item in items)
                ColoredBox(
                  color: selected != null && item.represents(selected)
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .08)
                      : Colors.transparent,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    role: SemanticsRole.menu,
                    child: item,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  ),
);

List<PopupMenuEntry<T>> _surfaceItems<T>(
  BuildContext context,
  List<PopupMenuEntry<T>> items, {
  bool anchored = false,
}) {
  if (Theme.of(context).extension<PopupSurfaceStyle>() == null ||
      (!anchored && Theme.of(context).extension<PopupSheetStyle>() != null))
    return items;
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
    if (MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context))
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
  @override
  m.PopupMenuButtonState<T> createState() => _SheetMenuButtonState<T>();
}

class _SheetMenuButtonState<T> extends m.PopupMenuButtonState<T> {
  bool _showingSheet = false;
  @override
  void showButtonMenu() {
    if (Theme.of(context).extension<PopupSheetStyle>() == null) {
      super.showButtonMenu();
      return;
    }
    if (_showingSheet || !widget.enabled) return;
    final items = widget.itemBuilder(context);
    if (items.isEmpty) return;
    _showingSheet = true;
    widget.onOpened?.call();
    _showMenuSheet<T>(
      context: context,
      items: items,
      selected: widget.initialValue,
      color: widget.color,
      title: widget.tooltip,
      useRootNavigator: widget.useRootNavigator,
      routeSettings: widget.routeSettings,
      requestFocus: widget.requestFocus,
    ).then((value) {
      _showingSheet = false;
      if (!mounted) return;
      if (value == null) {
        widget.onCanceled?.call();
      } else {
        widget.onSelected?.call(value);
      }
    });
  }
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
}) => Theme.of(context).extension<PopupSheetStyle>() != null
    ? _showMenuSheet<T>(
        context: context,
        items: items,
        selected: initialValue,
        color: color,
        title: semanticLabel,
        useRootNavigator: useRootNavigator,
        routeSettings: routeSettings,
        requestFocus: requestFocus,
      )
    : m.showMenu<T>(
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

/// A value selector stays attached to its invoking row even when action menus
/// use bottom sheets. SDK positioning, scrolling, focus and return semantics
/// remain intact; only the opt-in light surface is wrapped around each entry.
Future<T?> showAnchoredMenu<T>({
  required BuildContext context,
  required PopupMenuPositionBuilder positionBuilder,
  required List<PopupMenuEntry<T>> items,
  T? initialValue,
  BoxConstraints? constraints,
  String? semanticLabel,
}) {
  final theme = Theme.of(context);
  final surface = theme.extension<PopupSurfaceStyle>() != null;
  return m.showMenu<T>(
    context: context,
    positionBuilder: positionBuilder,
    items: _surfaceItems(context, items, anchored: true),
    initialValue: initialValue,
    semanticLabel: semanticLabel,
    constraints: constraints,
    menuPadding: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    color: surface ? Colors.transparent : theme.colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    requestFocus: true,
  );
}
