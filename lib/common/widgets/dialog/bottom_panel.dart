import 'dart:ui' show SemanticsRole;
import 'package:material_ui/material_ui.dart';

/// A single, edge-attached sheet. Scrolling stays in [child], so long lists,
/// large text and the keyboard cannot push its header off the screen.
class BottomPanel extends StatelessWidget {
  const BottomPanel({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.surface = true,
    this.fitContent = false,
  });
  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final bool surface;
  final bool fitContent;
  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: fitContent ? MainAxisSize.min : MainAxisSize.max,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22),
                ),
              ],
            ),
          ),
          Flexible(
            fit: fitContent ? FlexFit.loose : FlexFit.tight,
            child: child,
          ),
        ],
      ),
    );
    return surface
        ? ImmersiveSurface(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: content,
          )
        : content;
  }
}

/// Keeps PopupMenuItem's native onTap, enabled and pop-result semantics.
Future<T?> showSelectionSheet<T>({
  required BuildContext context,
  required Widget title,
  required List<PopupMenuEntry<T>> items,
  T? selected,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .75,
    ),
    child: ImmersiveSurface(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.titleMedium!,
                        child: title,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
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
