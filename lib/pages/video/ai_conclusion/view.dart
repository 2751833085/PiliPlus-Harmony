import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';
import 'package:PiliPlus/pages/common/slide/common_slide_page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AiConclusionPanel extends CommonSlidePage {
  final AiConclusionResult item;

  const AiConclusionPanel({
    super.key,
    required this.item,
  });

  @override
  State<AiConclusionPanel> createState() => _AiDetailState();

  static Widget buildContent(
    BuildContext context,
    ThemeData theme,
    AiConclusionResult res, {
    Key? key,
    bool tap = true,
  }) {
    final spans = <InlineSpan>[];
    if (res.summary?.isNotEmpty == true) {
      spans.add(
        TextSpan(text: res.summary, style: const TextStyle(fontSize: 15)),
      );
    }
    for (final outline in res.outline ?? []) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n\n'));
      spans.add(
        TextSpan(
          text: outline.title ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      for (final part in outline.partOutline ?? []) {
        spans.add(const TextSpan(text: '\n'));
        spans.add(
          TextSpan(
            text: DurationUtils.formatDuration(part.timestamp),
            style: tap ? TextStyle(color: theme.colorScheme.primary) : null,
            recognizer: tap
                ? (NoDeadlineTapGestureRecognizer()
                    ..onTap = () {
                      try {
                        Get.find<VideoDetailController>(
                          tag: Get.arguments['heroTag'],
                        ).plPlayerController.seekTo(
                          Duration(seconds: part.timestamp!),
                          isSeek: false,
                        );
                      } catch (_) {}
                    })
                : null,
          ),
        );
        spans.add(TextSpan(text: ' ${part.content ?? ''}'));
      }
    }
    // SelectionArea sends an unconditional selectionClick on long press.
    // EditableText's selection path respects OHOS's silent long-press policy.
    // Keep one selectable span so copying across sections continues to work.
    return CustomScrollView(
      key: key,
      shrinkWrap: !tap,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            14,
            0,
            14,
            tap ? MediaQuery.viewPaddingOf(context).bottom + 100 : 0,
          ),
          sliver: SliverToBoxAdapter(
            child: SelectionText.rich(
              TextSpan(children: spans),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiDetailState extends State<AiConclusionPanel>
    with SingleTickerProviderStateMixin, CommonSlideMixin {
  @override
  Widget buildPage(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: SizedBox(
              height: 35,
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: enableSlide ? slideList(theme) : buildList(theme),
          ),
        ],
      ),
    );
  }

  late Key _key;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = PrimaryScrollController.of(context);
    _key = ValueKey(controller.hashCode);
  }

  @override
  Widget buildList(ThemeData theme) {
    return AiConclusionPanel.buildContent(
      context,
      theme,
      widget.item,
      key: _key,
    );
  }
}
