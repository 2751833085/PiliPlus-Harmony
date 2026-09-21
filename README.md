# PiliPlus Harmony

基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的鸿蒙 HAP 项目，面向手机、平板和折叠屏，优先适配 Huawei Mate XTS。

V1 保存功能移植基线；V2 在保留既有功能与信息布局的基础上，增加可选的鸿蒙界面风格、展开屏 Dock、系统智感握姿与稳定的封面过渡。

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
| V1 | 功能移植与回退基线，标签 `harmony-v1.0.0` | [版本记录](releases/v1.0.0/README.md) |
| V2 RC1 | 鸿蒙体验候选版，已签名并在 Mate XTS 覆盖安装 | [HAP 与版本记录](releases/v2.0.0-rc1/README.md) · [验证记录](docs/v2/VALIDATION.md) |

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
