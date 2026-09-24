import 'package:material_ui/material_ui.dart';

class HarmonyQuickAction {
  const HarmonyQuickAction(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class HarmonyQuickActions extends StatelessWidget {
  const HarmonyQuickActions({super.key, required this.actions});
  final List<HarmonyQuickAction> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final columns = bounds.maxWidth >= 304 * scale ? 4 : 2;
      return Wrap(
        children: [
          for (final action in actions)
            SizedBox(
              width: bounds.maxWidth / columns,
              child: ImmersiveInteraction(
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: action.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action.icon,
                          size: 25,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          action.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
