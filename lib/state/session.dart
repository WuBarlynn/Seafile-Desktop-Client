import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../api/seafile_api.dart';
import '../core/format.dart';
import 'session_store.dart';

class AppSession extends ChangeNotifier {
  AppSession({SessionStore? store, this.clientVersion = '0.1.0'})
      : _store = store ?? SessionStore();

  final SessionStore _store;
  final String clientVersion;

  SeafileApi? _api;
  StoredSession? _stored;
  AccountInfo? _accountInfo;
  ServerInfo? _serverInfo;
  List<Repository> _repositories = const [];
  ApiException? _librariesError;
  bool _restoring = true;
  bool _loadingLibraries = false;
  bool _loadedLibraries = false;
  bool _expired = false;
  bool _handlingExpired = false;
  bool _disposed = false;

  final Set<String> _unlockedRepos = {};

  SeafileApi? get api => _api;
  StoredSession? get stored => _stored;
  AccountInfo? get accountInfo => _accountInfo;
  ServerInfo? get serverInfo => _serverInfo;
  List<Repository> get repositories => _repositories;
  ApiException? get librariesError => _librariesError;
  bool get restoring => _restoring;
  bool get loadingLibraries => _loadingLibraries;
  bool get loadedLibraries => _loadedLibraries;
  bool get hasSession => _stored != null && _api != null;
  bool get expired => _expired;
  String get serverBase => _stored?.serverUrl ?? '';
  String get username => _stored?.username ?? '';

  String get displayName {
    final fromInfo = _accountInfo?.displayName(_stored?.username);
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    final storedName = _stored?.displayName;
    if (storedName != null && storedName.isNotEmpty) return storedName;
    return username;
  }

