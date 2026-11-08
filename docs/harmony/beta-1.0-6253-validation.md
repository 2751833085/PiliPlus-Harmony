# Beta 1.0 版本命名修正（6253）

按用户卸载旧版、从 GitHub 手动安装的方式重新发布。本轮只修正版本元数据、显示和更新标签读取，不改动播放、下载、布局或交互逻辑。

- 应用内版本：`Beta 1.0 · 构建 6253`。
- 鸿蒙安装包版本：`1.0.0-beta`；版本码 `6253`。
- 发布标签：`v1.0.0-beta+6253`，发布名称 `Beta 1.0`。
- Flutter 版本：`1.0.0-beta+6253`；保留递增构建号用于追溯。
- 更新检测从完整标签读取版本，验证同版本不重复、下一 Beta 可识别、已撤安装附件的 3.0 历史发布不参与选择。

鸿蒙原生元数据通过官方 [Hvigor 构建上下文](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-build-expanding-context/) 写入。在 `nodesEvaluated` 阶段设置名称，避免 Flutter 插件后续覆盖后缀；导出时强制核对 HAP 内的版本与 pubspec 一致。首轮后缀被覆盖的候选已被该检查拒绝，未发布、未安装。

## 6253 安装包验证

- 源码：`ff68a382f506e333c58a98ffdc99173f223da505`。
- HAP：`PiliPlus-Harmony-Beta-1.0-6253-signed.hap`，33,140,187 bytes。
- SHA-256：`6f7a7b954bc3e779c70bc0a4b359c69fdcafe6bf3ec52ba8ef67e85f4067da71`。
- 完整 Dart 回归：375 项通过，1 项仅诊断构建测试跳过。
- HAP ZIP CRC、原生 libmpv 哈希、AOT 嵌入源码提交、正式配置标志及官方签名校验通过。
- 实际 HAP `versionName=1.0.0-beta`、`versionCode=6253`，与源码一致。
- GitHub 上传的四个附件与本地校验值一致。

- 专用 HarmonyOS 7 模拟器实际安装成功，系统登记 `1.0.0-beta / 6253`，关于页实读 `Beta 1.0 · 构建 6253`。应用 UID、首次安装时间保留，已回到三屏推荐首页；见[版本核验汇总](beta-1.0-6253-version-smoke.json)。
- 首次从“我的”转场后立即点击设置未进入，稳定页面后再次点击成功，本轮没有将其视为完整流畅性验证。
- [GitHub 标签流水线](https://github.com/2751833085/PiliPlus-Harmony/actions/runs/42438313826)仍在执行，最终公开下载结果另行记录。

此前 6252 的三屏态累计 30 分钟回归保留在[历史验证记录](beta-1.0-validation.md)，不冒充 6253 的独立长测。真实媒体、弱网、登录和真机性能限制继续适用。本轮不操作用户实体手机。
