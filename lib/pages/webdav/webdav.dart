import 'dart:convert';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:uuid/v4.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

typedef _WebDavConfig = ({
  String uri,
  String username,
  String password,
  String directory,
});

class WebDav {
  _WebDavConfig? _clientConfig;
  webdav.Client? _client;

  WebDav._internal();
  static final WebDav _instance = WebDav._internal();
  factory WebDav() => _instance;

  _WebDavConfig _getConfig() {
    String directory = Pref.webdavDirectory;
    if (!directory.endsWith('/')) {
      directory += '/';
    }
    return (
      uri: Pref.webdavUri,
      username: Pref.webdavUsername,
      password: Pref.webdavPassword,
      directory: '$directory${Constants.appName}',
    );
  }

  Future<webdav.Client> _connect(
    _WebDavConfig config, {
    bool force = false,
  }) async {
    final cachedClient = _client;
    if (!force && cachedClient != null && _clientConfig == config) {
      return cachedClient;
    }

    final client =
        webdav.newClient(
            config.uri,
            user: config.username,
            password: config.password,
          )
          ..setHeaders({'accept-charset': 'utf-8'})
          ..setConnectTimeout(12000)
          ..setReceiveTimeout(12000)
          ..setSendTimeout(12000);

    await client.mkdirAll(config.directory);
    _clientConfig = config;
    _client = client;
    return client;
  }

  Future<Pair<bool, String?>> init() async {
    try {
      await _connect(_getConfig(), force: true);

      return Pair(first: true, second: null);
    } catch (e) {
      return Pair(first: false, second: e.toString());
    }
  }

  String _getFileName() {
    return 'piliplus_settings_${DeviceUtils.platformName}.json';
  }

  Future<void> backup() async {
    // Keep the payload bound to the same settings snapshot as the connection.
    final config = _getConfig();
    final data = GStorage.exportAllSettings();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (_) {
      SmartDialog.showToast('备份失败，请检查 WebDAV 配置');
      return;
    }
    final path = '${config.directory}/${_getFileName()}';
    final pending = '$path.${const UuidV4().generate()}.tmp';
    try {
      await client.write(pending, utf8.encode(data));
      final base = Uri.parse(client.uri);
      final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
      final backupPath = path.replaceFirst(RegExp(r'^/+'), '');
      final destination = base.replace(
        userInfo: '',
        path: '$basePath/$backupPath',
      );
      // The client's rename retries every conflict. This upload needs one MOVE.
      final response = await client.c.req(
        client,
        'MOVE',
        pending,
        optionsHandler: (options) {
          options.headers!['destination'] = destination.toString();
          options.headers!['overwrite'] = 'T';
        },
      );
      if (response.statusCode != 201 && response.statusCode != 204) {
        throw StateError('WebDAV MOVE did not complete');
      }
      SmartDialog.showToast('备份成功');
    } catch (_) {
      try {
        await client.remove(pending);
      } catch (_) {}
      SmartDialog.showToast('备份失败，请检查 WebDAV 服务状态');
    }
  }

  Future<void> restore() async {
    final config = _getConfig();
    final webdav.Client client;
    try {
      client = await _connect(config);
    } catch (e) {
      SmartDialog.showToast('恢复失败，请检查配置: $e');
      return;
    }
    try {
      final path = '${config.directory}/${_getFileName()}';
      final data = await client.read(path);
      await GStorage.importAllSettings(utf8.decode(data));
      SmartDialog.showToast('恢复成功');
    } catch (e) {
      SmartDialog.showToast('恢复失败: $e');
    }
  }
}
