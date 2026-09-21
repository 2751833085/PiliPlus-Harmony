import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:flutter/material.dart';

/// Keep the saved value visible while preventing every nested action, including
/// switches and popup menus. A tap explains why this setting is unavailable.
class SettingAccess extends StatelessWidget {
  const SettingAccess({
    super.key,
    required this.title,
    required this.reason,
    required this.child,
  });
  final String title;
  final ValueGetter<String?> reason;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: HarmonyAppearance.revision,
    builder: (context, _, _) {
      final message = reason();
      if (message == null) return child;
      void explain() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return Semantics(
        enabled: false,
        label: '$title。$message',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: explain,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Opacity(opacity: 0.42, child: AbsorbPointer(child: child)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '此选项暂不可用 · 点按查看原因',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
