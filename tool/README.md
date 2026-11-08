# 开发工具

在仓库根目录运行。SDK、签名材料和缓存路径使用本机配置，不提交私密配置。

| 工具 | 用途 |
| --- | --- |
| `bash tool/harmony.sh doctor` | 检查 Flutter OH、Harmony SDK 与本机环境 |
| `bash tool/harmony.sh release` | 执行回归、隔离构建并输出 HAP；签名须配置本机材料 |
| `tool/stage_harmony.py` | 构建目录同步，由构建脚本调用 |
| `node tool/test_harmony_posture.cjs` | 原生折叠屏状态和生命周期回归 |
| `tool/check_harmony_layout.sh` | 布局相关自动检查 |
| `tool/capture_harmony_display.py` | 采集设备原生分辨率与显示证据 |
| `tool/collect_harmony_performance.py` | 采集设备运行与帧时间证据，具体参数见 `--help` |
| `tool/rebuild_harmony_mpv.py` | 重建本项目固定版本的原生播放器 |
| `tool/research/hap_inventory.py` | 检查 HAP 文件清单 |

完整 Dart 回归：`flutter test`。工具回归：`python3 -m unittest discover -s test/harmony_adapt/tooling -v`。

参见[构建说明](../docs/harmony/README.md)、[原生播放器说明](../docs/harmony/native-player.md)和[Beta 1.0 验证记录](../docs/harmony/beta-1.0-validation.md)。
