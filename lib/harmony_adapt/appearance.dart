import 'package:flutter/foundation.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

enum HarmonyNavigation with EnumWithLabel {
  floatingDock('悬浮 Dock'),
  bottomBar('底部导航'),
  sideBar('侧栏');

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
      ? '因为开启了鸿蒙界面风格，此选项已由鸿蒙导航接管，无法选择。请前往“外观设置 → 鸿蒙底栏与侧栏”调整导航。关闭鸿蒙界面风格后将恢复原设置。'
      : null;

  /// A chosen accent replaces the pink preset, never the Harmony UI style.
  static Future<void> selectCustomColors() async {
    await GStorage.setting.put(SettingBoxKey.harmonyNativeColors, false);
    changed();
  }
}
