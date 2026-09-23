import 'dart:math' as math;
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

typedef PopupMenuItemSelected<T> =
    void Function(
      T value,
      VoidCallback setState,
    );

List<PopupMenuEntry<T>> enumItemBuilder<T extends EnumWithLabel>(
  Iterable<T> items,
) => items.map((e) => PopupMenuItem(value: e, child: Text(e.label))).toList();

enum DescPosType { subtitle, title, trailing }

class PopupListTile<T> extends StatefulWidget {
  const PopupListTile({
    super.key,
    this.dense,
    this.safeArea = true,
    this.enabled = true,
    this.leading,
    required this.title,
    this.descPosType = .subtitle,
    required this.value,
    required this.itemBuilder,
    required this.onSelected,
    this.titleStyle,
    this.descStyle,
  });

  final bool? dense;
  final bool safeArea;
  final bool enabled;
  final Widget? leading;
  final Widget title;

  final DescPosType descPosType;
  final ValueGetter<(T, String)> value;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final TextStyle? titleStyle;
  final TextStyle? descStyle;

  @override
  State<PopupListTile<T>> createState() => _PopupListTileState<T>();
}

class _PopupListTileState<T> extends State<PopupListTile<T>> {
  final _key = PlatformUtils.isDesktop ? null : GlobalKey();

  void _showButtonMenu(TapUpDetails details, T value) {
    final thisOffset = details.globalPosition - details.localPosition;
    final double dx;
    if (PlatformUtils.isDesktop) {
      dx = details.globalPosition.dx + 1;
    } else {
      final thisBox = context.findRenderObject();
      final titleBox = _key!.currentContext!.findRenderObject() as RenderBox;
      final titleOffset = titleBox.localToGlobal(.zero, ancestor: thisBox);
      dx = thisOffset.dx + titleOffset.dx;
    }
    final selection = HarmonyStyle.enabled(context)
        ? showAnchoredMenu<T>(
            context: context,
            positionBuilder: (context, constraints) {
              final overlay =
                  Navigator.of(context).overlay!.context.findRenderObject()
                      as RenderBox;
              final row = this.context.findRenderObject() as RenderBox;
              final topLeft = row.localToGlobal(Offset.zero, ancestor: overlay);
              final anchor = Rect.fromLTWH(
                topLeft.dx + 16,
                topLeft.dy,
                math.max(0, row.size.width - 32),
                row.size.height,
              );
              return RelativeRect.fromRect(anchor, Offset.zero & overlay.size);
            },
            constraints: BoxConstraints(
              minWidth: math.min(200, MediaQuery.sizeOf(context).width - 32),
              maxWidth: math.min(360, MediaQuery.sizeOf(context).width - 32),
              maxHeight: MediaQuery.sizeOf(context).height * .65,
            ),
            items: widget.itemBuilder(context),
            initialValue: value,
          )
        : showMenu<T>(
            context: context,
            position: RelativeRect.fromLTRB(dx, thisOffset.dy + 5, dx, 0),
            items: widget.itemBuilder(context),
            initialValue: value,
            requestFocus: false,
          );
    selection.then<void>((newValue) {
      if (!mounted) return;
      if (newValue == null || newValue == value) return;
      widget.onSelected(newValue, _refresh);
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (value, descStr) = widget.value();
    Widget title = KeyedSubtree(key: _key, child: widget.title);
    Widget? subtitle;
    Widget? trailing;
    final desc = Text(
      descStr,
      style:
          (widget.descStyle ??
                  (HarmonyStyle.enabled(context)
                      ? theme.textTheme.bodyMedium!
                      : theme.textTheme.labelMedium!))
              .copyWith(
                color: widget.enabled
                    ? theme.colorScheme.secondary
                    : theme.disabledColor,
              ),
    );
    switch (widget.descPosType) {
      case DescPosType.subtitle:
        subtitle = desc;
      case DescPosType.title:
        title = Row(
          spacing: 12,
          mainAxisSize: .min,
          children: [title, desc],
        );
      case DescPosType.trailing:
        trailing = desc;
    }
    return ListTile(
      dense: widget.dense,
      safeArea: widget.safeArea,
      enabled: widget.enabled,
      onTapUp: (details) => _showButtonMenu(details, value),
      leading: widget.leading,
      title: title,
      titleTextStyle: widget.titleStyle ?? theme.textTheme.titleMedium,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
