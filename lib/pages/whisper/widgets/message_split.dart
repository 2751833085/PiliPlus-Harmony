import 'package:material_ui/material_ui.dart';

/// Both slots keep their position in the tree when folding. The hidden list
/// keeps a valid width so offstage layout never squeezes its rows to zero.
class MessageSplit extends StatelessWidget {
  const MessageSplit({
    super.key,
    required this.split,
    required this.hasSelection,
    required this.list,
    required this.detail,
  });
  final bool split, hasSelection;
  final Widget list, detail;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final listWidth = split ? 352.0 : bounds.maxWidth;
      final hidden = !split && hasSelection;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: hidden ? 0 : listWidth,
            child: OverflowBox(
              minWidth: listWidth,
              maxWidth: listWidth,
              alignment: Alignment.topLeft,
              child: Offstage(offstage: hidden, child: list),
            ),
          ),
          SizedBox(
            width: split ? 1 : 0,
            child: VerticalDivider(
              width: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: .12),
            ),
          ),
          Expanded(child: detail),
        ],
      );
    },
  );
}
