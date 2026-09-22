/// Route hints choose the first layout. A missing hint can be resolved once by
/// the actual video dimensions; manual choices and subsequent feed items win.
class ShortVideoEntryPolicy {
  ShortVideoEntryPolicy({
    required this.enabled,
    required this.supported,
    required bool portraitHint,
  }) : initialMode = enabled && supported && portraitHint;
  final bool enabled, supported, initialMode;
  bool _resolved = false;
  bool? resolve(bool portrait) {
    if (_resolved) return null;
    _resolved = true;
    return enabled && supported && portrait;
  }

  void manualSelection() => _resolved = true;
}
