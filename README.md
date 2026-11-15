# PiliPlus Harmony

[PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的鸿蒙版，为手机、平板和折叠屏适配，由 **厄斯因二次编辑** 维护。

当前版本 **Beta 1.1**（`1.1.0-beta`，构建 `6254`）。请在 [Releases](https://github.com/2751833085/PiliPlus-Harmony/releases) 下载签名 HAP 手动安装，问题请提交 [Issues](https://github.com/2751833085/PiliPlus-Harmony/issues)。

## 功能

- 鸿蒙风格界面、原生顶栏与底栏，可选沉浸光感。
- 为折叠屏各形态优化首页、搜索和视频详情布局，自动避让安全区与挖孔。
- 保留推荐、动态、个人页、搜索、评论、消息和离线缓存等原有功能。
- 播放器控制、弹幕、合集/分 P、空降助手和海外线路。

## 版本

- [Beta 1.1 版本说明](releases/beta-1.1/notes.md) · [验证记录](docs/harmony/beta-1.1-6254-validation.md)
- [Beta 1.2 候选说明](releases/beta-1.2/notes.md)
- [版本档案](releases/README.md)

## 构建

```sh
bash tool/harmony.sh doctor
bash tool/harmony.sh release
```

需要 Flutter OH `3.44.9+ohos-0.0.1-canary1` 和 HarmonyOS SDK 26，普通 Flutter 无法构建本项目。详见[构建说明](docs/harmony/README.md)。

GitHub Actions 会运行完整 Dart 回归并编译 HAP。CI 产物未签名，仅用于构建诊断；应用内更新只使用发布页的签名 HAP。

## 目录

| 目录 | 内容 |
| --- | --- |
| `lib/` | Flutter 业务、页面和组件 |
| `lib/harmony_adapt/` | 鸿蒙桥接、窗口布局和界面适配 |
| `ohos/` | ArkTS 宿主、原生组件和 HAP 配置 |
| `packages/` | 本地兼容包和鸿蒙播放器 |
| `test/` | 自动回归测试 |
| `tool/` | 构建、诊断和播放器重建工具 |
| `docs/` | 构建说明与验证记录 |
| `releases/` | 版本说明和构建元数据 |

证书、私钥、账号数据、SDK 和构建缓存不入库。

## 来源与许可

业务代码来自 PiliPlus，鸿蒙基础适配来自 [dev4harmony/PiliPlus](https://github.com/dev4harmony/PiliPlus/tree/ohos)，贡献者信息见[来源说明](docs/upstream/README.md)。本项目以 [GPL-3.0](LICENSE) 发布，原生依赖许可见 `packages/media_kit_libs_ohos/third_party_licenses`。
