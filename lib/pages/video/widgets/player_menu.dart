import 'package:material_ui/material_ui.dart';

class PlayerMenuAction {
  const PlayerMenuAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Identical layout for pre-play, ordinary playback and the short-video feed.
/// Unlike toolbar widgets these tiles own their complete, readable hit target.
class PlayerMenu extends StatelessWidget {
  const PlayerMenu({
    super.key,
    required this.actions,
    this.children = const [],
    this.shrinkWrap = false,
  });
  final List<PlayerMenuAction> actions;
  final List<Widget> children;
  final bool shrinkWrap;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: shrinkWrap,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
    children: [
      LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final capacity = (bounds.maxWidth / (76 * scale)).floor().clamp(2, 5);
          final rows = (actions.length / capacity).ceil().clamp(
            1,
            actions.length.clamp(1, 100),
          );
          final columns = (actions.length / rows).ceil().clamp(1, capacity);
          return Wrap(
            children: [
              for (final action in actions)
                SizedBox(
                  width: bounds.maxWidth / columns,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: action.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(action.icon, size: 23),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            action.label,
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
            ],
          );
        },
      ),
      if (children.isNotEmpty) ...[
        const Divider(height: 20, thickness: .5),
        ...children,
      ],
    ],
  );
}

class PlayerMenuRow extends StatelessWidget {
  const PlayerMenuRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.value,
  });
  final String title;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    leading: Icon(icon, size: 22),
    title: Text(title),
    subtitle: value == null
        ? null
        : Text(value!, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
