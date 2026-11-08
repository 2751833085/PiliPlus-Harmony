import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:hive_ce/hive.dart';

abstract final class Accounts {
  static late final Box<LoginAccount> account;
  static final List<Account> accountMode = List.filled(
    AccountType.values.length,
    AnonymousAccount(),
  );
  static bool get mainEqVideo => main == video;
  static Account get main => accountMode[AccountType.main.index];
  static Account get video => accountMode[AccountType.video.index];
  static Account get heartbeat => accountMode[AccountType.heartbeat.index];
  static Account get history {
    final heartbeat = Accounts.heartbeat;
    if (heartbeat is AnonymousAccount) {
      return Accounts.main;
    }
    return heartbeat;
  }
  // static set main(Account account) => set(AccountType.main, account);

  static Future<void> init() async {
    account = await Hive.openBox(
      'account',
      compactionStrategy: (int entries, int deletedEntries) {
        return deletedEntries > 2;
      },
    );
  }

  static void _loadAccountModes() {
    accountMode.fillRange(0, accountMode.length, AnonymousAccount());
    for (final a in account.values) {
      for (final t in a.type) {
        accountMode[t.index] = a;
      }
    }
  }

  static Future<void> refresh() {
    _loadAccountModes();
    return Future.wait(
      (accountMode.toSet()..removeWhere((i) => i.activated)).map(
        Request.buvidActive,
      ),
    );
  }

  static String exportBackup() => Utils.jsonEncoder.convert({
    'version': 1,
    'accounts': account.toMap(),
    'roles': {
      for (final role in AccountType.values)
        role.name: get(role).isLogin ? get(role).mid.toString() : null,
    },
  });

  static bool _restoringBackup = false;

  static Future<void> importBackup(Map json) async {
    if (_restoringBackup) throw StateError('正在恢复登录信息');
    final legacy = !json.containsKey('version');
    final accounts = legacy ? json : json['accounts'];
    if ((!legacy && json['version'] != 1) || accounts is! Map) {
      throw const FormatException('登录备份格式无效');
    }
    final imported = <String, LoginAccount>{};
    for (final entry in accounts.entries) {
      final uid = entry.key;
      final value = entry.value;
      if (uid is! String || value is! Map) {
        throw const FormatException('登录账号记录格式无效');
      }
      final record = LoginAccount.fromJson(value);
      if (record.mid.toString() != uid) {
        throw const FormatException('登录账号编号与凭据不匹配');
      }
      imported[uid] = record;
    }

    final roles = <AccountType, String?>{
      for (final role in AccountType.values) role: null,
    };
    if (legacy) {
      for (final entry in imported.entries) {
        for (final role in entry.value.type) {
          if (roles[role] != null) {
            throw const FormatException('登录备份包含重复的账号角色');
          }
          roles[role] = entry.key;
        }
      }
    } else {
      final savedRoles = json['roles'];
      if (savedRoles is! Map || savedRoles.length != roles.length) {
        throw const FormatException('登录备份的账号角色格式无效');
      }
      for (final role in AccountType.values) {
        final uid = savedRoles[role.name];
        if (!savedRoles.containsKey(role.name) ||
            (uid != null && (uid is! String || !imported.containsKey(uid)))) {
          throw const FormatException('登录备份的账号角色无效');
        }
        roles[role] = uid as String?;
      }
    }

    // Merge credentials, but restore the four role selections as one unit.
    final updates = <dynamic, LoginAccount>{...imported};
    final previousRoles = Map<LoginAccount, Set<AccountType>>.identity();
    for (final entry in {...account.toMap(), ...imported}.entries) {
      final record = entry.value;
      final assigned = {
        for (final role in roles.entries)
          if (role.value == entry.key) role.key,
      };
      if (record.type.length == assigned.length &&
          record.type.containsAll(assigned)) {
        continue;
      }
      previousRoles[record] = Set.of(record.type);
      record.type
        ..clear()
        ..addAll(assigned);
      updates[entry.key] = record;
    }
    _restoringBackup = true;
    try {
      await account.putAll(updates);
      _loadAccountModes();
    } catch (_) {
      for (final entry in previousRoles.entries) {
        entry.key.type
          ..clear()
          ..addAll(entry.value);
      }
      rethrow;
    } finally {
      _restoringBackup = false;
    }
  }

  static Future<void> clear() async {
    await account.clear();
    for (int i = 0; i < AccountType.values.length; i++) {
      accountMode[i] = AnonymousAccount();
    }
    await AnonymousAccount().delete();
    Request.buvidActive(AnonymousAccount());
  }

  static Future<void> deleteAll(Set<Account> accounts) async {
    final isLoginMain = Accounts.main.isLogin;
    for (int i = 0; i < AccountType.values.length; i++) {
      if (accounts.contains(accountMode[i])) {
        accountMode[i] = AnonymousAccount();
      }
    }
    await Future.wait(accounts.map((i) => i.delete()));
    if (isLoginMain && !Accounts.main.isLogin) {
      await LoginUtils.onLogoutMain();
    }
  }

  static Future<void> set(AccountType key, Account account) async {
    final oldAccount = accountMode[key.index]..type.remove(key);
    accountMode[key.index] = account..type.add(key);
    await Future.wait([?account.onChange(), ?oldAccount.onChange()]);
    if (!account.activated) await Request.buvidActive(account);
    switch (key) {
      case AccountType.main:
        await (account.isLogin
            ? LoginUtils.onLoginMain()
            : LoginUtils.onLogoutMain());
        break;
      case AccountType.heartbeat:
        MineController.anonymity.value = !account.isLogin;
        break;
      default:
        break;
    }
  }

  @pragma("vm:prefer-inline")
  static Account get(AccountType key) {
    return accountMode[key.index];
  }
}
