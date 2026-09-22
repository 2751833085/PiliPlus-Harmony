import 'dart:io';
import 'package:path/path.dart' as path;

/// libmpv's desktop cache default is not writable in an application sandbox.
/// Use Harmony's temporary directory, retaining mpv's automatic file cleanup.
Future<Map<String, String>> harmonyPlayerCacheOptions(
  String temporaryPath,
) async {
  try {
    final cache = await Directory(
      path.join(temporaryPath, 'mpv-packets'),
    ).create(recursive: true);
    return {'demuxer-cache-dir': cache.path};
  } on FileSystemException {
    // Storage failure must not prevent playback; existing byte limits still
    // bound the memory cache when disk buffering is unavailable.
    return {'cache-on-disk': 'no'};
  }
}
