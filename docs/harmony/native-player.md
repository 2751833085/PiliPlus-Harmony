# 鸿蒙原生播放器构建记录

已在 macOS ARM64 上完成原生交叉编译，生成 OHOS ARM64 `libmpv.so`。
源码版本和压缩包校验值见 `tool/native_mpv/sources.json`。
`packages/media_kit_libs_ohos` 保存插件、库文件及依赖许可证。

- 构建脚本：`cnoim/libmpv-ohos-build`，固定提交 `c8d5731ba5ba7623081795db52b2578d975cb3e7`。
- FFmpeg：`12d3b88527659b03c6c72d33f58086ddfa21ae24`，应用构建仓库内的 Audio Vivid 补丁。
- mpv：`b1b1bc3aa8503d529cbae4e4dfa7d27e7d7c5333`。
- 本项目补丁：启用可用的全部 FFmpeg 滤镜和 AV3A 解码器/解析器；依赖和播放器仍按原仓库脚本编译。
- `ffmpeg-config_components.h` 记录 `CONFIG_LOUDNORM_FILTER`、`CONFIG_DYNAUDNORM_FILTER`、
  `CONFIG_AV3A_OH_DECODER` 和 `CONFIG_AV3A_PARSER` 均为 1。
- FFmpeg 禁用 GPL/nonfree、启用 version3；mpv 使用 `-Dgpl=false`。
  各组件许可独立保留，不将动态库统一声称为 MIT。
- HAP 包内库的 SHA256 必须与源工程一致；预先执行 `llvm-strip --strip-all`，
  避免打包时去除符号改变哈希。原构建输出哈希也保留在清单中。

## 重建入口

安装 Git、Python 3.12+、curl、meson、ninja、pkg-config、make、Rust 和 cargo-c。
本次使用 Rust 1.98.1、cargo-c 0.10.25+cargo-0.99.0、Meson 1.12.0、Ninja 1.13.2。
使用 SDK 26 的 OpenHarmony NDK 和同级 HMS BiSheng 编译器。
`OHOS_NDK_HOME`、构建目录均须是无空格英文路径。

```sh
rustup target add aarch64-unknown-linux-ohos
cargo install cargo-c --version '0.10.25' --locked --features=vendored-openssl
python3 tool/rebuild_harmony_mpv.py \
  --ndk /path/to/command-line-tools/sdk/default/openharmony \
  --host-sdk /Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk \
  --work-dir /tmp/piliplus-mpv-fresh --jobs 8 --install
python3 tool/rebuild_harmony_mpv.py --check
bash tool/harmony.sh release
```

`--work-dir` 必须为空，脚本拒绝覆盖已有开发目录。
`--install` 才会替换工程内的库并更新校验值；不加该参数只在指定目录编译。
本机 Xcode 链接器不能链接 macOS 27 SDK 的部分 host 工具，因此本次显式使用 14.4 host SDK；
OHOS 目标代码仍使用 SDK 26 sysroot。其他机器应选择与其 host 编译器配套的 macOS SDK。

已完成底层全部依赖的实际构建和最终库校验。整理后的 Python 入口已检查语法、
交叉编译配置及本地库校验，尚未从空目录再次跑完整构建；不同构建环境也不保证逐字节相同。

## 待真机验证

- 普通视频、番剧、直播、离线文件，H.264/HEVC/AV1 的解码和音画同步。
- loudnorm / dynaudnorm / 自定义参数切换，播放列表连续播放，倍速和后台恢复。
- 有权限播放的 Audio Vivid 源、耳机切换、杜比视界/HDR、字幕及截图。
- 折叠、双屏、三屏、旋转及画中画切换时，播放器实例、进度和字幕保持。

未将上述项目标成已通过；没有以插件限制替代系统权限例外。
