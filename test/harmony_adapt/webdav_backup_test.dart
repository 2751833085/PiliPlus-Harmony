import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/pages/webdav/webdav.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

typedef _Mutation = ({
  String method,
  String path,
  String? destination,
  String? overwrite,
});

class _BackupServer {
  static const previous = '{"setting":{"showMineHistory":false},"video":{}}';
  static const basePath = '/dav/nested';
  static const directory = '/fixture';
  static const username = 'fixture-user';
  static const password = 'fixture-password';
  static final authorization =
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  static final canonical =
      '$basePath$directory/${Constants.appName}/'
      'piliplus_settings_${DeviceUtils.platformName}.json';

  _BackupServer(this.server, {required this.failPut, this.moveFailure}) {
    server.listen(_serve);
  }

  final HttpServer server;
  final bool failPut;
  final int? moveFailure;
  bool _attemptedMove = false;
  final mutations = <_Mutation>[];
  final files = {canonical: previous};

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        authorization) {
      response.headers.set(
        HttpHeaders.wwwAuthenticateHeader,
        'Basic realm="fixture"',
      );
      response.statusCode = HttpStatus.unauthorized;
    } else if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
    } else if (request.method == 'MKCOL') {
      response.statusCode = HttpStatus.created;
    } else {
      final destination = request.headers.value('destination');
      final overwrite = request.headers.value('overwrite');
      mutations.add((
        method: request.method,
        path: path,
        destination: destination == null ? null : Uri.parse(destination).path,
        overwrite: overwrite,
      ));
      switch (request.method) {
        case 'PUT':
          final payload = await utf8.decoder.bind(request).join();
          if (failPut) {
            files[path] = 'incomplete upload';
            response.statusCode = HttpStatus.insufficientStorage;
          } else {
            files[path] = payload;
            response.statusCode = HttpStatus.created;
          }
        case 'MOVE':
          if (moveFailure case final status?) {
            // Bound a regression to the old client's recursive 409 retry.
            response.statusCode = _attemptedMove ? HttpStatus.locked : status;
            _attemptedMove = true;
          } else if (destination != null &&
              overwrite == 'T' &&
              files.containsKey(path)) {
            files[Uri.parse(destination).path] = files.remove(path)!;
            response.statusCode = HttpStatus.noContent;
          } else {
            response.statusCode = HttpStatus.badRequest;
          }
        case 'DELETE':
          response.statusCode = files.remove(path) == null
              ? HttpStatus.notFound
              : HttpStatus.noContent;
        default:
          response.statusCode = HttpStatus.methodNotAllowed;
      }
    }
    await response.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;

  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('pili-webdav-backup-');
    Hive.init(sandbox.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
  });

  tearDownAll(() async {
    await Hive.close();
    await sandbox.delete(recursive: true);
  });

  Future<_BackupServer> createServer({
    bool failPut = false,
    int? moveFailure,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    await GStorage.setting.putAll({
      SettingBoxKey.webdavUri:
          'http://127.0.0.1:${server.port}${_BackupServer.basePath}/',
      SettingBoxKey.webdavUsername: _BackupServer.username,
      SettingBoxKey.webdavPassword: _BackupServer.password,
      SettingBoxKey.webdavDirectory: _BackupServer.directory,
      SettingBoxKey.showMineHistory: true,
    });
    return _BackupServer(server, failPut: failPut, moveFailure: moveFailure);
  }

  Future<void> backup() => HttpOverrides.runWithHttpOverrides(
    WebDav().backup,
    _LoopbackHttpOverrides(),
  );

  void expectStagingPath(String path) {
    expect(path, startsWith('${_BackupServer.canonical}.'));
    expect(path, endsWith('.tmp'));
  }

  test(
    'failed WebDAV upload deletes only the incomplete staged file',
    () async {
      final fixture = await createServer(failPut: true);

      await backup();

      expect(fixture.mutations.map((m) => m.method), ['PUT', 'DELETE']);
      final put = fixture.mutations.first;
      expectStagingPath(put.path);
      expect(fixture.mutations.last.path, put.path);
      expect(fixture.files, {_BackupServer.canonical: _BackupServer.previous});
    },
  );

  for (final status in [
    HttpStatus.locked,
    HttpStatus.conflict,
    HttpStatus.multiStatus,
    HttpStatus.methodNotAllowed,
  ]) {
    test(
      'WebDAV MOVE $status keeps the old canonical backup without retrying',
      () async {
        final fixture = await createServer(moveFailure: status);

        await backup();

        expect(fixture.mutations.map((m) => m.method), [
          'PUT',
          'MOVE',
          'DELETE',
        ]);
        final put = fixture.mutations.first;
        final move = fixture.mutations[1];
        expectStagingPath(put.path);
        expect(move.path, put.path);
        expect(move.destination, _BackupServer.canonical);
        expect(move.overwrite, 'T');
        expect(fixture.mutations.last.path, put.path);
        expect(fixture.files, {
          _BackupServer.canonical: _BackupServer.previous,
        });
      },
    );
  }

  test(
    'successful WebDAV backups use distinct staging paths and replace data',
    () async {
      final fixture = await createServer();
      final firstSnapshot = GStorage.exportAllSettings();

      await backup();
      expect(fixture.files, {_BackupServer.canonical: firstSnapshot});

      await GStorage.setting.put(SettingBoxKey.showMineHistory, false);
      final secondSnapshot = GStorage.exportAllSettings();
      await backup();

      expect(fixture.mutations.map((m) => m.method), [
        'PUT',
        'MOVE',
        'PUT',
        'MOVE',
      ]);
      final [firstPut, firstMove, secondPut, secondMove] = fixture.mutations;
      for (final (put, move) in [
        (firstPut, firstMove),
        (secondPut, secondMove),
      ]) {
        expectStagingPath(put.path);
        expect(move.path, put.path);
        expect(move.destination, _BackupServer.canonical);
        expect(move.overwrite, 'T');
      }
      expect(firstPut.path, isNot(secondPut.path));
      expect(fixture.files, {_BackupServer.canonical: secondSnapshot});
    },
  );
}
