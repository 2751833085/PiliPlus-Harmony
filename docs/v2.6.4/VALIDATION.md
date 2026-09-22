# V2.6.4 验证记录

版本 `2.6.4+6090`，源码 `0dcded5a9336121a07630b7b7c826ff53d497db5`。签名 HAP SHA256 `ef0d03ffee158c72f5c32e2f44cb1d05dda359e777d0581167a248f81637aa22`。

- **72 项 Flutter 回归通过**，签名构建流程再次通过同一套检查。Dart **0 错误、6 项原有警告**。
- 模式切换仅保留一个播放器 State；覆盖重复触发、正常/短视频往返、减少动态效果和动画中退出。
- 不想看覆盖中间页/最后一页替换、上一条和下一条继续滑动、并发与过期回调隔离、播放/网络失败恢复、持久化原因及清除记录；不对真实账号执行写入测试。
- 实际 ShortVideoFeed 使用假数据和占位播放器，在 320×640、840×800、600×320、1.8 倍字号下渲染。人工检查缩小图标、原因弹层和紧凑评论标题预览；评论标题标准字号高 48dp，关闭按钮保留 48dp 触控区域。
- 原因弹层选择、取消与恢复，评论标题排序与关闭测试通过。短视频评论容器补上 MiniScaffold，供既有二级回复弹层使用；真实评论及二级回复交互仍待设备验收。
- SDK 26 / Flutter OH Release 构建、HAP CRC/AOT/ARM64 原生库和 mpv 固定哈希检查，以及官方代码签名/摘要/权限签名校验通过。

Mate XTS 已用 `install -r` 从 2.6.3 / 6089 覆盖升级为 **2.6.4 / 6090**。UID、首次安装时间、appId、appIdentifier 均保留，未卸载或清除数据。正常启动被 **10106102** 拒绝，手机锁屏；电脑也锁定，无法打开 DevEco 可视化界面。未绕过锁屏或更改安全设置。

因此本版 HAP 的真机动画、评论/二级回复、反馈菜单、原生播放和帧耗时尚未验证。自动测试与布局预览不能替代真机体验验收。

本机日志 `/tmp/piliplus-v264-test.log`、`/tmp/piliplus-v264-layout.log`、`/tmp/piliplus-v264-analyze.log`、`/tmp/piliplus-v264-build.log`、`/tmp/piliplus-v264-signature.log`、`/tmp/piliplus-v264-install.log`、`/tmp/piliplus-v264-launch.log`。预览 `/tmp/piliplus-v264-layout-320.png`、`-840.png`、`-600.png`、`-minimal-*.png`、`-feedback.png` 和 `-comment-header-*.png`，临时文件可能被系统清理。

[签名包归档](../../releases/v2.6.4-rc1/README.md) · [验证摘要](validation.json)。仅本地归档，未 push。
