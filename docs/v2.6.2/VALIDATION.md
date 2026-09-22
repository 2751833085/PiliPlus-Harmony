# V2.6.2 验证记录

版本 `2.6.2+6088`，源码 `c19d9ad79c9a29212937ca799b273ea54263b3ff`。
[签名 HAP](../../releases/v2.6.2-rc1/PiliPlus-Harmony-V2.6.2-2.6.2-6088-signed.hap)，SHA256 `ac3fa4a4dc6ee084a07764a96acc0cfa4b983540b15adb32612445fc794f686f`。

## 自动验证

- **63 项 Flutter 回归通过**；Dart 静态分析 **0 错误、6 项原有警告**。
- 拖过半页再拉回，不打开其他视频；16 ms 逐帧推进吸附过程，验证页面位置单调且未吸附完成前不换源。
- 第一条换源迟迟不完成时继续滑到第四个目标，视口仍到达最终目标，随后只处理正在执行的请求和最新目标；中间结果不引起页面回跳，原播放器 State 保留且只存在一个实例。此测试曾复现并帮助修复中间页回收导致的播放器重建。
- 实际 ShortVideoFeed 在 320×640、840×800、600×320 和 1.8 倍字号下，相邻封面已预建，封面与播放器区域尺寸一致；普通/简洁/全屏往返和控制锁回归通过。使用测试数据与占位播放器。
- 使用真实 VideoDetailController、临时 Hive 设置验证：普通自动播放关闭时，进入短视频和切换来源都会启用播放；普通模式原偏好仍为关闭；退出短视频后的普通重置不会强制播放。
- 继承 V2.6.1 手势自定义、单/双击、媒体缓存 Range、预取取消、首条下拉刷新、海外线路及此前鸿蒙适配回归。
- SDK 26 / Flutter OH Release 构建、HAP CRC/AOT/ARM64 原生库和固定 mpv 哈希检查、官方代码签名/摘要/权限签名校验通过。

## 真机结果

已通过 `install -r` 从 V2.6.1 覆盖更新。系统包版本为 **2.6.2 / 6088**，UID、首次安装时间、appId 与 appIdentifier 均保留；未卸载或清除数据。

正常启动被系统以 **10106102** 拒绝，原因是设备锁屏且开发模式不允许自动解锁。未绕过锁屏或更改安全设置。设备上实际自动播放、连续滑动手感、首帧与帧耗时尚未验证；自动组件测试不能替代真机流畅度结论。

## 复现

```sh
flutter test --no-pub test/harmony_adapt
dart analyze --format machine
HARMONY_CODESIGN=1 bash tool/harmony.sh release
```

本机日志：`/tmp/piliplus-v262-test.log`、`/tmp/piliplus-v262-targeted.log`、`/tmp/piliplus-v262-analyze.log`、`/tmp/piliplus-v262-build.log`、`/tmp/piliplus-v262-signature.log`、`/tmp/piliplus-v262-install.log`、`/tmp/piliplus-v262-launch.log`。

[验证摘要](validation.json) · [构建元数据](../../releases/v2.6.2-rc1/PiliPlus-Harmony-V2.6.2-2.6.2-6088-signed.build.json)。设备身份与签名私钥不入库，未 push。
