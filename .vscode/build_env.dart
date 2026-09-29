import 'dart:convert';
import 'dart:io';

// Keep release metadata consistent with the HAP's pubspec version.
Future<void> main(List<String> args) async {
  final content = await File('pubspec.yaml').readAsString();
  final version = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (version == null)
    throw StateError('pubspec.yaml needs version name+build');
  final tag = 'v${version[1]}+${version[2]}';
  if (args.isNotEmpty && args.first.isNotEmpty && args.first != tag) {
    throw StateError('Release tag ${args.first} does not match $tag');
  }
  final git = await Process.run('git', ['rev-parse', 'HEAD']);
  if (git.exitCode != 0) throw StateError('Unable to read source commit');
  final env = {
    'pili.name': '${version[1]}-ohos',
    'pili.tag': tag,
    'pili.time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'pili.hash': git.stdout.toString().trim(),
    'pili.code': int.parse(version[2]!),
    'ENABLE_FLEX_OVERFLOW': false,
  };
  await File('.vscode/env.json').writeAsString(jsonEncode(env));
}
