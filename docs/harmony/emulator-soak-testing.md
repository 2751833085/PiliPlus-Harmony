# 鸿蒙模拟器长时验证与性能采集

此流程用于真实启动的 DevEco 官方模拟器，不通过缩放截图假装切换屏幕形态。它不保证所有功能无 bug，也不把模拟器速度作为 Mate XTS 的实际呈现帧率。

## 当前播放边界

`pubspec.lock` 锁定的 `media_kit_video 2.0.1`（`762fdc6368fb95ad61ab2d99a9cf70a59a00c2e3`）在 `OhosVideoController.create` 调用 `Utils.IsEmulator` 后，若原生 `deviceInfo.productModel == 'emulator'`，会在创建纹理前抛出不支持模拟器的异常。这个检查先于 `hwdec` 和 `vo` 配置，所以关闭硬件解码并不能启用这条路径。

该依赖原生实现只有 `TextureRegistry.registerTexture → SurfaceTextureEntry.getSurfaceId → MPV gpu-next` 输出路径，没有模拟器专用软件帧回退。以上证明当前依赖主动不支持，不证明新 SDK 的底层接口永远不可能支持。未修改依赖、设备身份或许可证检查。若记录到进度推进但无纹理/画面，需将解码验收标成受阻，不能标成播放正常。

本轮新增前的 89 个测试源文件以控件和状态单元回归为主，未发现真实 HDC 下载全流程或集成测试。播放器请求队列和音频恢复策略测试不能替代原生解码、真实断点下载与弱网音画同步测试。

## 测试包和显示参数

仅在用户已接受相关 DevEco/系统许可后启动模拟器。使用新建或专用 QA 模拟器；不要为了游客测试退出真实手机账号。

诊断包显式开启：

```sh
HARMONY_CODESIGN=1 HARMONY_QA_PERFORMANCE=1 HARMONY_LAYOUT_DIAGNOSTICS=1 HARMONY_QA_GUEST=1 bash tool/harmony.sh release
```

`tool/harmony.sh` 会把性能开关写入 Dart defines 和构建元数据。该开关不会在普通生产包中启用计时回调、周期输出或原始样本日志。首次安装、版本与签名、UID、模拟器系统版本应单独记录。普通签名包与 QA 包不能混淆。

每次官方折叠控件切换后，用仓库工具读取真实分辨率：

```sh
python3 tool/capture_harmony_display.py --hdc /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc --target EMULATOR_TARGET --source emulator --form triple --output /tmp/pili-qa/triple.json
```

既有 TripleFold 参考为单屏 1008×2232、双屏 2048×2232、三屏 3184×2232，DPR 2.875。以当前系统读取值为准；旋转允许交换坐标轴。字体比例和应用内缩放另记，不从显示密度推断。

## 有边界的只读采集

工具不会登录、发送消息、清空系统日志、修改网络、旋转设备或注入手势，只读取指定目标上该应用 PID 的日志。应用必须已经运行，且构建启用了性能开关。

```sh
python3 tool/collect_harmony_performance.py capture \
  --hdc /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  --target EMULATOR_TARGET --scene home-scroll \
  --duration 600 --max-batches 400 \
  --markers /tmp/pili-qa/scenes.jsonl --output /tmp/pili-qa/scroll.json
```

开始其他场景前，在另一终端写本地标记：

```sh
python3 tool/collect_harmony_performance.py mark --markers /tmp/pili-qa/scenes.jsonl --scene video-tabs
```

默认最多运行 60 秒、500 个完整批次；可设 1–3600 秒、1–10000 批次，任一边界达到便停止本地 HDC 日志客户端。按 Ctrl+C（SIGINT）会正常保存当前报告，标记 `stop_reason=operator_stop`，仅停止该次采集创建的 HDC 日志客户端，不结束应用或其他采集。样本 JSONL 逐行缓冲，采集运行时即可读取，不调用 fsync。原始应用日志不落盘；只保存白名单计时 JSON、场景标记、样本量及已知异常类别计数。采集使用阻塞跟随的 `hilog -v epoch -P PID`（不使用会立即退出的 `-x`），并用同设备 `date +%s` 对齐来排除先前日志；与本地时区或 12/24 小时显示无关。每次场景变更后的首个批次保守丢弃，避免 120 帧统计跨越场景边界。

