import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Map<String, Object?> _record(String uid, [List<int> roles = const []]) => {
  'cookies': {
    'DedeUserID': uid,
    'SESSDATA': 'fixture-session-$uid',
    'bili_jct': 'fixture-csrf',
  },
  'accessKey': 'fixture-access-$uid',
  'refresh': 'fixture-refresh-$uid',
  'type': roles,
};

void main() {
  late Directory sandbox;
  setUpAll(() async {
    sandbox = await Directory.systemTemp.createTemp('pili-account-backup-');
    Hive.init(sandbox.path);
    GStorage.regAdapter();
    GStorage.localCache = await Hive.openBox('localCache');
    Accounts.account = await Hive.openBox<LoginAccount>('account');
  });
  setUp(() async {
    await Accounts.account.clear();
    Accounts.accountMode.fillRange(
      0,
      AccountType.values.length,
      AnonymousAccount(),
    );
  });
  tearDownAll(() async {
    await Hive.close();
    await sandbox.delete(recursive: true);
  });

  test(
    'account backup restores all roles including guest and retains unselected accounts',
    () async {
      await Accounts.importBackup({
        '101': _record('101', [
          AccountType.main.index,
          AccountType.recommend.index,
        ]),
        '202': _record('202', [AccountType.video.index]),
        '303': _record('303'),
      });
      final backup = jsonDecode(Accounts.exportBackup()) as Map;
      expect(backup['roles'], {
        'main': '101',
        'heartbeat': null,
        'recommend': '101',
        'video': '202',
      });

      await Accounts.importBackup({
        '404': _record('404', [
          for (final role in AccountType.values) role.index,
        ]),
      });
      await Accounts.importBackup(backup);
      expect(
        Accounts.account.keys,
        unorderedEquals(['101', '202', '303', '404']),
      );
      expect(Accounts.main.mid, 101);
      expect(Accounts.video.mid, 202);
      expect(Accounts.heartbeat.isLogin, isFalse);
      expect(Accounts.get(AccountType.recommend), same(Accounts.main));
      expect(Accounts.account.get('404')!.type, isEmpty);
      final restored = Accounts.account.get('101')!;
      expect(restored.accessKey, 'fixture-access-101');
      expect(restored.refresh, 'fixture-refresh-101');
      expect(restored.cookieJar.toJson()['SESSDATA'], 'fixture-session-101');
      expect(restored.type, {AccountType.main, AccountType.recommend});
    },
  );

  test(
    'invalid record, mismatched UID or competing roles never write accounts',
    () async {
      await Accounts.importBackup({
        '101': _record('101', [AccountType.main.index]),
      });
      final current = Accounts.main;
      final invalid = [
        {'202': _record('202'), '303': _record('304')},
        {
          '202': _record('202'),
          '303': {
            'cookies': {'DedeUserID': '303'},
          },
        },
        {
          '202': _record('202', [AccountType.main.index]),
          '303': _record('303', [AccountType.main.index]),
        },
        {
          '202': _record('202', [99]),
        },
        {
          'version': 1,
          'accounts': {'202': _record('202')},
          'roles': {
            'main': '999',
            'heartbeat': null,
            'recommend': null,
            'video': null,
          },
        },
      ];
      for (final backup in invalid) {
        await expectLater(Accounts.importBackup(backup), throwsFormatException);
        expect(Accounts.account.keys, ['101']);
        expect(Accounts.main, same(current));
      }
    },
  );
}
