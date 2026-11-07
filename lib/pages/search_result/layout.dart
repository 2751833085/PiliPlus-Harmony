import 'dart:math' show min;

import 'package:material_ui/material_ui.dart';

/// Uses the available logical window width, including when the device is folded.
class SearchResultLayout extends StatelessWidget {
  const SearchResultLayout({
    super.key,
    required this.results,
    this.sidebar,
  });

  final Widget results;
  final WidgetBuilder? sidebar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final showSidebar =
          sidebar != null && bounds.maxWidth >= 620 && bounds.maxHeight >= 480;
      final width = min(bounds.maxWidth, 960.0);
      final top = MediaQuery.paddingOf(context).top;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: results),
              if (showSidebar) ...[
                Padding(
                  padding: EdgeInsets.only(top: top),
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor.withValues(alpha: .1),
                  ),
                ),
                SizedBox(
                  width: min(width / 3, 240.0),
                  child: Padding(
                    padding: EdgeInsets.only(top: top),
                    child: Builder(builder: sidebar!),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
