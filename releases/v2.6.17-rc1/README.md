# V2.6.17 RC1 · 2.6.17+6104

[签名 HAP](PiliPlus-Harmony-V2.6.17-2.6.17-6104-signed.hap) · [SHA256](PiliPlus-Harmony-V2.6.17-2.6.17-6104-signed.hap.sha256) · [构建信息](PiliPlus-Harmony-V2.6.17-2.6.17-6104-signed.build.json)

修复原生显隐调用的异步错误处理，以及短视频预取失败后已发出的缓存地址返回 404；复用不可变队列快照，减少重复分配。原有大结构不变。

源码 `6ba89a4755c1783a26f2f001a7e2d26d6bd3b120`。HAP 33,099,833 字节，SHA256 `d054bfbd3fcaa47024a2f199413a6cb769a87d500ec64ccbdad9fca6271c3503`。

132 项完整 Flutter 回归通过，静态检查 0 错误、6 项既有警告；原生握姿/折叠回归、HAP 完整性与官方签名校验通过。最终包已在 DevEco 模拟器启动，真实视频播放仍待真机，详见 [验证记录](../../docs/v2.6.17/VALIDATION.md)。

本地候选包，未 push；HAP 不入 Git，手机应用未在本轮覆盖升级。
