# 开发约定

1. `main` 保留原 PiliPlus 对照来源；`harmony/mate-xts` 保存 V1；V2 在 `harmony/v2-native-ui` 开发。
2. 不移动 Flutter / ArkTS 工具依赖的标准目录。共享界面能力放入 `lib/harmony_adapt/`，系统能力放入 `ohos/entry/src/main/ets/plugins/`。
3. V2 鸿蒙风格必须可以关闭，不重置账号、播放器、下载记录及用户既有设置。
4. 桥接字段要同时更新 Dart 与 ArkTS。新系统能力需有版本判断、失败回退、监听释放。
5. 折叠切换按窗口尺寸响应；不得重建播放器、首页数据控制器或丢失滚动位置来换取布局变化。
6. 每项改动应有适合风险的验证：布局/动画测试、静态检查、HAP 编译；涉及系统行为的项目另做真机验证。
7. 构建通过不等于功能验收通过。测试记录须区分自动模拟、真机观察与未验证。
8. 使用 `bash tool/harmony.sh release`；签名配置放在被忽略的 `ohos/build-profile.local.json5`。
9. `releases/` 的 HAP 不入库；保留版本说明、哈希、构建信息。发布前核对来源与许可证。

提交信息描述实际改动。不要把账号、签名文件、设备唯一标识或临时日志提交到仓库。
