import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  const StoredSession({
    required this.serverUrl,
    required this.username,
    required this.token,
    this.allowUntrustedCertificate = false,
    this.displayName = '',
    this.email = '',
  });

  final String serverUrl;
  final String username;
  final String token;
  final bool allowUntrustedCertificate;
  final String displayName;
  final String email;

  String get accountId => '${serverUrl.toLowerCase()}|${username.toLowerCase()}';

  StoredSession copyWith({
    String? displayName,
    String? email,
  }) {
    return StoredSession(
      serverUrl: serverUrl,
      username: username,
      token: token,
      allowUntrustedCertificate: allowUntrustedCertificate,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'token': token,
        'allowUntrustedCertificate': allowUntrustedCertificate,
        'displayName': displayName,
        'email': email,
      };

  static StoredSession? fromJson(Map<String, dynamic> json) {
    final server = json['serverUrl'];
    final username = json['username'];
    final token = json['token'];
    if (server is! String || username is! String || token is! String) return null;
    if (server.isEmpty || username.isEmpty || token.isEmpty) return null;
    return StoredSession(
      serverUrl: server,
      username: username,
      token: token,
      allowUntrustedCertificate: json['allowUntrustedCertificate'] == true,
      displayName: json['displayName'] is String ? json['displayName'] as String : '',
      email: json['email'] is String ? json['email'] as String : '',
    );
  }
}

class SessionStore {
  SessionStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ?? const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  static const _repoPrefix = 'seafile.desktop.repo.';
  final FlutterSecureStorage _secure;

  // On macOS we deliberately keep tokens in the sandboxed Application Support
  // directory. The legacy Keychain is tied to the ad-hoc code signature of each
  // local build and prompts for the login password after every rebuild; that
  // makes unsigned development and CI builds unusable. Windows continues to use
  // the platform secure storage (DPAPI-backed).
  bool get _fileStore => !kIsWeb && Platform.isMacOS;

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'seafile'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _sessionFile() async => File(p.join((await _directory()).path, 'session.json'));

  Future<File> _secretsFile() async => File(p.join((await _directory()).path, 'repo_secrets.json'));

  Future<Map<String, dynamic>> _readSecrets() async {
    try {
      final file = await _secretsFile();
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  Future<void> _writeSecrets(Map<String, dynamic> secrets) async {
    final file = await _secretsFile();
    await file.writeAsString(jsonEncode(secrets), flush: true);
    await _restrictPermissions(file);
  }

  Future<void> _restrictPermissions(File file) async {
    try {
      await Process.run('chmod', ['600', file.path]);
    } catch (_) {}
  }

  Future<StoredSession?> readSession() async {
    try {
      if (_fileStore) {
        final file = await _sessionFile();
        if (!await file.exists()) return null;
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) return StoredSession.fromJson(decoded.cast<String, dynamic>());
        return null;
      }
      final raw = await _secure.read(key: 'seafile.desktop.session');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) return StoredSession.fromJson(decoded.cast<String, dynamic>());
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(StoredSession session) async {
    if (_fileStore) {
      final file = await _sessionFile();
      await file.writeAsString(jsonEncode(session.toJson()), flush: true);
      await _restrictPermissions(file);
      return;
    }
    await _secure.write(key: 'seafile.desktop.session', value: jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    try {
      if (_fileStore) {
        final file = await _sessionFile();
        if (await file.exists()) await file.delete();
        return;
      }
      await _secure.delete(key: 'seafile.desktop.session');
    } catch (_) {}
  }

  String _repoKey(String accountId, String repoId) {
    final digest = sha1.convert(utf8.encode(accountId)).toString();
    return '$_repoPrefix$digest.$repoId';
  }

  Future<String?> readRepoPassword(String accountId, String repoId) async {
    try {
      final key = _repoKey(accountId, repoId);
      if (_fileStore) {
        final secrets = await _readSecrets();
        final value = secrets[key];
        return value is String && value.isNotEmpty ? value : null;
      }
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeRepoPassword(String accountId, String repoId, String password) async {
    final key = _repoKey(accountId, repoId);
    if (_fileStore) {
      final secrets = await _readSecrets();
      secrets[key] = password;
      await _writeSecrets(secrets);
      return;
    }
    await _secure.write(key: key, value: password);
  }

  Future<void> deleteRepoPassword(String accountId, String repoId) async {
    final key = _repoKey(accountId, repoId);
    try {
      if (_fileStore) {
        final secrets = await _readSecrets();
        if (secrets.remove(key) != null) await _writeSecrets(secrets);
        return;
      }
      await _secure.delete(key: key);
    } catch (_) {}
  }

  Future<void> deleteAllRepoPasswords(String accountId) async {
    final digest = sha1.convert(utf8.encode(accountId)).toString();
    final prefix = '$_repoPrefix$digest.';
    try {
      if (_fileStore) {
        final secrets = await _readSecrets();
        final before = secrets.length;
        secrets.removeWhere((key, _) => key.startsWith(prefix));
        if (secrets.length != before) await _writeSecrets(secrets);
        return;
      }
      final all = await _secure.readAll();
      for (final key in all.keys) {
        if (key.startsWith(prefix)) {
          await _secure.delete(key: key);
        }
      }
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      if (_fileStore) {
        for (final file in [await _sessionFile(), await _secretsFile()]) {
          if (await file.exists()) await file.delete();
        }
        return;
      }
      await _secure.deleteAll();
    } catch (_) {}
  }

  static Future<({String server, String username})> lastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      server: prefs.getString('lastServer') ?? '',
      username: prefs.getString('lastUsername') ?? '',
    );
  }

  static Future<void> saveLastLogin(String server, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastServer', server);
    await prefs.setString('lastUsername', username);
  }
}
