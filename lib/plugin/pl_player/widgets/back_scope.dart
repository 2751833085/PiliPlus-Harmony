import 'package:flutter/material.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart' as app;

/// A blocked pop is broadcast to every scope on the route. The player must
/// respond only to its own veto, never to an open comment panel's veto.
/// Stateful also preserves the player's GlobalKey mounted check during folds.
class PlayerBackScope extends StatefulWidget {
  const PlayerBackScope({
    super.key,
    required this.canPop,
    required this.suspended,
    required this.onPopInvokedWithResult,
    required this.child,
  });
  final bool canPop, suspended;
  final PopInvokedWithResultCallback<Object> onPopInvokedWithResult;
  final Widget child;
  @override
  State<PlayerBackScope> createState() => _PlayerBackScopeState();
}

class _PlayerBackScopeState extends State<PlayerBackScope> {
  @override
  Widget build(BuildContext context) {
    // Capture this frame, because a sibling scope may synchronously change
    // the comment flag while the route is still broadcasting one back event.
    final config = widget;
    return app.popScope(
      canPop: config.suspended || config.canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || (!config.suspended && !config.canPop)) {
          config.onPopInvokedWithResult(didPop, result);
        }
      },
      child: config.child,
    );
  }
}
