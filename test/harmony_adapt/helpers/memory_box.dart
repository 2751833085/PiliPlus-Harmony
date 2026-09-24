import 'dart:async';
import 'package:hive_ce/hive.dart';

class MemoryBox<T> implements Box<T> {
  final _events = StreamController<BoxEvent>.broadcast(sync: true);
  @override
  Stream<BoxEvent> watch({dynamic key}) =>
      _events.stream.where((event) => key == null || event.key == key);

  final _values = <dynamic, T>{};
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, T value) async {
    _values[key] = value;
    _events.add(BoxEvent(key, value, false));
  }

  @override
  Future<void> delete(dynamic key) async {
    _values.remove(key);
    _events.add(BoxEvent(key, null, true));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
