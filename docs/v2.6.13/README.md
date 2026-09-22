# V2.6.13 · 双手握持居中

智感握姿的应用侧回调新增 `BOTH_HANDS_HELD` → `center`：左手靠左，右手靠右，双手居中。保持 180ms 稳定确认；未知/未握持样本撤销尚未执行的移动，保留最近稳定位置。触控期间等待手指释放再移动，避免误触；关闭功能和进入后台时移除监听与定时器。

首页原生 HDS Dock 仍使用系统 `adaptToHandedness`，不叠加第二套定位动画。全屏播放条保持全宽，不随握持缩窄。设置中补充单手/双手规则。

系统握持枚举以本机 API 26 `@ohos.multimodalAwareness.motion.d.ts` 为准。华为[多设备适配指南](https://developer.huawei.com/consumer/cn/multidevice/adaptive-apps/)说明支持左手、右手、双手和未握持识别。回归使用实际 ArkTS 服务的模拟事件及 Flutter 桥接/控件；真实双手识别需要设备传感器验证。

保留 V2.6.12 白色遮层、旋转锁定、全宽播放栏和统一菜单修复。未 push。

[验证记录](VALIDATION.md) · [签名 HAP](../../releases/v2.6.13-rc1/README.md)。
