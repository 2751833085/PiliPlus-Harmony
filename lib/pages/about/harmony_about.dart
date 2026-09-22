import 'package:PiliPlus/common/assets.dart';
import 'package:material_ui/material_ui.dart';

class HarmonyAboutHeader extends StatelessWidget {
  const HarmonyAboutHeader({
    super.key,
    required this.version,
    required this.onLogoTap,
    this.onLogoSecondaryTap,
  });
  final String version;
  final VoidCallback onLogoTap;
  final VoidCallback? onLogoSecondaryTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        GestureDetector(
          onTap: onLogoTap,
          onSecondaryTap: onLogoSecondaryTap,
          child: Image.asset(
            Assets.logo,
            width: 88,
            height: 88,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PiliPlus 鸿蒙版',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(version, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        const Text(
          '厄斯因二次编辑',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          '基于开源 PiliPlus 的哔哩哔哩第三方客户端',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class HarmonyAboutGroup extends StatelessWidget {
  const HarmonyAboutGroup({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ImmersiveSurface(child: Column(children: children)),
      ],
    ),
  );
}

class HarmonyDevelopmentJourney extends StatelessWidget {
  const HarmonyDevelopmentJourney({super.key});
  @override
  Widget build(BuildContext context) => HarmonyAboutGroup(
    title: '我们的开发历程',
    children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in const [
              ('V1', '鸿蒙移植', '保留原有功能，适配手机、平板与折叠屏。'),
              ('V2', '鸿蒙界面', '可选原生配色、沉浸光感与展开导航。'),
              ('V2.5', '竖屏短视频', '在原有播放器上加入连续浏览与手势操作。'),
              ('V2.6', '体验打磨', '优化预加载、播放控制、弹层与多屏布局。'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(
                        step.$1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$2,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.$3,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),
            Text(
              '开发流程：需求整理 → 实现 → 自动化回归 → 真机验证 → HAP 归档',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '感谢 PiliPlus 上游及开源贡献者。改编版本保留原项目的开源许可与署名。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
