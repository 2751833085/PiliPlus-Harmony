# V2.6.1 验证记录

应用版本 `2.6.1+6087`，源码 `09da7f1f08254255b34a00ca8e0f2aeacf8eb04d`。
[签名 HAP 归档](../../releases/v2.6.1-rc1/README.md)，SHA256 `24530514c25e68116a121b5c73a383ddc3fa33fb2c8de09bcfda2ecbe9db63df`。

## 已完成

- **60 项 Flutter 回归通过**，包括既有 V2/V2.5/V2.6 回归。Dart 分析 **0 错误、6 项原有警告**。
- 单击/双击使用实际生产手势识别器验证：双击仅切换一次播放，不附带单击或点赞；单击切换信息层。隐藏层不拦截点击，播放按钮单击/双击均只触发一次。
- 两侧默认调进度；自定义左滑评论、右滑作者时不同时改进度；短距离、取消手势不导航。纵向分页、首条下拉刷新及控制锁回归保留。
- 单屏 320×640、展开 840×800、横向 600×320 的实际 ShortVideoFeed 普通/简洁界面布局检查（1.8 倍字、测试数据、占位播放器），切换信息层及全屏保留同一播放器状态。预览字体不随 HAP 分发。
- 预加载元数据可独立于媒体完成状态消费；不同帐号/画质上下文不混用，过时任务和已销毁页面不发布结果，当前缓冲时取消预取，恢复后复用元数据。
- 本地 HTTP 真请求验证：缓存头部直接返回、不重复下载；跨缓存边界和完整文件 Range 拼接字节正确；支持尾部范围、HEAD；无效范围、未知地址、过期缓存和错误响应安全结束。没有以线上帐号写操作做测试。
- SystemPosture 原生隔离检查通过：握姿开关、去抖、折叠、后台订阅、不支持设备。
- Flutter OH / SDK 26 Release 签名构建通过；HAP CRC、ArkTS/Flutter AOT、ARM64 原生库和固定 mpv 哈希检查通过；官方代码签名、摘要和权限签名验证通过。

## 设备结果与限制

用户重新连接手机后，V2.6.1 已通过 `install -r` 覆盖安装成功。系统包版本确认为 **2.6.1 / 6087**，UID、首次安装时间、appId 与 appIdentifier 均与 V2.6.0 相同；未卸载或清除应用数据。

正常启动被系统以 **10106102** 拒绝：设备屏幕锁定，开发模式不允许自动解锁。未绕过锁屏或更改设备安全设置，需解锁后打开应用。安装成功不代表媒体播放验收通过。

媒体缓存的本地 HTTP 字节复用已经验证，但鸿蒙原生播放器实际读取缓存、失败换源、连续快速滑动的首帧与流畅度仍需实机运行；海外网络性能、功耗、整体内存及物理折叠同样未实测。保留候选版标记，不声称在任意网络零加载或完整复刻当前各平台原版。

## 证据与复现

```sh
flutter test --no-pub test/harmony_adapt
dart analyze --format machine
node tool/test_harmony_posture.cjs
HARMONY_CODESIGN=1 bash tool/harmony.sh release
```

本机日志：`/tmp/piliplus-v261-test.log`、`/tmp/piliplus-v261-analyze.log`、`/tmp/piliplus-v261-posture.log`、`/tmp/piliplus-v261-build.log`、`/tmp/piliplus-v261-signature.log`、`/tmp/piliplus-v261-layout.log`、`/tmp/piliplus-v261-install.log`、`/tmp/piliplus-v261-launch.log`。组件预览为 `/tmp/piliplus-v261-layout-320.png`、`-840.png`、`-600.png` 及对应 `-minimal-` 版本。

[可入库验证摘要](validation.json) · [构建元数据](../../releases/v2.6.1-rc1/PiliPlus-Harmony-V2.6.1-2.6.1-6087-signed.build.json)。临时日志可能被系统清理；签名私钥、配置、设备身份不入库。本地归档，未 push。
