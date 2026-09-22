import 'package:hive_ce/hive.dart';

class MemoryBox<T> implements Box<T> {
  final _values = <dynamic, T>{};
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, T value) async {
    _values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
