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

## 6246 本轮实际记录（2026-10-27）

- 使用官方 HarmonyOS 7.0.0.107/API 26.0.0 TripleFold，DPR 2.875、默认 UI 缩放；三屏 3184×2232、双屏 2048×2232、单屏 1008×2232 均通过 DisplayManagerService 实读确认。
- 隔离游客测试包启用布局/性能诊断，生产包必须全部关闭。没有退出、复制或改动真实手机账号。
- 修前源码 fbb7f2e235400c095daf3e96afeb6bc2233ac35c 的连续导航完成 7 轮，第 8 轮点“热门”误开底下视频而停止；手动复现第二次。不是 30 轮通过。
- 原因核对 SDK 本地定义：原生顶栏宿主的 Transparent 命中允许兄弟 FlutterPage 同收输入，滚动留白不能拦住已滚到顶栏下的卡片。修复源码 9f984508e 改用有界 Default/停止冒泡，覆盖时排除子控件；Flutter 加不占布局空间的固定吸收区。
- 同时修复视频卡片 CID 查询晚到后仍跳转：重复点击合并，原卡片、路由、根页面和本地页签失效后不导航。6 项异步导航及 3 项卡片布局测试通过。
- 313 项 Harmony 测试通过、1 项仅诊断启用的性能协议测试另行通过；12 项 Python 工具测试通过。静态分析没有新增错误/警告，现有样式信息不作为崩溃。
- 实际已检查：深浅色设置、主题就近菜单及空白取消；三种尺寸的游客“我的”、底栏安全区；离线缓存空页进入/返回；动态、观看记录、稍后再看的登录提示。未登录数据页的提示通过不等于账号内容功能通过。
- 修前 20 分钟采集记录 94 个完整批次、6723 帧，场景边界排除 40 帧，保留 6683 帧。导航滚动场景 6468 帧，build p95 1.706ms、raster p95 23.492ms。该场景混有导航和意外打开的视频，不能作为纯首页滚动基准，也不能据此算实际掉帧率。
- 捕获时匹配到 4 次依赖的模拟器纹理输出不支持，其余四类已知异常匹配为 0；这只是指定 PID/时间窗口的关键词覆盖。原生图像方向属性 401 等日志未被当成“无异常”。
- 重建测试包后的模拟器整体退出过一次，HDC 一起离线；模拟器日志记录退出和心跳停止，现有证据不能归因于应用。已冷启动恢复，用鸿蒙 7 配套 HDC 重连后重新开始修后测试；中断不算通过。
- 修前完整脱敏数字保存在 [6246-first-round.json](qa/6246-first-round.json)。原始截图、应用日志和系统跟踪只留本机临时目录，不公开。

### 绘制链路短时跟踪

修后另录制约 10.044 秒 graphic/ace/animation/app/window 系统跟踪，操作混合了导航、滚动与页面切换。分析参考[华为性能 FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-performance-53)的分阶段排查方式，不用单一 Flutter 耗时推算实际呈现帧率。

- 256 个成对 Flutter raster 片段，Draw p50/p95 为 16.547/44.116ms。
- SwapBuffers 累计 3.001 秒，Paint 累计 1.887 秒；Submit 等包含嵌套阶段，不能重复相加。长壁钟集中在绘制/提交链，不能直接说 CPU/GPU 持续忙。
- 同段 UI begin/draw 回调 p95 约 4.456/4.224ms，原生 ArkUI 布局和重建标记通常更短。
- 观察到原生模糊调用，但同步标记不等于完整 GPU 材质成本；未做同动作 A/B，不把模糊判为唯一原因。没有足够的图片解码/上传标记，不据此继续降低封面清晰度。
- PresentFence 等待缺少与每个 Flutter 帧的一一对应，实际 FPS 和实际掉帧率仍为未知。详见 [6246-graphics-trace.json](qa/6246-graphics-trace.json)。

### 顶栏修后实际回归

