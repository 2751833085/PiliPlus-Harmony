# 开发约定

1. 当前开发分支为 `harmony/v2.6-video-experience`，原 PiliPlus 通过 `upstream/main` 对照。
2. 不移动 Flutter / ArkTS 依赖的标准目录。共享界面能力放在 `lib/harmony_adapt/`，系统能力放在 `ohos/entry/src/main/ets/plugins/`。
3. 鸿蒙风格必须可关闭，且不重置账号、播放器、下载记录和用户设置。
4. 桥接字段同时更新 Dart 与 ArkTS。新系统能力需要版本判断、失败回退和监听释放。
5. 折叠切换按窗口尺寸响应，不得为了布局变化重建播放器、首页控制器或丢失滚动位置。
6. 每项改动按风险验证：布局/动画测试、静态检查、HAP 编译；涉及系统行为的另做真机验证。
7. 构建通过不等于功能验收通过。验证记录须区分自动测试、模拟器、真机与未验证。
8. 使用 `bash tool/harmony.sh release` 构建；签名配置放在被忽略的 `ohos/build-profile.local.json5`。
9. HAP 不入库，`docs/releases/` 只保留版本说明、哈希和构建信息。发布前核对来源与许可证。

提交信息应描述实际改动。不要提交账号、签名文件、设备标识或临时日志。
