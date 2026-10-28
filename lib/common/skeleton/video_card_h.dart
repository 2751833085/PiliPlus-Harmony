import 'package:PiliPlus/common/widgets/video_card/video_card_h_layout.dart';
import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

class VideoCardHSkeleton extends StatelessWidget {
  const VideoCardHSkeleton({
    super.key,
    this.adaptiveCover = false,
    this.compactSidebar = false,
  });
  final bool adaptiveCover;
  final bool compactSidebar;

  @override
  Widget build(BuildContext context) {
    final color = ColorScheme.of(context).onInverseSurface;
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Style.safeSpace,
          vertical: 5,
        ),
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            crossAxisAlignment: .start,
            children: [
              SizedBox(
                width: adaptiveCover
                    ? VideoCardHLayout.coverWidth(
                        bounds.maxWidth,
                        bounds.maxHeight,
                        compactSidebar: compactSidebar,
                      )
                    : null,
                child: AspectRatio(
                  aspectRatio: Style.aspectRatio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: Style.mdRadius,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compactSidebar ? 6 : 10,
                    4,
                    6,
                    4,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Container(
                        color: color,
                        width: 200,
                        height: 13,
                        margin: const .only(bottom: 5),
                      ),
                      Container(
                        color: color,
                        width: 150,
                        height: 13,
                      ),
                      if (compactSidebar)
                        const SizedBox(height: 4)
                      else
                        const Spacer(),
                      Container(
                        color: color,
                        width: 100,
                        height: 13,
                        margin: const .only(bottom: 5),
                      ),
                      if (compactSidebar)
                        FittedBox(fit: BoxFit.scaleDown, child: _stats(color))
                      else
                        _stats(color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats(Color color) => Row(
    spacing: 8,
    children: [
      Container(color: color, width: 40, height: 13),
      Container(color: color, width: 40, height: 13),
    ],
  );
}
