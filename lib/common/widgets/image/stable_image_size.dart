import 'dart:collection';

/// Remember a bounded set of cover decode sizes across layout/reparent changes.
/// Shrinking reuses the sharper image; larger windows upgrade in coarse steps.
class StableImageSize {
  static final _widths = LinkedHashMap<String, int>();

  static int resolve(String identity, int requested, {required int limit}) {
    final previous = _widths.remove(identity) ?? 0;
    final bucket = ((requested + 255) ~/ 256 * 256).clamp(1, limit);
    final width = (previous > bucket ? previous : bucket).clamp(1, limit);
    _widths[identity] = width;
    if (_widths.length > 256) _widths.remove(_widths.keys.first);
    return width;
  }
}
