# V2.6.9 · 短视频字体与控件比例

将短视频信息层与底部操作栏放入同一套尺寸规则，解决「发弹幕」继承全局按钮字号、内边距，而其他文字分别指定尺寸造成的比例差异。正文、搜索推荐、关注、输入入口和时间采用 14sp 基准；辅助信息与数量采用 12sp。信息行使用一致行高与 16dp 左侧对齐线，图标按同一规则缩放。

发弹幕、关注和评论输入使用相同胶囊控件：标准字号下可见高度 32dp，实际点击高度 44dp；发弹幕最大宽度 200dp，旁边继续保留独立的弹幕开关、设置、详情和全屏。用户放大文字后，容器按实际文字比例增高，文字没有被全局钳制或缩小。图标适度增长，避免挤占输入区。

进度条保持细线外观，点击和拖动区域为 28dp 高。修正进度条渲染器在较高约束中仍靠顶绘制的问题，使轨道和滑块始终居中，拖动时滑块变大也不改变轨道位置。未设置额外高度的普通进度条仍按自然高度布局。

播放、暂停、拖动沿用同一个播放器，底部区域不因信息显隐而改变视频矩形。发送、弹幕设置、关注、评论及搜索继续使用原有操作，不新增账号写入或网络请求。包含 V2.6.8 及此前功能。

## 等比例组件预览

下列图片使用实际短视频组件、测试画面和样例数据，使用 STHeiti 字体与应用图标；模拟顶部 32dp / 底部 24dp 安全区。视频画面保持 3:4、9:16、16:9 比例，没有将截图拉伸来制造适配效果。这不是 Mate XTS 的实机截图或真实解码性能测试。

[手机标准字号](previews/phone-9x16.png) · [3:4 暂停](previews/phone-paused-3x4.png) · [16:9 手动短视频模式](previews/phone-manual-16x9.png)

[1.3 倍字号](previews/phone-text-1.3.png) · [2 倍字号](previews/phone-text-2.0.png) · [展开屏标准字号](previews/expanded-9x16.png) · [评论输入](previews/phone-comments.png)

大字号下长作者名、标题及搜索词允许省略显示，搜索传参仍完整；低高度窗口继续允许滚动信息区。自动测试还覆盖 320dp 窄屏与 600×320 低高度窗口。

[验证记录](VALIDATION.md) · [签名 HAP](../../releases/v2.6.9-rc1/README.md)。

## 原生分辨率与密度核对（进行中）

用户指出此前逻辑尺寸预览不能替代 Mate XTs 的实际比例后，加入实测显示配置。三屏已通过设备 DisplayManagerService 采集：3184×2232 像素，显示密度 2.875（逻辑密度 460dpi），约 1107.48×776.35 逻辑像素；物理屏幕 PPI 约 383，与布局使用的显示密度含义不同。

[实测配置](../../test/harmony_adapt/fixtures/mate_xts_display/triple.json)保留来源、采集时间与折叠状态，不含设备 ID。`tool/capture_harmony_display.py` 按当前状态采集，若分辨率与指定形态不符会拒绝写入。[华为官方规格](https://consumer.huawei.com/cn/phones/mate-xts-ultimate-design/specs/)列明单屏 1008×2232、双屏 2048×2232、三屏 3184×2232；单屏、双屏的系统密度仍需逐一实测，不能仅由分辨率推断。

原生测试同时设置 Flutter view 的 physicalSize、devicePixelRatio，并从 view 构建 MediaQuery。应用界面缩放额外乘入有效 DPR；导出时使用该 DPR 直接栅格化并校验 PNG 像素尺寸，没有放大低分辨率截图。三屏另覆盖 1.3 倍文字和 1.15 倍界面缩放。使用从该设备临时读取的 HarmonyOS Sans / Sans SC 测试，字体仅本地保存，不打包或入库。

[三屏 3184×2232 组件预览](previews/native-triple.png) · [三屏暂停](previews/native-triple-paused.png) · [三屏评论](previews/native-triple-comments.png)。这些仍是测试画面；安全区暂用测试值，实际应用字体选择、窗口安全区与缩放须解锁后通过本机验证。此前 390/840dp 图片只保留为通用边界压力测试，不能称作 Mate XTs 实机适配验收。

测试构建可启用 `HARMONY_LAYOUT_DIAGNOSTICS=1`，短视频页仅在窗口参数变化时输出 `PiliPlusDisplayMetrics`：引擎物理尺寸与 DPR、有效 DPR、应用缩放、字号、安全区和布局尺寸，不含账户或视频信息。常规构建默认关闭。该开关也写入构建元数据，以便区分诊断候选包。
