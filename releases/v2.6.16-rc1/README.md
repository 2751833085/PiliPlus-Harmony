# V2.6.16 RC1 · 2.6.16+6103

本地 HAP：`PiliPlus-Harmony-V2.6.16-2.6.16-6103-signed.hap` · [SHA256](PiliPlus-Harmony-V2.6.16-2.6.16-6103-signed.hap.sha256) · [构建元数据](PiliPlus-Harmony-V2.6.16-2.6.16-6103-signed.build.json)

减少短视频缓冲预取造成的整页重建，修复鸿蒙文件缓存目录和浅色主题下的短视频评论对比度。

源码 `fadef1cda3bb4e858b6798683c18064cac14b6e7`。HAP 33,099,834 字节，SHA256 `8dbe857ed94bacd77e3d57c33839a0669797e3f9946627f83f7a7b21deac2ce4`。

125 项完整 Flutter 回归通过，Dart 0 错误、6 项既有警告；原生握姿/折叠回归、Release 构建、完整性和官方签名校验通过。

已在 DevEco 官方三折屏模拟器实际运行游客界面与操作，最终 Release 包已安装并成功启动。播放器依赖不支持模拟器视频输出，真机解码与流畅度尚未完成验收，不能据此认定全部功能正常。

Mate XTS 已覆盖升级到本版，UID 和首次安装时间保留，手机数据未清理；手机锁屏使应用启动被系统拒绝（10106102），尚未完成真机运行验收。

[说明](../../docs/v2.6.16/README.md) · [验证记录](../../docs/v2.6.16/VALIDATION.md)。未 push，HAP 仅本机归档、不入 Git。
