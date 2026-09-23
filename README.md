# PiliPlus Harmony

基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的鸿蒙 HAP 项目，面向手机、平板和折叠屏，优先适配 Huawei Mate XTS。

由 **厄斯因二次编辑** 维护鸿蒙适配。在原有播放器与业务功能基础上，增加可选鸿蒙界面、原生 Dock/加载、系统智感握姿、折叠适配、竖屏短视频和海外播放优化。竖屏短视频与海外模式均在「其他设置」中手动启用。

当前候选版本为 **V2.7 RC1（2.7.0+6106）**。139 项鸿蒙适配回归通过，签名 HAP 已无线覆盖安装并保留应用数据。真实刷新观感与物理展开后的交互仍待设备空闲时验收，详见[验证记录](docs/v2.7/VALIDATION.md)。

本仓库提供源码、构建方法和版本记录。开发签名 HAP 只在本地归档，不随源码上传；`releases/` 中的包名和哈希是构建记录，不是公共下载地址。

## 开始使用

```sh
bash tool/harmony.sh doctor
bash tool/harmony.sh release
```

需要 Flutter OH `3.44.9+ohos-0.0.1-canary1` 和 HarmonyOS SDK 26。
普通 Flutter 不能生成本项目 HAP。SDK 路径配置在本机 `.harmony-env.local`，该文件不入库。
完整环境、签名和真机步骤见[构建说明](docs/harmony/README.md)。

## 版本与进度

| 版本 | 定位 | 入口 |
| --- | --- | --- |
| V2.7 RC1 | 首页按栏数适配、刷新淡出后回弹、评论保留播控与切页 | [版本记录](releases/v2.7.0-rc1/README.md) · [说明](docs/v2.7/README.md) |
| V2.6.18 RC1 | 切页首帧衔接、连贯下拉刷新与默认距离档 | [版本记录](releases/v2.6.18-rc1/README.md) · [验证记录](docs/v2.6.18/VALIDATION.md) |
| V2.6.17 RC1 | 原生显隐异步保护、预加载失败回退和队列快照复用 | [版本记录](releases/v2.6.17-rc1/README.md) · [验证记录](docs/v2.6.17/VALIDATION.md) |
| V2.6.16 RC1 | DevEco 运行回归、预取重建优化、沙箱缓存与评论对比度修复 | [版本记录](releases/v2.6.16-rc1/README.md) · [验证记录](docs/v2.6.16/VALIDATION.md) |
| V2.6.15 RC1 | 可选历史卡片、账号请求保护与挖孔/手势区避让；真机验收待解锁 | [版本记录](releases/v2.6.15-rc1/README.md) · [验证记录](docs/v2.6.15/VALIDATION.md) |
| V2.6.14 RC1 | 播放栏动画防误触与迟到尺寸信息切换保护 | [版本记录](releases/v2.6.14-rc1/README.md) · [说明](docs/v2.6.14/README.md) |
| V2.6.13 RC1 | 双手握持居中，握姿切换防抖与触控保护 | [版本记录](releases/v2.6.13-rc1/README.md) · [说明](docs/v2.6.13/README.md) |
| V2.6.12 RC1 | 统一贴底菜单、更多光感表面、三折全宽播放栏与关于页 | [版本记录](releases/v2.6.12-rc1/README.md) · [说明](docs/v2.6.12/README.md) |
| V2.6.11 RC1 | 选集可用、弹层优先返回、显隐与暂停独立、单行普通播控 | [版本记录](releases/v2.6.11-rc1/README.md) · [说明](docs/v2.6.11/README.md) |
| V2.6.10 RC1 | 圆角裁切、普通播放器单行时间、进度条与空降标记对齐 | [版本记录](releases/v2.6.10-rc1/README.md) · [说明](docs/v2.6.10/README.md) |
| V2.6.9 RC1 | 短视频字号与控件比例统一、进度条点击和绘制位置修正 | [版本记录](releases/v2.6.9-rc1/README.md) · [验证记录](docs/v2.6.9/VALIDATION.md) |
| V2.6.8 RC1 | 底部关联搜索、短弹幕输入入口与独立弹幕设置 | [版本记录](releases/v2.6.8-rc1/README.md) · [验证记录](docs/v2.6.8/VALIDATION.md) |
| V2.6.7 RC1 | 图标与数量、紧凑作者关注行、按视频比例验证布局 | [版本记录](releases/v2.6.7-rc1/README.md) · [验证记录](docs/v2.6.7/VALIDATION.md) |
| V2.6.6 RC1 | 参考 iOS 的短视频暂停状态与中央继续播放入口 | [版本记录](releases/v2.6.6-rc1/README.md) · [验证记录](docs/v2.6.6/VALIDATION.md) |
| V2.6.5 RC1 | 按视频比例进入短视频、连续预加载、参考 iOS 的播控与评论布局 | [版本记录](releases/v2.6.5-rc1/README.md) · [验证记录](docs/v2.6.5/VALIDATION.md) |
| V2.6.4 RC1 | 模式切换过渡、紧凑评论、缩小图标和不想看原因选择 | [版本记录](releases/v2.6.4-rc1/README.md) · [验证记录](docs/v2.6.4/VALIDATION.md) |
| V2.6.3 RC1 | 简洁模式保留进度条、底部播放/暂停按钮 | [版本记录](releases/v2.6.3-rc1/README.md) · [验证记录](docs/v2.6.3/VALIDATION.md) |
| V2.6.2 RC1 | 平稳分页、快速切换保留播放器、短视频自动播放 | [版本记录](releases/v2.6.2-rc1/README.md) · [验证记录](docs/v2.6.2/VALIDATION.md) |
| V2.6.1 RC1 | 双击播放、简洁界面、左右滑自定义、下一条媒体预加载 | [版本记录](releases/v2.6.1-rc1/README.md) · [使用说明](docs/v2.6.1/README.md) · [验证记录](docs/v2.6.1/VALIDATION.md) |
| V2.6 RC1 | 展开全屏刷视频、第一条下拉刷新、可选海外模式 | [版本记录](releases/v2.6.0-rc1/README.md) · [使用说明](docs/v2.6/README.md) · [验证记录](docs/v2.6/VALIDATION.md) |
| V2.5 RC1 | 竖屏短视频信息流，其他设置手动启用 | [版本记录](releases/v2.5.0-rc1/README.md) · [使用说明](docs/v2.5/README.md) · [验证记录](docs/v2.5/VALIDATION.md) |
| V2 RC2 | 统一界面、设置互斥、原生加载与播放器控制改进 | [版本记录](releases/v2.0.0-rc2/README.md) · [验证记录](docs/v2/VALIDATION.md) |
| V1 | 功能移植与回退基线，标签 `harmony-v1.0.0` | [版本记录](releases/v1.0.0/README.md) |