  String get emailLabel {
    final fromInfo = _accountInfo?.subtitle(_stored?.username);
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    return _stored?.email ?? username;
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'[\s._-]+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${_firstRune(parts.first)}${_firstRune(parts.last)}'.toUpperCase();
    }
    final runes = source.runes.toList();
    return String.fromCharCodes(runes.take(2)).toUpperCase();
  }

  String _firstRune(String value) {
    if (value.isEmpty) return '';
    return String.fromCharCode(value.runes.first);
  }

  double? get quotaFraction => _accountInfo?.usageFraction;
  int? get quotaUsage => _accountInfo?.usage;
  int? get quotaTotal => _accountInfo?.totalQuota;

  Repository? findRepo(String id) {
    for (final repo in _repositories) {
      if (repo.id == id) return repo;
    }
    return null;
  }

  Future<void> restore() async {
    _restoring = true;
    _notify();
    final saved = await _store.readSession();
    if (_disposed) return;
    if (saved == null) {
      _restoring = false;
      _notify();
      return;
    }
    _stored = saved;
    _api = _createApi(saved);
    _restoring = false;
    _notify();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final api = _api;
    if (api == null) return;
    try {
      final results = await Future.wait<dynamic>([
        api.accountInfo(),
        api.serverInfo(),
      ]);
      _accountInfo = results[0] as AccountInfo;
      _serverInfo = results[1] as ServerInfo;
      _updateStoredProfile();
    } catch (error) {
      if (error is ApiException && error.isUnauthorized) {
        await _handleExpired();
        return;
      }
    }
    await refreshLibraries();
    unawaited(refreshAccountInfo());
  }

  SeafileApi _createApi(StoredSession session) {
    return SeafileApi(
      serverUrl: session.serverUrl,
      token: session.token,
      allowUntrustedCertificate: session.allowUntrustedCertificate,
      clientVersion: clientVersion,
      onUnauthorized: _onUnauthorized,
    );
  }

  Future<void> signIn({
    required String server,
    required String username,
    required String password,
    String? otp,
    bool rememberDevice = false,
    bool persist = true,
    bool allowUntrusted = false,
  }) async {
    final uri = SeafileApi.normalizeServerUrl(server);
    final target = uri.toString();
    final temp = SeafileApi(serverUrl: target, clientVersion: clientVersion);
    String token;
    try {
      token = await temp.login(
        username: username.trim(),
        password: password,
        otp: otp,
        rememberDevice: rememberDevice,
      );
    } finally {
      temp.close();
    }

    final authenticated = SeafileApi(
      serverUrl: target,
      token: token,
      allowUntrustedCertificate: allowUntrusted,
      clientVersion: clientVersion,
      onUnauthorized: _onUnauthorized,
    );
    AccountInfo? info;
    try {
      info = await authenticated.accountInfo();
    } catch (error) {
      if (error is ApiException && error.isUnauthorized) {
        authenticated.close();
        rethrow;
      }
    }

    _api?.close();
    _api = authenticated;
    _accountInfo = info;
    _serverInfo = null;
    _repositories = const [];
    _librariesError = null;
    _loadedLibraries = false;
    _expired = false;
    _stored = StoredSession(
      serverUrl: target,
      username: username.trim(),
      token: token,
      allowUntrustedCertificate: allowUntrusted,
      displayName: info?.name ?? '',
      email: info?.email ?? '',
    );
    if (persist) {
      await _store.writeSession(_stored!);
    } else {
      await _store.clearSession();
    }
    await SessionStore.saveLastLogin(target, username.trim());
    _notify();
    unawaited(_loadServerInfo());
    await refreshLibraries();
    unawaited(refreshAccountInfo());
  }

  Future<void> _loadServerInfo() async {
    final api = _api;
    if (api == null) return;
    try {
      _serverInfo = await api.serverInfo();
      _notify();
    } catch (_) {}
  }

  Future<void> refreshLibraries() async {
    final api = _api;
    if (api == null || _loadingLibraries) return;
    _loadingLibraries = true;
    _librariesError = null;
    _notify();
    try {
      final repos = await api.repositories();
      repos.sort((a, b) => compareNatural(a.name, b.name));
      _repositories = repos;
      _loadedLibraries = true;
    } on ApiException catch (error) {
      _librariesError = error;
      if (error.isUnauthorized) {
        await _handleExpired();
        return;
      }
    } catch (_) {
      _librariesError = ApiException(ApiErrorKind.unknown);
    } finally {
      _loadingLibraries = false;
      _notify();
    }
  }

  Future<void> refreshAccountInfo() async {
    final api = _api;
    if (api == null) return;
    try {
      final info = await api.accountInfo();
      _accountInfo = info;
      _updateStoredProfile();
      _notify();
    } catch (_) {}
  }

  void _updateStoredProfile() {
    final stored = _stored;
    final info = _accountInfo;
    if (stored == null || info == null) return;
    _stored = stored.copyWith(
      displayName: info.name ?? stored.displayName,
      email: info.email ?? stored.email,
    );
  }

  void _onUnauthorized() {
    unawaited(_handleExpired());
  }

  Future<void> _handleExpired() async {
    if (_handlingExpired || _disposed) return;
    _handlingExpired = true;
    try {
      _api?.close();
      _api = null;
      _stored = null;
      _accountInfo = null;
      _serverInfo = null;
      _repositories = const [];
      _librariesError = null;
      _loadedLibraries = false;
      _unlockedRepos.clear();
      await _store.clearSession();
      _expired = true;
      _notify();
    } finally {
      _handlingExpired = false;
    }
  }

  Future<void> signOut({bool forgetRepoPasswords = true}) async {
    final accountId = _stored?.accountId;
    _api?.close();
    _api = null;
    _stored = null;
    _accountInfo = null;
    _serverInfo = null;
    _repositories = const [];
    _librariesError = null;
    _loadedLibraries = false;
    _unlockedRepos.clear();
    _expired = false;
    await _store.clearSession();
    if (forgetRepoPasswords && accountId != null) {
      await _store.deleteAllRepoPasswords(accountId);
    }
    _notify();
  }

  // -------------------------------------------------------------------------
  // Encrypted libraries

  bool isRepoUnlocked(String repoId) => _unlockedRepos.contains(repoId);

  Future<bool> tryAutoUnlock(Repository repo) async {
    if (!repo.encrypted) return true;
    if (_unlockedRepos.contains(repo.id)) return true;
    final accountId = _stored?.accountId;
    if (accountId == null) return false;
    final saved = await _store.readRepoPassword(accountId, repo.id);
    if (saved == null || saved.isEmpty) return false;
    final api = _api;
    if (api == null) return false;
    try {
      await api.setRepoPassword(repo.id, saved);
      _unlockedRepos.add(repo.id);
      _notify();
      return true;
    } on ApiException catch (error) {
      if (error.status == 400) {
        await _store.deleteRepoPassword(accountId, repo.id);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> unlockRepo(Repository repo, String password, {required bool remember}) async {
    final api = _api;
    if (api == null) throw ApiException(ApiErrorKind.network);
    try {
      await api.setRepoPassword(repo.id, password);
    } on ApiException catch (error) {
      if (error.status == 400) {
        throw const RepoCryptoException('Incorrect library password', wrongPassword: true);
      }
      rethrow;
    }
    final accountId = _stored?.accountId;
    if (accountId != null) {
      if (remember) {
        await _store.writeRepoPassword(accountId, repo.id, password);
      } else {
        await _store.deleteRepoPassword(accountId, repo.id);
      }
    }
    _unlockedRepos.add(repo.id);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _api?.close();
    super.dispose();
  }
}
