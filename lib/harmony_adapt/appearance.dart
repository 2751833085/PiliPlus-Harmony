import 'package:flutter/foundation.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

enum HarmonyNavigation with EnumWithLabel {
  floatingDock('悬浮'),
  bottomBar('经典');

  const HarmonyNavigation(this.label);
  @override
  final String label;
}

abstract final class HarmonyAppearance {
  // Also refreshes settings on covered routes and search results. Changing a
  // navigation option need not change ThemeData to notify these consumers.
  static final revision = ValueNotifier<int>(0);
  static void changed() => revision.value++;

  static String? navigationUnavailable() => Pref.harmonyUI
      ? '因为开启了鸿蒙界面风格，此选项已由鸿蒙导航接管，无法选择。请前往“外观设置 → 底栏样式”调整导航。'
      : null;
}
