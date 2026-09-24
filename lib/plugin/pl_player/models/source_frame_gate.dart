import 'package:flutter/foundation.dart';

/// A decoder-ready signal belongs to one media load, never to the reused player.
class SourceFrameGate extends ChangeNotifier {
  int _generation = 0;
  String? _source;
  bool _ready = true;
  bool get ready => _ready;
  bool isCurrent(int generation) => generation == _generation;

  int begin(String source) {
    invalidate();
    _source = source;
    return _generation;
  }

  void invalidate() {
    _generation++;
    _source = null;
    if (_ready) {
      _ready = false;
      notifyListeners();
    }
  }

  bool accept(int generation, {required String source, required String pts}) {
    final timestamp = double.tryParse(pts);
    if (!isCurrent(generation) ||
        _ready ||
        _source == null ||
        source != _source ||
        timestamp == null ||
        !timestamp.isFinite ||
        timestamp < 0) {
      return false;
    }
    _ready = true;
    notifyListeners();
    return true;
  }
}
