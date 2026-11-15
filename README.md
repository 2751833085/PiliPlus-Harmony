# PiliPlus Harmony

[PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的鸿蒙版，为手机、平板和折叠屏适配。

> [!WARNING]
> 本软件仍处于测试阶段，功能尚不稳定，可能出现卡顿、闪退或数据异常，请谨慎使用。

## 下载

当前版本 **Beta 1.1**。请在 [Releases](https://github.com/2751833085/PiliPlus-Harmony/releases) 下载签名 HAP 手动安装，[版本说明](docs/releases/beta-1.1/notes.md)。

遇到问题请提交 [Issues](https://github.com/2751833085/PiliPlus-Harmony/issues)。

## 构建

```sh
bash tool/harmony.sh doctor
bash tool/harmony.sh release
```

需要 Flutter OH `3.44.9+ohos-0.0.1-canary1` 和 HarmonyOS SDK 26，详见[构建说明](docs/harmony/README.md)。

## 致谢与许可

业务代码来自 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，鸿蒙基础适配来自 [dev4harmony/PiliPlus](https://github.com/dev4harmony/PiliPlus/tree/ohos)，播放器适配感谢 [ErBWs](https://github.com/ErBWs)。

本项目以 [GPL-3.0](LICENSE) 发布。
