import 'package:flutter/widgets.dart';

/// Keeps the page subtree mounted when a fold/resize inserts or removes a rail.
class AdaptiveNavigationBody extends StatelessWidget {
  const AdaptiveNavigationBody({
    super.key,
    required this.child,
    this.navigation,
    this.divider,
  });

  final Widget child;
  final Widget? navigation;
  final Widget? divider;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ?navigation,
      if (navigation != null && divider != null) divider!,
      Expanded(key: const ValueKey('main-page-content'), child: child),
    ],
  );
}
