# 构建说明

## 代码来源

- 原项目：[PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，对照提交 `e4185e5b1d0eebfefb9cb6f32933401a4aa23c29`。
- 鸿蒙适配：[dev4harmony/PiliPlus](https://github.com/dev4harmony/PiliPlus/tree/ohos)，基线提交 `381dc884d2cb908d682c357f768d46cdcb929f25`。原生入口、插件桥接、播放器、权限、分享、画中画及接续等代码来自该分支，保留原许可和提交历史。
- Flutter OH：[CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter/tree/oh-3.44.9-dev)，固定标签 `3.44.9+ohos-0.0.1-canary1`（提交 `39285df71a97ffe0c23241dcc459d997a9d8b7c6`）。不能用普通 Flutter 的同名版本替代。

## 环境

目标 SDK 为 `26.0.0`，`compatibleSdkVersion` 为 `6.0.2(22)`，CI 使用 DevEco 工具 `26.0.0.821`。命令行工具的版本、下载源和 SHA256 见 [`toolchain.json`](toolchain.json)。

1. 从[华为开发者网站](https://developer.huawei.com/consumer/cn/deveco-studio/)安装配套的 DevEco Studio 与 SDK。
2. 设置 `HARMONY_FLUTTER_HOME` 指向 Flutter OH。`.fvmrc` 仅作版本提示。
3. 安装 SDK 配套的 Node、ohpm、Hvigor 和 Git LFS。用 `DEVECO_SDK_HOME` 或 `HOS_SDK_HOME` 指定 SDK 位置。
4. 在 DevEco Studio 中配置签名。证书、密码和个人路径不入库。

本机路径可写入被 Git 忽略的 `.harmony-env.local`。

## 构建

```sh
bash tool/harmony.sh doctor    # 检查环境
bash tool/harmony.sh debug     # 调试构建
bash tool/harmony.sh release   # 发布构建
bash tool/check_harmony_layout.sh   # 无原生 SDK 时仅检查布局
```

脚本依次检查工具、解析依赖、运行布局测试，再把工程同步到英文临时路径构建（Hvigor 不接受中文路径）。产物位于 `build/harmony/<release|debug>/default/outputs/default/`。

默认不签名，未签名 HAP 无法安装到设备。签名时，把 DevEco 生成的完整 `ohos/build-profile.json5` 另存为被忽略的 `ohos/build-profile.local.json5`，再运行：

```sh
HARMONY_CODESIGN=1 bash tool/harmony.sh release
```

每个 HAP 附带 SHA256 与 `.build.json` 源码/SDK 记录。工程沿用社区分支的包名，安装前请留意设备上同包名版本的签名是否一致。

## 验收规则

每项验收记录应包含构建提交、HAP 哈希、设备与 API 版本、操作步骤、预期与实际结果，以及日志或截图。自动测试、模拟器、真机与未验证须分开记录，构建通过不代表功能可用。

仅在有官方权限限制依据并经设备验证时，才可将某项记为系统权限例外；编译错误、插件缺失、未实现或网络/账号问题都不算。

## 设备测试矩阵

自动测试中的窗口宽度是合成值，不代表真机参数。以下场景需在真机验证：

| 场景 | 要求 |
| --- | --- |
| 折叠、展开各形态，横竖屏 | 导航、视频网格、搜索、动态、评论、设置无溢出或重复栏 |
| 滚动后反复折叠/展开 | 页签、滚动位置和加载结果保持，不重复初始化 |
| 播放中折叠/展开及旋转 | 进度、音轨、字幕、弹幕、清晰度保持，不重建播放器 |
| 分屏/自由窗口调整 | 按窗口尺寸布局，全屏退出正常，安全区正确 |
| 键盘弹出时折叠，调整字体/显示大小 | 输入框可见，焦点与草稿保留 |
| 后台、锁屏、回前台及画中画 | 音频、媒体通知、恢复播放和关闭正确 |
| 登录、多账号、扫码、验证码 | 会话持久、账号隔离、WebView 验证可用 |
| 缓存、离线、保存、分享、投屏 | 文件读写正常，拒绝权限后可恢复 |
| 普通手机与平板 | 布局和核心流程无退化 |