报告中的 `build_p50_ms`、`build_p95_ms`、`raster_p50_ms`、`raster_p95_ms` 在原始样本完整时精确聚合。数据每批最多 120 帧、每行最多 20 对样本，含 `run_id / batch_id / start`，缺片或重片不会被默认为完整。5 秒周期会输出未满 120 帧的短场景尾帧。若仅存在旧格式的批次摘要，工具保留逐批数字，但将整个场景的百分位设为 `null`，绝不平均百分位冒充真实场景统计。

安全事件文件可离线重算：

```sh
python3 tool/collect_harmony_performance.py analyze --input /tmp/pili-qa/scroll.samples.jsonl --output /tmp/pili-qa/reanalyzed.json
```

报告没有完整批次或原始样本时，不算性能通过；先核对诊断开关、目标 PID、日志完整性与是否实际产生了帧。

这些是 Flutter 构建/绘制耗时，不是实际呈现 FPS、输入响应延迟或功耗。模拟器还受宿主机负载影响。实际掉帧需要 DevEco Profiler 的 Frame/RenderService/PresentFence 时间线配合；本机已安装 `ohos-profiler` 和 `ohos-trace` 插件。若使用命令行系统跟踪，先在当前系统查询 `hitrace -h`、`hidumper -ls` 和所选服务帮助，不假定所有模拟器都有相同参数。不要只用显示器报告的 60/90/120 Hz 换算成“零掉帧”。

## 建议 45–60 分钟矩阵

每一项记录系统/应用版本、实际尺寸、主题、UI 字体比例、初始状态、循环次数、完成/失败/受阻、截图及计时报告。只要出现崩溃、布局溢出、返回无响应、错误覆盖页面或功能不工作，就停止该场景、保存证据、修复后重测，不能用持续乱点代替验收。

| 场景 | 时长或次数上限 | 游客可验证内容 | 边界 |
| --- | --- | --- | --- |
| 冷启动、前后台与基础导航 | 5 分钟，10 次启动/恢复 | 仅一个初始 loading；首页/动态/我的；数据与底栏安全区 | 未登录动态可为登录提示，不算内容验收 |
| 首页及热门/分区 | 10 分钟，100 次页签往返、30 次刷新、200 次上下滑动 | 首屏与分页、刷新阈值、到底内容可见、长按封面/菜单取消、导航无穿透 | 缺少数据或限流应记录，不能记“全部正常” |
| 播放页与快速返回 | 10 分钟，50 次进入→快速点击播放→返回，100 次相关/评论往返 | 加载期间返回仍可用；右栏/评论详情/AI 面板只关闭自身；合集中重复展开不叠层 | 当前依赖的模拟器视频输出被禁用，实际解码与声音可能受阻 |
| 设置、主题与窗口 | 10 分钟，每种形态深浅色各一次，默认与大字号 | 设置搜索、开关保存与恢复、禁用原因、窗口旋转/折叠后的裁切/按钮触达 | 模拟折叠不能验收物理挖孔、握姿或真机传感器 |
| 搜索及公开用户页 | 5 分钟，30 次进入/退出，5 个查询 | 键盘开关、历史/热搜/发现、结果/用户页、菜单就近弹出 | 不发送私信或执行关注/投币/发评论等账号写入 |
| 下载与离线缓存 | 10 分钟，至多 3 个小型公开可下载条目 | 进入/退出、权限与错误；若服务允许游客下载，再验暂停/恢复/取消/重启后列表、文件大小和可播放性 | 无账号权限或解码不支持要写受阻；空离线页通过不等于下载功能通过 |
| 收尾稳定性 | 5 分钟，恢复初始设置 | 页面仍可响应、错误类日志、同场景重复计时、资源是否持续增长 | 未测量内存/功耗时不能宣称没有泄漏或最强性能 |

## 本地工具回归

```sh
python3 -B -m unittest discover -s test/harmony_adapt/tooling -p 'test_*.py' -v
flutter test --no-pub --dart-define=HARMONY_QA_PERFORMANCE=true test/harmony_adapt/performance_probe_test.dart
bash -n tool/harmony.sh
```

Python 测试覆盖真实协议格式的分片重排、缺片、重复、旧摘要、场景边界、隐私字段排除与超时停止。Dart 测试通过实际 `PlatformDispatcher.onReportTimings` 回调验证 120 帧上限、20 项分片和不足 120 帧的尾部输出；它注入合成时间戳，不声称是设备性能实测。
