import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/accounts/account_manager/account_mgr.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _CookieResponseAdapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requested.complete();
    return response.future;
  }

  void respond() => response.complete(
    ResponseBody.fromString(
      'ok',
      HttpStatus.ok,
      headers: {
        HttpHeaders.setCookieHeader: [
          'SESSDATA=response-session; Domain=.bilibili.com; Path=/',
        ],
      },
    ),
  );

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _backup(String session, AccountType role) => {
  '101': {
    'cookies': {'DedeUserID': '101', 'SESSDATA': session},
    'accessKey': '$session-token',
    'type': [role.index],
  },
};

void main() {
  late Directory sandbox;
  late Dio client;
  late _CookieResponseAdapter adapter;

  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('pili-cookie-response-');
    Hive.init(sandbox.path);
    GStorage.regAdapter();
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
    await Accounts.init();
  });

  setUp(() async {
    await Accounts.account.clear();
    await Accounts.importBackup(_backup('original-session', AccountType.main));
    adapter = _CookieResponseAdapter();
    client = Dio()..httpClientAdapter = adapter;
    client.interceptors.add(AccountManager());
  });

  tearDown(() => client.close(force: true));
  tearDownAll(() async {
    await Hive.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'a response bound to the old account cannot overwrite a restore',
    () async {
      final original = Accounts.main;
      final response = client.get<String>(
        'https://api.bilibili.com/test-cookie',
      );
      await adapter.requested.future;

      await Accounts.importBackup(
        _backup('restored-session', AccountType.video),
      );
      final restored = Accounts.video;
      expect(restored, isNot(same(original)));
      adapter.respond();
      expect((await response).data, 'ok');

      final saved = Accounts.account.get('101')!;
      expect(saved, same(restored));
      expect(saved.accessKey, 'restored-session-token');
      expect(saved.type, {AccountType.video});
      expect(saved.cookieJar.toJson()['SESSDATA'], 'restored-session');
    },
  );

  test('a response bound to the stored account still saves cookies', () async {
    final original = Accounts.main;
    final response = client.get<String>('https://api.bilibili.com/test-cookie');
    await adapter.requested.future;
    adapter.respond();
    expect((await response).data, 'ok');

    final saved = Accounts.account.get('101')!;
    expect(saved, same(original));
    expect(saved.type, {AccountType.main});
    expect(saved.cookieJar.toJson()['SESSDATA'], 'response-session');
  });
}
