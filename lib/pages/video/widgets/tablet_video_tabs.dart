import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/harmony_adapt/harmony_motion.dart';

/// The right column owns its paging; it never moves the player or introduction.
class TabletVideoTabs extends StatelessWidget {
  const TabletVideoTabs({super.key, this.related, this.comments});
  final Widget? related;
  final Widget? comments;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ?related,
      ?comments,
    ];
    if (pages.isEmpty) return const SizedBox.expand();
    if (pages.length == 1) return pages.single;
    return DefaultTabController(
      length: 2,
      animationDuration: HarmonyMotion.duration,
      child: Column(
        children: [
          const SizedBox(
            height: 46,
            child: TabBar(
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: '更多视频'),
                Tab(text: '评论'),
              ],
            ),
          ),
          Expanded(
            child: tabBarView(
              children: [
                for (final page in pages) KeepAliveWrapper(child: page),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
