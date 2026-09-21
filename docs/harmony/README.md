# PiliPlus 鸿蒙移植与 Mate XTS 验收

当前已产出 ARM64 Release 未签名 HAP，并提供构建入口，尚未完成全部功能真机验收。
首要真机为华为 Mate XTS 三折叠，系统为 HarmonyOS 7.0.0.107 SP8，HDC 已确认设备 API 为 26。

## 代码来源

- 原项目：<https://github.com/bggRGjQaUbCoE/PiliPlus>
  - 固定对照提交：`e4185e5b1d0eebfefb9cb6f32933401a4aa23c29`。
  - 原始代码保留在本地 `main` 分支及 `origin/main`。
- 复用的鸿蒙适配：<https://github.com/dev4harmony/PiliPlus/tree/ohos>
  - 基线提交：`381dc884d2cb908d682c357f768d46cdcb929f25`。
  - 当前开发分支：`harmony/mate-xts`。
  - 原生入口、插件桥接、播放器适配、权限、分享、文件选择、画中画及接续等代码来自该社区分支；保留原许可证及提交历史。
- Flutter OH：<https://gitcode.com/CPF-Flutter/flutter_flutter/tree/oh-3.44.9-dev>
  - 分支浅克隆不能正确识别版本，现固定至官方标签 `3.44.9+ohos-0.0.1-canary1`，提交 `39285df71a97ffe0c23241dcc459d997a9d8b7c6`。
  - 不能使用普通 Flutter 的同名版本替代 OHOS fork。

鸿蒙基线原来缺少的 42 个提交列在 `upstream-gap.txt`，现已作为合并输入适配到工作区。
新增自定义主题色、SC 保存图片、推荐/搜索修复、验证码加载与错误反馈，并迁移新版媒体状态更新。
保留 OHOS 画中画、后台续播、接续、文本选择、WebView 缩放和文件选择器兼容代码；
依赖升级与 Android JNI 生成代码继续使用可编译的鸿蒙基线版本。合并仍是工作区改动，
Git HEAD 仍指向社区基线；源码快照哈希写入每个 HAP 的 `.build.json`。这不是功能等价验收证明。

## 本次新增

- 鸿蒙主页按应用窗口的逻辑宽度选择导航：小于 600 使用底栏，600 及以上使用侧栏。
  使用当前窗口而非设备型号或物理屏幕尺寸，因此分屏缩窄时可回到紧凑布局。
  用户显式启用侧栏的设置继续生效。
- 折叠/展开插入侧栏时，通过稳定的内容节点键保留页面子树。
- 首页搜索栏与主页使用同一导航状态，避免宽竖屏重复出现顶栏和侧栏入口。
- 新增布局状态回归测试与 `tool/harmony.sh` 环境检查/构建入口。
- 修正 `.fvmrc` 版本提示及 CI 吞掉 HAP 构建失败的问题。
- 原生 SaveButton 授权后，把 JPEG 封面和视频作为动态照片写入图库；不再在鸿蒙上静默降级为普通视频。
- 自行绘制字幕描边，恢复描边宽度设置，并保留拖动字幕与背景透明度行为。
- 重编译播放器以恢复响度均衡、启用 Audio Vivid 解码，并保存源码版本、补丁、构建入口及许可证。
- 构建脚本自动同步到英文临时路径，规避 Hvigor 不接受中文工程路径的问题。

这些修改不等于已验证播放中折叠、硬解或所有插件。600 是初始布局断点，
需要在 Mate XTS 的实际逻辑窗口宽度、字体缩放、显示大小下确认。

## 验证记录（2026-09-21）

- 完整工程依赖解析成功；Dart 分析无编译错误，仍有 6 项警告和 64 项提示，主要来自已有代码。
- 7 项回归测试覆盖导航断点、折叠后状态/滚动保留、动态照片异步完成/取消/授权失败、字幕描边与更新。
  动态照片测试模拟 MethodChannel，不证明系统授权和图库写入已经真机通过。
- Release HAP 已编译；导出时校验 ZIP CRC、ArkTS 字节码、Flutter AOT、mpv ARM64 动态库，
  同时生成 HAP SHA256 与 `.build.json` 源码/SDK 记录。
- Mate XTS 已通过 HDC 连接，读取型号 GRL-AL20、版本 7.0.0.107(SP8C00E105R5P4)、API 26。
  尚无开发签名；没有安装、登录、播放、性能或三折叠设备测试结果。
- 已重建并接入包含 loudnorm/dynaudnorm 的播放器，启用鸿蒙音量均衡设置；
  加入 AV3A/Audio Vivid 解码支持。构建记录见 `native-player.md`，实际播放待真机确认。

## 构建环境

鸿蒙基线的实际配置为 Flutter OH `oh-3.44.9-dev`、目标 SDK `26.0.0`，
`compatibleSdkVersion` 为 `6.0.2(22)`，CI 使用 DevEco 工具版本 `26.0.0.821`。
用户已报告 HarmonyOS 7；仍以真机 API 和安装结果确认兼容性，不通过修改 SDK 数字冒充兼容。

本机 DevEco Studio 6.0.1.251 内置 API 21，不能直接构建此基线。已另行配置
API 26 命令行工具，来源与社区 CI 一致，版本、下载源和 SHA256 见 `toolchain.json`。
独立工具链不替换本机 DevEco Studio。

