import 'dart:math' show min;

import 'package:PiliPlus/common/widgets/dialog/bottom_panel.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:material_ui/material_ui.dart';

void showSearchFilterPanel(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final harmony = HarmonyStyle.enabled(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: min(640, MediaQuery.sizeOf(context).shortestSide),
    ),
    backgroundColor: harmony ? Colors.transparent : null,
    elevation: harmony ? 0 : null,
    showDragHandle: harmony ? false : null,
    builder: harmony
        ? (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .78,
            ),
            child: BottomPanel(
              title: '筛选',
              fitContent: true,
              child: Builder(builder: builder),
            ),
          )
        : builder,
  );
}

EdgeInsets searchFilterPadding(BuildContext context) =>
    HarmonyStyle.enabled(context)
    ? const EdgeInsets.fromLTRB(16, 8, 16, 20)
    : EdgeInsets.fromLTRB(
        16,
        20,
        16,
        100 + MediaQuery.viewPaddingOf(context).bottom,
      );
