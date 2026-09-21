import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_loading.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/loading_widget/m3e_loading_indicator.dart';
import 'package:material_ui/material_ui.dart';

const Widget m3eLoading = Center(child: M3ELoadingIndicator());

const Widget linearLoading = SliverToBoxAdapter(
  child: _PageLoading(),
);

const Widget scrollableError = CustomScrollView(slivers: [HttpError()]);

Widget scrollErrorWidget({
  String? errMsg,
  VoidCallback? onReload,
  ScrollController? controller,
}) => CustomScrollView(
  controller: controller,
  slivers: [
    HttpError(
      errMsg: errMsg,
      onReload: onReload,
    ),
  ],
);

class _PageLoading extends StatelessWidget {
  const _PageLoading();
  @override
  Widget build(BuildContext context) => HarmonyStyle.enabled(context)
      ? const Center(child: HarmonyLoadingIndicator())
      : const LinearProgressIndicator();
}
