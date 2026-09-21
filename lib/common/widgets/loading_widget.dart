import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/common/widgets/custom_arc.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.msg = 'loading...',
    required this.progress,
  });

  ///loading msg
  final String msg;
  final RxDouble progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: theme.dialogTheme.backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      ),
      child: Column(
        spacing: 20,
        mainAxisSize: MainAxisSize.min,
        children: [
          //loading animation
          Obx(
            () => HarmonyStyle.enabled(context)
                ? HarmonyLoadingIndicator(
                    color: onSurfaceVariant,
                    value: progress.value,
                  )
                : Arc(
                    size: 40,
                    color: onSurfaceVariant,
                    strokeWidth: 3,
                    progress: progress.value,
                  ),
          ),
          //msg
          Text(msg, style: TextStyle(color: onSurfaceVariant)),
        ],
      ),
    );
  }
}
