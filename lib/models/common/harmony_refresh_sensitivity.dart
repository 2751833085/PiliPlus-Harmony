import 'package:PiliPlus/models/common/enum_with_label.dart';

enum HarmonyRefreshSensitivity implements EnumWithLabel {
  light('轻拉', 56),
  standard('标准', 72),
  firm('较重', 92);

  const HarmonyRefreshSensitivity(this.label, this.triggerDistance);

  @override
  final String label;
  final double triggerDistance;
}
