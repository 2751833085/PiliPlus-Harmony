import 'package:PiliPlus/harmony_adapt/appearance.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/harmony_adapt/widgets/harmony_switch.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:get/get.dart';

import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';

void refreshHarmonySettings(bool _) {
  HarmonyAppearance.changed();
  Get.updateMyAppTheme();
  if (Get.isRegistered<MainController>()) {
    Get.find<MainController>().refreshHarmonyAppearance();
  }
}

List<SettingsModel> get harmonyAppearanceSettings => [
  if (Pref.harmonyUI) ...[
    SwitchModel(
      section: '鸿蒙界面风格',
      title: '沉浸光感',
      subtitle: '为底栏、顶栏、菜单、播放面板与账户卡片启用光感材质；关闭后使用实色背景',
      leading: const Icon(Icons.water_drop_outlined),
      setKey: SettingBoxKey.harmonyImmersive,
      defaultVal: true,
      onChanged: refreshHarmonySettings,
    ),
  ],
  const SwitchModel(
    section: '交互与动画',
    title: '点击系统状态栏快速返回顶部',
    subtitle: '开启后在鸿蒙/iOS设备上，绝大部分列表点击状态栏可以快速回顶。\n关闭后除了部分原生支持的界面，均不再响应状态栏点击。',
    leading: Icon(Icons.vertical_align_top_outlined),
    setKey: SettingBoxKey.enableStatusBarTapToTop,
    defaultVal: false,
  ),
];

List<SettingsModel> get harmonyPlaybackSettings => [
  const SwitchModel(
    section: '全屏与折叠屏',
    title: '全屏跟随折叠形态',
    subtitle: '默认开启：展开时重新适配全屏方向，合回单屏时回到详情页播放器并继续播放；关闭后保留原有全屏方向行为',
    leading: Icon(Icons.screen_rotation_alt_outlined),
    setKey: SettingBoxKey.harmonyFoldOrientation,
    defaultVal: true,
  ),
  const SwitchModel(
    section: '播放控制',
    title: '显示实际百分比音量',
    subtitle:
        '某些系统(鸿蒙)或设备只支持整数音量级别，如0~15，对应的百分比音量只有0%、7%、···、93%和100%，不存在1%、2%和50%等实际百分比音量',
    leading: Icon(Icons.science_outlined),
    setKey: SettingBoxKey.showActualVolume,
    defaultVal: false,
  ),
];

List<SettingsModel> get experimentalSettings => [
  NormalModel(
    section: '系统能力',
    title: '应用接续',
    subtitle: '相同华为用户播放视频时可在另一个设备的Dock栏中快速流转，无缝衔接上一个设备的视频。（始终开启）',
    leading: const Icon(Icons.devices_other),
    getTrailing: (theme) => theme.extension<HarmonyStyle>() != null
        ? const HarmonySwitch(value: true, onChanged: null)
        : IgnorePointer(
            child: Transform.scale(
              scale: 0.8,
              alignment: Alignment.centerRight,
              child: Switch(
                value: true,
                onChanged: (_) {},
                thumbIcon: WidgetStateProperty.all(
                  const Icon(Icons.lock_outline_rounded),
                ),
              ),
            ),
          ),
  ),
  NormalModel(
    section: '系统能力',
    title: '后台下载离线缓存视频',
    subtitle: '接入鸿蒙后台任务，切换至后台不中断离线缓存视频下载（始终开启）',
    leading: const Icon(Icons.downloading),
    getTrailing: (theme) => theme.extension<HarmonyStyle>() != null
        ? const HarmonySwitch(value: true, onChanged: null)
        : IgnorePointer(
            child: Transform.scale(
              scale: 0.8,
              alignment: Alignment.centerRight,
              child: Switch(
                value: true,
                onChanged: (_) {},
                thumbIcon: WidgetStateProperty.all(
                  const Icon(Icons.lock_outline_rounded),
                ),
              ),
            ),
          ),
  ),
];

List<SettingsModel> get harmonyNavigationSettings => [];