9f984508e 在三屏完成 20 轮、双屏 10 轮、单屏 10 轮：363 次动作、203 次校验全部通过，三个脚本运行时长合计 891.436 秒。未重现顶栏点击打开底下视频；这是具体路径通过，不代表所有业务无 bug。

第二段采集正常到达 1200.006763 秒上限，304 个完整批次、22278 原始帧，边界排除 161 帧后保留 22117 帧。其间单屏/双屏/三屏与系统跟踪的动作不同，不能当作严格性能 A/B。仍有绘制尖峰，不能宣称零卡顿；详见 [6246-header-fixed.json](qa/6246-header-fixed.json)。

人工补查：封面菜单打开后点背景“热门”位置只关闭菜单，底下推荐页未切换；搜索发现关键词能打开真实结果；单屏三次点击播放后约 120ms 返回均回到首页、同一应用 PID 存活。模拟器音画输出仍不支持，这三次只验导航不验解码。

搜索时首次出现独立的小艺输入法服务协议，已选择取消并退出该输入法设置，未替用户同意。随后搜索页与发现词结果正常；键盘实际打字未计入通过。

第二段日志中唯一 MissingPluginException 已从官方模拟器自动日志归档定位：旧加载视图的 setOpacity 通道关闭后仍有透明度请求；由 NativeLoadingOpacity.onError 捕获打印，非未处理异常。完整运行栈未保留，具体重建时间窗依据源码推断。证据见 [6246-loading-warning.json](qa/6246-loading-warning.json)。这一条保留为修复前的真实记录，不将其改写成 0；其后的视图代次修复和最终包短测另记。

### 加载视图代次修复

为已捕获的旧 setOpacity 通道回调增加代次隔离、明确失效和旧回调拒绝。旧视图尚未完成的调用不再阻塞新视图，当前有效通道的真实错误仍保留诊断；保持 220ms 入场和最终透明度 0。另验非鸿蒙回退在入场中更新 opacity 后仍按原节奏完成，防止共用组件回归。

6 项针对性测试通过，随后完整 Harmony 测试重新运行：317 项通过，另 1 项仅诊断开关测试此前已单独通过；Python 工具 12 项通过。40 轮完整导航属于此前顶栏修复源码；最终生产包将在本修复后另做短测，避免将前一份二进制的结果冒记到最后包上。

### 最终生产二进制短测

发布源码 c1cff0dd6a21726098bfaecf3ee5faa7e55df0f1，HAP SHA-256 为 450a72ddd6d1f8d22d30ce3a7268a1cd4f4ae0b75a3876dbc0e9b6fb8a1d4c3a。签名摘要、包 CRC、版本 6246、原生 MPV 哈希校验通过；游客隔离、布局诊断、性能采集开关均关闭。

相同 HAP 在模拟器原生单屏再运行 5 轮，46 次动作、26 次校验通过，97.583 秒内同 PID 保持存活；该 PID 日志中旧加载透明度警告、MissingPluginException、Unhandled Exception、RenderFlex、ErrorWidget 和 QA 计时标记均未匹配到。仅是该窗口的有限检查，不扩大成所有平台、所有功能或所有时间均无异常。详见 [6246-production-smoke.json](qa/6246-production-smoke.json)。

当前模拟器依赖仍不能验收视频纹理与音频输出，真实弱网同步和手机实际帧率仍需后续验证；此轮没有主动操作真实手机界面。

手机覆盖安装验证：6245 → 6246，原 UID 和首次安装时间不变；仅发布与安装，没有主动操作手机界面。脱敏结果见 [6246-device-install.json](qa/6246-device-install.json)。不能把成功安装当成真实音画/帧率全部通过。

发布后读取 GitHub 真实 releases 列表，用应用的 release_version.dart 选择器执行校验：最新为6246，6245应升级、6246不重复提示；选中HAP的远端大小与SHA-256和已装机包一致。见 [6246-update-check.json](qa/6246-update-check.json)。
