import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:material_ui/material_ui.dart';

/// Harmony accents deliberately omit Material palette algorithms and swatches.
class HarmonyAccentChoices extends StatelessWidget {
  const HarmonyAccentChoices({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ImmersiveSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('强调色', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final i in themeColorDisplayOrder)
                    Semantics(
                      button: true,
                      selected: selected == i,
                      label: colorThemeTypes[i].label,
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 64,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colorThemeTypes[i].color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: .12),
                                    ),
                                  ),
                                  child: selected == i
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 24,
                                          color:
                                              ThemeData.estimateBrightnessForColor(
                                                    colorThemeTypes[i].color,
                                                  ) ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  colorThemeTypes[i].label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
