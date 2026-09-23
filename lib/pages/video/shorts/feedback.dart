import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

enum ShortVideoHideReason {
  uninterested('不感兴趣'),
  watched('已经看过了'),
  unexpected('内容不符合预期');

  const ShortVideoHideReason(this.label);
  final String label;
}

/// Local recommendation feedback. Related/web feeds supply no server reason
/// IDs; do not substitute a video downvote or invent server feedback values.
class ShortVideoFeedback {
  ShortVideoFeedback(this.box);
  final Box<dynamic> box;
  static const _key = 'shortVideoHiddenVideos';
  static const limit = 1000;

  Map<String, String> get records {
    final stored = box.get(_key);
    return stored is Map
        ? {
            for (final entry in stored.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          }
        : {};
  }

  bool allows(String bvid) {
    final stored = box.get(_key);
    return stored is! Map || !stored.containsKey(bvid);
  }

  Future<void> hide(String bvid, ShortVideoHideReason reason) {
    final next = records..remove(bvid);
    next[bvid] = reason.name;
    while (next.length > limit) {
      next.remove(next.keys.first);
    }
    return box.put(_key, next);
  }

  Future<void> clear() => box.delete(_key);
}

class ShortVideoFeedbackSheet extends StatelessWidget {
  const ShortVideoFeedbackSheet({super.key, required this.hiddenCount});
  final int hiddenCount;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text('我不想看', style: TextStyle(fontSize: 18)),
                ),
              ),
              IconButton(
                tooltip: '取消',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('选择原因后跳过此视频，并在本机短视频推荐中隐藏。'),
          ),
          for (final reason in ShortVideoHideReason.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ImmersiveSurface(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(reason.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, reason),
                ),
              ),
            ),
          if (hiddenCount > 0)
            TextButton.icon(
              // A distinct result; closing the sheet has no side effects.
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.restore),
              label: Text('恢复本机已隐藏的视频（$hiddenCount）'),
            ),
        ],
      ),
    ),
  );
}
