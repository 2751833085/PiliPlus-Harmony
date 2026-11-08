# PiliPlus Harmony

基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的鸿蒙 HAP 项目，面向手机、平板和折叠屏，由 **厄斯因二次编辑** 维护。

当前阶段：**Beta 1.0**，首个 Beta 版本。内部版本为 `3.0.0+6252`，沿用递增构建号，兼容已安装版本的更新检测。

[下载与版本说明](https://github.com/2751833085/PiliPlus-Harmony/releases) · [Beta 1.0 验证记录](docs/harmony/beta-1.0-validation.md) · [问题反馈](https://github.com/2751833085/PiliPlus-Harmony/issues)

## 功能与范围

- 鸿蒙界面、原生顶部与底部导航、可选沉浸光感。
- 手机、双屏、三屏的搜索、推荐与视频详情布局，安全区和挖孔避让。
- 推荐、动态、个人页、搜索、评论、消息与离线缓存等原有业务功能。
- 播放器控制、弹幕、合集/分 P、空降助手和海外线路选项。

Beta 1.0 重点修复快速操作和异步请求的竞态，并核查原生资源释放、下载状态和更新发布流程。验证记录区分自动测试、模拟器检查与仍需真机/登录的项目；不将模拟器结果等同于所有设备无卡顿、无缺陷。

## 版本管理

Beta 1.0 之前的版本统一归档为 **Alpha**，包括旧说明中曾使用的 Beta、RC 和 Test Build 名称。历史发布保留详情和原始 Git 标签，不再提供旧 HAP 下载。旧目录名、文件名和构建哈希保留用于追溯，不代表当前发布阶段。

- [Beta 1.0 版本说明](releases/beta-1.0/notes.md)
- [历史版本与目录说明](releases/README.md)
- [开发文档目录](docs/README.md)
- [原上游功能清单](docs/harmony/feature-matrix.json)

## 构建

```sh
bash tool/harmony.sh doctor
bash tool/harmony.sh release
```

需要 Flutter OH `3.44.9+ohos-0.0.1-canary1` 和 HarmonyOS SDK 26。普通 Flutter 不能生成本项目 HAP。本机 SDK 和签名路径配置不入库，详见[构建说明](docs/harmony/README.md)。

GitHub Actions 固定 Ubuntu 24.04、显式安装鸿蒙编译器运行依赖，并执行完整 Dart 回归与 HAP 编译。Actions 中的未签名产物用于构建诊断；应用更新仅选择发布页中已上传完成的签名 HAP。

## 工程目录

| 目录 | 内容 |
| --- | --- |
| `lib/` | Flutter 业务、页面和通用组件 |
| `lib/harmony_adapt/` | 鸿蒙桥接、窗口布局和界面适配 |
| `ohos/` | ArkTS 宿主、原生组件、系统能力和 HAP 配置 |
| `packages/` | 本地兼容包和固定版本的鸿蒙播放器 |
| `assets/` | 字体、图片和着色器 |
| `test/` | 自动回归测试 |
| `tool/` | 构建、环境诊断和原生播放器重建工具 |
| `docs/` | 设计、构建、功能核查与验证记录 |
| `releases/` | 版本详情和构建元数据；HAP 不入 Git 历史 |

保留上游平台目录与已有路径，以便同步功能，不迁移插件所依赖的目录。证书、私钥、账号数据、SDK 和构建缓存不进入 Git 历史。

## 来源与许可

业务代码来自 PiliPlus，鸿蒙基础适配来自 [dev4harmony/PiliPlus](https://github.com/dev4harmony/PiliPlus/tree/ohos)。项目保留 GPL-3.0 [LICENSE](LICENSE)，原生依赖许可见 `packages/media_kit_libs_ohos/third_party_licenses`。[来源说明](docs/upstream/README.md)保留贡献者与上游功能信息。
