import 'package:flutter/widgets.dart';

/// A split view already exposes the conversation list, so back leaves messages.
class MessageBackScope extends StatelessWidget {
  const MessageBackScope({
    super.key,
    required this.split,
    required this.hasSelection,
    required this.onCloseSelection,
    required this.child,
  });
  final bool split, hasSelection;
  final VoidCallback onCloseSelection;
  final Widget child;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: split || !hasSelection,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !split && hasSelection) onCloseSelection();
    },
    child: child,
  );
}