[更新记录](CHANGELOG.md) · [开发约定](CONTRIBUTING.md) · [文档目录](docs/README.md) · [147 项功能核对](docs/harmony/feature-matrix.json)

## 工程结构

```text
lib/                 Flutter 业务、页面、通用组件
  harmony_adapt/     鸿蒙桥接、布局策略和可选界面组件
ohos/                ArkTS 宿主、HDS 组件、系统能力、HAP 配置
packages/            本地兼容包与固定版本的鸿蒙播放器
assets/              字体、图片、着色器
test/harmony_adapt/   鸿蒙适配回归测试
tool/                构建、环境诊断、播放器重建脚本
docs/                开发设计、来源、构建与验收记录
releases/            本地版本归档和可入库的构建元数据
build/               可再生成的构建产物与日志（不入库）
```

其他平台目录保留上游结构，以便同步功能和回归，避免移动路径破坏插件及构建工具。
证书、私钥、账号、本机 SDK、编译缓存和 HAP 二进制不进入 Git 历史。

## 来源与许可

业务代码来自 PiliPlus；鸿蒙基础适配来自 [dev4harmony/PiliPlus](https://github.com/dev4harmony/PiliPlus/tree/ohos)。
项目保留 GPL-3.0 [LICENSE](LICENSE)，原生依赖各自许可见 `packages/media_kit_libs_ohos/third_party_licenses`。
[原项目与社区分支说明](docs/upstream/README.md)保留贡献者、功能清单与来源信息。
