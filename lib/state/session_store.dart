import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  static const _sessionKey = 'seafile.desktop.session';
  static const _repoPrefix = 'seafile.desktop.repo.';
  final FlutterSecureStorage _secure;

  Future<StoredSession?> readSession() async {
    try {
      final raw = await _secure.read(key: _sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) return StoredSession.fromJson(decoded.cast<String, dynamic>());
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(StoredSession session) async {
    await _secure.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    try {
      await _secure.delete(key: _sessionKey);
    } catch (_) {}
  }

  String _repoKey(String accountId, String repoId) {
    final digest = sha1.convert(utf8.encode(accountId)).toString();
    return '$_repoPrefix$digest.$repoId';
  }

  Future<String?> readRepoPassword(String accountId, String repoId) async {
    try {
      return await _secure.read(key: _repoKey(accountId, repoId));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeRepoPassword(String accountId, String repoId, String password) async {
    await _secure.write(key: _repoKey(accountId, repoId), value: password);
  }

  Future<void> deleteRepoPassword(String accountId, String repoId) async {
    try {
      await _secure.delete(key: _repoKey(accountId, repoId));
    } catch (_) {}
  }

  Future<void> deleteAllRepoPasswords(String accountId) async {
    final digest = sha1.convert(utf8.encode(accountId)).toString();
    final prefix = '$_repoPrefix$digest.';
    try {
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
