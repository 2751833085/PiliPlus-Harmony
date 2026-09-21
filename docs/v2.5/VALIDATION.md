# V2.5 验证记录

应用版本：`2.5.0+6085`。源码 `cf4716e4ed6f65fc7e1a5e44fb1f114877b64374`。
[签名 HAP 归档](../../releases/v2.5.0-rc1/README.md)，SHA256 `608d93ee93227769ef13669e22552674af4a1f881ff8874af2a117bdce1071d4`。

## 自动回归

最终源码测试 **41 项通过**；Dart 分析 **0 错误、6 项原有警告**。SystemPosture 的系统握姿、去抖、折叠、后台订阅和不支持设备隔离检查通过。

SDK 26 / Flutter OH Release 签名构建成功；导出校验通过 ZIP CRC、ArkTS 字节码、Flutter AOT、ARM64 库和固定 mpv 哈希。官方 `hap-sign-tool verify-app` 的代码签名、SHA-256 摘要、权限签名全部通过。源树校验码记录在同目录 `.build.json`。

- 原 V2 的设置互斥、搜索尺寸、弹层交互、动态编辑布局、原生加载桥接、刷新停留、Hero、AI 总结轮询和折叠策略继续纳入同一测试集。
- 竖屏队列：去重、串行切换、失败重试、页面销毁丢弃回调、合集同步、互动异常后解除分页锁。
- 请求队列：旧源返回丢弃、原生初始化不并发、异常后下一次请求可执行、已离开页面无更新。
- 评论源切换：旧视频晚返回不会覆盖新视频评论。
- 实际 `ShortVideoFeed` 组件：320×640、840×800、600×320，1.8 倍字体，完整操作区布局；全屏往返播放器状态不重建。
- 分页：上下切换、失败回到当前页、账号互动时手势锁定；慢网络取流期间播放器视图不销毁。
- 布局预览使用测试数据和占位播放器；中文字库仅用于本机视觉检查，不随应用重新分发。

复现：

```sh
flutter test --no-pub test/harmony_adapt
dart analyze --format machine
node tool/test_harmony_posture.cjs
HARMONY_CODESIGN=1 bash tool/harmony.sh release
```

## 真机与限制

Mate XTS 上 **V2.5 覆盖安装成功**：系统包信息为 `2.5.0/6085`，升级前后 UID、首次安装时间、appId 和 appIdentifier 均一致。未卸载或清除应用数据；账号与缓存的具体内容尚未解锁逐项核对。用户先前确认 RC1 展开播放、方向、握姿正常；该反馈不能当作 V2.5 新增功能的实测结果。

用户休息后手机锁屏，**V2.5 正常启动请求仍被系统以 10106102 拒绝**（设备锁屏，开发模式不允许自动解锁）。没有绕过锁屏或关闭开发者模式。本版尚未完成真机运行验收，作为候选版本归档。

仍需解锁后的真实网络视频连播、单屏/双折/三折物理变化、后台/画中画、原生 LoadingProgress 视觉和性能实测。没有用真实账号点赞、关注、投币、发布动态/评论或对外分享作为自动测试；这些连接已复用原业务，但不能宣称已完成线上写操作验收。

完整 147 项原上游功能矩阵仍按各项实际验证程度记录，不因本版构建成功而自动标记全部通过。

## 本机证据索引

- `/tmp/piliplus-v25-final-build.log`：41 项回归、ArkTS / Flutter AOT、签名 HAP 构建及导出。
- `/tmp/piliplus-v25-final-analyze.log`：静态分析。
- `/tmp/piliplus-v25-signature.log`：官方验签（完整日志仅本机，包含证书公开信息）。
- `/tmp/piliplus-v25-install.log`：覆盖安装成功。
- `/tmp/piliplus-v25-launch.log`：锁屏阻止启动。
- 结构化摘要见 [validation.json](validation.json)；源树、工具链、包信息、原生库与文件哈希见 [构建元数据](../../releases/v2.5.0-rc1/PiliPlus-Harmony-V2.5-2.5.0-6085-signed.build.json)。

临时日志可能被系统清理；可入库的摘要和构建元数据保留在版本目录。没有把手机身份标识、证书私钥或账户凭据放入归档。
