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
              color: ColorScheme.of(context).onSurface,
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
            color: onClose == null
                ? ColorScheme.of(context).secondary
                : ColorScheme.of(context).onSurfaceVariant,
          ),
          label: Text(
            sortLabel,
            style: TextStyle(
              fontSize: onClose == null ? 13 : 12,
              height: onClose == null ? null : 1.25,
              color: onClose == null
                  ? ColorScheme.of(context).secondary
                  : ColorScheme.of(context).onSurfaceVariant,
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
  const ShortReplyComposer({super.key, required this.onReply, this.onEmoji});
  final VoidCallback onReply;
  final VoidCallback? onEmoji;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ImmersiveSurface(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF242528)
            : const Color(0xFFF1F2F3),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onReply,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Text(
                    '尊重是评论打动人心的入场券',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '发表情',
              onPressed: onEmoji ?? onReply,
              icon: const Icon(Icons.sentiment_satisfied_alt, size: 24),
            ),
          ],
        ),
      ),
    ),
  );
}
