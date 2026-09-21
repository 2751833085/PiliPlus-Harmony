# PiliPlus HarmonyOS native media dependency

This is the OHOS plugin from `cnoim/media-kit` at the commit recorded in
`../../tool/native_mpv/sources.json`, with a locally rebuilt ARM64 `libmpv.so`.
The plugin code retains its original MIT license; linked native components retain
their own licenses in `third_party_licenses/` (including LGPL libraries).

The old downloadable build disabled the FFmpeg audio normalization filters and
Audio Vivid decoder. This build enables all available FFmpeg filters, including
`loudnorm` and `dynaudnorm`, plus the OHOS AV3A decoder/parser. Hardware decoding,
WebP screenshot encoding, ASS subtitles, Lua, Vulkan and OHOS audio remain enabled.
AV3A playback still depends on device decoder support and an authorized source.
Compilation alone does not prove playback quality or runtime feature parity.

The library is pre-stripped with SDK 26 `llvm-strip --strip-all`, matching HAP
packaging. CMake and `tool/harmony.sh` validate SHA256 before exporting the HAP.
No library is downloaded or silently substituted during app builds.

## Rebuilding

See `../../docs/harmony/native-player.md`. Exact dependency commits, source
archive checksums, FFmpeg build configuration and the build patch are retained in
`../../tool/native_mpv/`. The HAP build uses this plugin through a local dependency
override. A fresh native build is separate from the ordinary HAP build.

`NOTICES` is generated from the preserved component licenses by
`tool/native_mpv/update_notices.py`; Flutter includes these notices in the HAP.
