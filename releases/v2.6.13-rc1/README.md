# V2.6.13 RC1 · 2.6.13+6100

[签名 HAP](PiliPlus-Harmony-V2.6.13-2.6.13-6100-signed.hap) · [SHA256](PiliPlus-Harmony-V2.6.13-2.6.13-6100-signed.hap.sha256) · [构建元数据](PiliPlus-Harmony-V2.6.13-2.6.13-6100-signed.build.json)

应用侧握姿状态补齐双手居中：单手靠近握持侧、双手居中，未知样本保持位置。原生 Dock 继续由系统 HDS 跟手；全屏播放条保持全宽。设置说明明确这一规则。

源码 `7fc9bbd899917febd1b2854a64b9e5cf9ab77b66`；标签 `harmony-v2.6.13-rc1`。HAP 33,091,722 字节，SHA256 `50fada2f54e5abf4105c497794fa8b063a44a545bbb93896510b6c17d63aebe7`。

106 项 Flutter 回归、ArkTS 握姿事件回归、构建、CRC、原生播放器哈希和官方签名校验通过。Dart 0 错误、6 项既有警告。

已覆盖安装 2.6.13+6100，UID 与首次安装时间保留，未卸载或清理数据。手机仍锁屏，系统拒绝启动；真实双手握持、最终包白层消失与旋转锁定仍待解锁验收。自动事件与控件回归不等于物理握姿测试。

[说明](../../docs/v2.6.13/README.md) · [验证记录](../../docs/v2.6.13/VALIDATION.md)。HAP 留在本机、不入 Git，未 push。
