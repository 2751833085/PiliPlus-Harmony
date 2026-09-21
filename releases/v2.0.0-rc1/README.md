# V2 RC1 · 鸿蒙体验候选版

- 应用版本：`2.2.0+6083`，包名 `com.example.piliplus`。
- 源码提交：`faf1f06526cbebfdb08d9ec30922ea412b63252e`，分支 `harmony/v2-native-ui`。
- 构建：ARM64 Release，SDK 26，最低 API 22；已使用本机 DevEco 开发签名。
- 安装包：[PiliPlus-Harmony-V2-2.2.0-6083-signed.hap](PiliPlus-Harmony-V2-2.2.0-6083-signed.hap)，32,934,799 字节。
- SHA256：`44c7688aad985c1763136f7ae9ba58d3827bf732c1c0fa00756fbf0a6a56331e`。
- [构建元数据](build.json) · [校验文件](SHA256SUMS) · [详细验证记录](../../docs/v2/VALIDATION.md)。

包含可选鸿蒙 UI、三屏 Dock、提示避让、封面过渡、智感握姿、折叠全屏方向和已有位置的星球加载动画。
AI 总结支持有限轮询、取消及准确区分无内容和服务错误。

19 项 Flutter 回归和原生握姿/折叠服务检查通过，Dart 分析 0 错误。
官方签名校验通过；Mate XTS / HarmonyOS 7.0.0.107 SP8 覆盖安装和启动成功。
未卸载旧应用，原应用 UID、首次安装时间和应用标识保持，登录界面仍可见。

物理折叠、左右手握姿、登录账号 AI 总结、长时间性能和完整业务清单尚未全部验收，故标为 RC1。
本包用于开发设备测试，适用于描述文件包含的设备；不是应用市场分发签名。
HAP 保留本机并被 Git 忽略，私钥、证书、描述文件、签名密码不进入版本库。
V1 在独立目录与 `harmony-v1.0.0` 标签中保留。
