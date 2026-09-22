import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

/// The short-video sheet shares its title row with sorting and closing, rather
/// than stacking a drag handle, modal title, and the reply panel's own header.
class ReplyPanelHeader extends StatelessWidget {
  const ReplyPanelHeader({
    super.key,
    required this.title,
    required this.sortLabel,
    required this.onSort,
    this.onClose,
  });
  final String title, sortLabel;
  final VoidCallback onSort;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      onClose == null ? 2.5 : 0,
      6,
      onClose == null ? 2.5 : 0,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: onClose == null ? 13 : 17,
              fontWeight: onClose == null ? null : FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          style: Style.buttonStyle,
          onPressed: onSort,
          icon: Icon(
            Icons.sort,
            size: 16,
            color: ColorScheme.of(context).secondary,
          ),
          label: Text(
            sortLabel,
            style: TextStyle(
              fontSize: 13,
              color: ColorScheme.of(context).secondary,
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            style: IconButton.styleFrom(fixedSize: const Size.square(48)),
            tooltip: '关闭评论',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 22),
          ),
      ],
    ),
  );
}

class ShortReplyComposer extends StatelessWidget {
  const ShortReplyComposer({super.key, required this.onReply});
  final VoidCallback onReply;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: TextButton(
        onPressed: onReply,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          minimumSize: const Size(double.infinity, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '发一条友善的评论',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.sentiment_satisfied_alt,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}
