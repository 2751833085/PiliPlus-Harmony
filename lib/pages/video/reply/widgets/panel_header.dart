import 'package:PiliPlus/pages/video/shorts/metrics.dart';
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
              fontSize: onClose == null ? 13 : 16,
              height: onClose == null ? null : 1.25,
              letterSpacing: onClose == null ? null : 0,
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
              fontSize: onClose == null ? 13 : 12,
              height: onClose == null ? null : 1.25,
              color: ColorScheme.of(context).secondary,
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            // Keep the modal close target at its existing accessible size.
            style: IconButton.styleFrom(fixedSize: const Size.square(48)),
            tooltip: '关闭评论',
            onPressed: onClose,
            icon: Icon(Icons.close, size: ShortVideoMetrics.of(context).icon),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: ShortVideoPillButton(
        onPressed: onReply,
        label: '发一条友善的评论',
        foreground: Theme.of(context).colorScheme.onSurfaceVariant,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        trailing: Icon(
          Icons.sentiment_satisfied_alt,
          size: ShortVideoMetrics.of(context).icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
