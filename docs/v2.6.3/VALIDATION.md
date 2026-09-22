# V2.6.3 验证记录

版本 `2.6.3+6089`，源码 `84f4475b39a6e567575095c78441cd6812a92a0a`。签名 HAP SHA256 `83d135d49331466d699304a4246c5327cebe8d86089c78b4f9703a07bdc587c2`。

- **63 项 Flutter 回归通过**，Dart **0 错误、6 项原有警告**。
- 实际 ShortVideoFeed 在 320×640、840×800、600×320 和 1.8 倍字号下渲染普通/简洁预览，并人工检查底部布局。使用测试数据与占位播放器。
- 隐藏信息层后底部进度条仍命中触控，点按和拖动均调用 seek，不恢复信息层；播放/暂停图标位于进度条左侧，状态切换位置相同。信息显隐不改变视频、进度条尺寸及播放器 State。
- 按钮双击只切换一次播放；原有分页、自动播放、缓存与手势自定义回归通过。
- SDK 26 / Flutter OH Release 构建、HAP CRC/AOT/ARM64 原生库和 mpv 固定哈希检查、官方代码签名/摘要/权限签名校验通过。

Mate XTS 已用 `install -r` 从 V2.6.2 覆盖升级到 **2.6.3 / 6089**；UID、首次安装时间、appId 和 appIdentifier 保留，未卸载或清除数据。正常启动被 **10106102** 拒绝，设备锁屏；没有自动解锁或更改设备安全设置。本版真机底部交互与原生播放性能尚未验证。

本机日志为 `/tmp/piliplus-v263-test.log`、`/tmp/piliplus-v263-layout.log`、`/tmp/piliplus-v263-analyze.log`、`/tmp/piliplus-v263-build.log`、`/tmp/piliplus-v263-signature.log`、`/tmp/piliplus-v263-install.log`、`/tmp/piliplus-v263-launch.log`。预览为 `/tmp/piliplus-v263-layout-320.png`、`-840.png`、`-600.png` 及对应 `-minimal-` 版本；临时文件可能被系统清理。

[签名包归档](../../releases/v2.6.3-rc1/README.md) · [验证摘要](validation.json)。仅本地归档，未 push。