1. 从[华为官方下载页](https://developer.huawei.com/consumer/cn/deveco-studio/)
   安装配套 DevEco Studio/SDK。本次访问下载按钮跳转到华为账号登录。
2. 配置鸿蒙 Flutter SDK。普通 FVM 的 `3.44.9` 不包含鸿蒙支持；
   `.fvmrc` 仅是版本提示。设置 `HARMONY_FLUTTER_HOME` 指向 OHOS fork。
3. 安装 SDK 配套的 Node、ohpm、Hvigor 和 Git LFS。本机使用 DevEco 自带 JDK 21 编译通过。
   SDK 位置用 `DEVECO_SDK_HOME` 或 `HOS_SDK_HOME` 指定。
4. 签名通过 DevEco Studio 的项目签名设置配置。账号、设备调试授权及私钥由本人管理；
   不提交证书、密码或个人签名路径。

```sh
# 本次临时下载位置；/tmp 可能被系统清理，长期使用请另行保存 SDK。
export HARMONY_FLUTTER_HOME=/tmp/piliplus-flutter-ohos
export HARMONY_COMMAND_LINE_TOOLS_HOME=/tmp/piliplus-sdk-26/command-line-tools
bash tool/harmony.sh doctor
bash tool/harmony.sh debug
# 或发布构建（仍需配置对应签名）
bash tool/harmony.sh release
# 无原生 SDK 时可单独验证布局组件（不代表完整应用编译通过）
bash tool/check_harmony_layout.sh
```

脚本先检查依赖工具，随后解析依赖、执行新增布局测试，再构建 HAP。
本机的 `.harmony-env.local` 已保存以上路径并被 Git 忽略，可直接运行脚本。
产物复制到 `build/harmony/release/default/outputs/default/`（调试模式为 `debug/`）。
默认 `--no-codesign`；unsigned HAP 不能直接安装到手机。

签名需在英文构建目录中通过 DevEco 配置。为避免下次同步覆盖本地签名配置，
将签名后的完整 `ohos/build-profile.json5` 存为源工程下被忽略的
`ohos/build-profile.local.json5`，并使用 `HARMONY_CODESIGN=1 bash tool/harmony.sh release`。
签名覆盖文件的 SDK 设置同样接受预检；证书保留本机，不提交仓库。
工程仍沿用社区分支的包标识，真机安装前注意已有同包名版本及签名是否一致。

## 完整功能验收规则

`feature-matrix.json` 收录原项目 README 中 147 个已勾选条目。
它是最小核对清单，包含“其他”等宽泛条目，不能代替全部页面、API 与插件审计。
业务功能（包括本次补齐的音量均衡与 Live Photo）标为 `unverified`，
表示尚未在本次鸿蒙构建上验证，不能据此推断功能缺失或可用。
`route-audit.json` 的静态比对显示原项目与鸿蒙基线均有 70 个命名路由且名称一致；
这不证明对应页面的行为一致，也不涵盖动态推入的页面。

每项验收记录应包含：构建提交、HAP 哈希、设备/API 版本、操作步骤、预期/实际结果、日志或截图。
测试通过后才能改为 `verified`。功能差异使用 `missing` 或 `partial`。
仅在有官方权限限制依据及设备验证时，才填写 `system_permission_exception`；
编译错误、插件缺失、尚未实现、网络或账号问题不属于系统权限例外。

动态照片实现使用 [OpenHarmony 官方保存流程](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/media/medialibrary/photoAccessHelper-movingphoto.md)。
需真机核对长按播放、封面方向、声音，以及不满足系统视频格式/时长条件时的错误反馈。
系统保存按钮由用户点击授权，插件缺少功能不构成权限豁免。

## Mate XTS 测试矩阵

所有场景均需实机验证；自动测试中的 420/700/1100 等数值是合成逻辑宽度，不是 Mate XTS 实测参数。

| 场景 | 验收要求 |
| --- | --- |
| 折叠、双屏展开、三屏展开，横竖屏各一次 | 导航、视频网格、搜索、动态、评论、设置无溢出或重复栏 |
| 首页滚动后反复折叠/展开 | 当前页签、滚动位置和加载结果保持，不重复初始化 |
| 播放中折叠/展开及旋转 | 播放进度、音轨、字幕、弹幕、清晰度保持，不重复建立播放器 |
| 分屏/自由窗口改变尺寸 | 依据应用窗口调整，视频全屏退出正常，安全区正确 |
| 键盘打开时折叠，字体/显示大小调整 | 搜索、回复、私信输入可见，焦点与草稿保留 |
| 后台/锁屏/切回前台及画中画 | 音频、媒体通知、恢复播放与关闭行为正确 |
| 登录/多账号/扫码/验证码 | 会话持久化、账号隔离、WebView 验证可用 |
| 缓存/离线/图片视频保存/分享/投屏 | 文件可读写、拒绝权限可恢复、分享及局域网行为正确 |
| 普通手机及平板回归 | 紧凑/大屏布局及上述核心链路无退化 |

最终交付标准：完整功能清单通过（或具备证据的权限例外）、
与固定上游提交的功能差异清零、产出签名 HAP，并完成 Mate XTS 优先的三种设备形态验证。
