# V2.6 验证记录

应用版本 `2.6.0+6086`，源码 `5073838c4482f4f1e3e1ede2c4f53d882be42cd3`。
[签名 HAP 归档](../../releases/v2.6.0-rc1/README.md)，SHA256 `72111966a6dcf1d94b3e2aa8ef17c431cf8f93ea0bdb6db924b100bfd987e01f`。

## 已完成

- **51 项 Flutter 回归通过**，包括继承的 41 项 V2/V2.5 测试。Dart 分析 **0 错误、6 项原有警告**。
- 首条下拉刷新替换整个队列并更换首视频；过滤重复及当前视频、推荐失败/空列表保留当前条目、旧加载响应丢弃、刷新中禁止并发切换。
- 390×844 与 900×640 手势：使用播放器同款单击、双击、长按及新增横向拖动识别器，横向调进度不翻页，向上下一条、向下上一条，首条下拉刷新，控制锁阻止翻页/刷新。
- 实际 ShortVideoFeed：320×640、840×800、600×320，1.8 倍字，普通/全屏往返和全屏翻页保留同一播放器状态；控制锁时隐藏评论入口。预览使用测试数据、占位播放器及本机字体，不随 HAP 分发字体。
- 海外线路策略：允许域名和可改写路径、保留 URL 签名、最快可用响应胜出、取消落选请求、截止超时、原地址回退、失效域名暂避/过期、清除缓存时取消请求。
- 本地 HTTP 实际 Range 请求：有效媒体通过，403、HTML 与重定向拒绝；请求 16 KiB，取消响应读取。没有向线上帐号发测试写请求。
- 画质：已含目标画质可延后补齐，缺失目标画质仍等待，不以降低画质冒充提速。
- SystemPosture 原生隔离检查通过：握姿开关、去抖、折叠、后台订阅和不支持设备。
- SDK 26 / Flutter OH Release 签名构建通过；HAP CRC、ArkTS/Flutter AOT、ARM64 库及固定 mpv 哈希校验通过；官方代码签名、摘要和权限签名均通过。

## 真机结果与限制

Mate XTS 覆盖安装成功，系统包版本为 **2.6.0 / 6086**；UID、首次安装时间、appId 和 appIdentifier 与 V2.5 相同。未卸载或清除数据。

正常启动仍被系统拒绝：**10106102，设备锁屏且开发模式不允许自动解锁**。没有绕过锁屏或更改开发者模式。V2.6 真机播放、物理折叠、网络换线路时的播放连续性、首帧/吞吐/卡顿和功耗尚未实测；组件与本地 HTTP 测试不能替代这些结论。

用户表示暂时没有测试时间，所以没有再次索取解锁或物理折叠操作。HAP 已准备好并安装，但本版仍是候选版。上游 147 项功能矩阵和账号写操作也不因构建成功而标记全部通过。

## 证据与复现

```sh
flutter test --no-pub test/harmony_adapt
dart analyze --format machine
node tool/test_harmony_posture.cjs
HARMONY_CODESIGN=1 bash tool/harmony.sh release
```

本机日志：`/tmp/piliplus-v26-build.log`、`/tmp/piliplus-v26-final-analyze.log`、`/tmp/piliplus-v26-signature.log`、`/tmp/piliplus-v26-install.log`、`/tmp/piliplus-v26-launch.log`、`/tmp/piliplus-v26-layout.log`。组件预览为 `/tmp/piliplus-v26-layout-320.png`、`-840.png`、`-600.png`。

可入库的摘要见 [validation.json](validation.json)，完整可复现工具链/源树/原生库哈希见 [构建元数据](../../releases/v2.6.0-rc1/PiliPlus-Harmony-V2.6-2.6.0-6086-signed.build.json)。临时日志可能被系统清理；私钥、签名配置和设备身份信息不入库。未 push。
