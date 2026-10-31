import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/app_info.dart';
import '../core/format.dart';
import 'api_error.dart';
import 'json_utils.dart';
import 'models.dart';

class SeafileApi {
  SeafileApi({
    required String serverUrl,
    this.token,
    this.allowUntrustedCertificate = false,
    this.onUnauthorized,
    this.clientVersion = appVersion,
  }) : serverUri = normalizeServerUrl(serverUrl) {
    _api = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'X-Seafile-Client-Version': clientVersion,
          'X-Seafile-Platform': Platform.operatingSystem,
          'X-Seafile-Platform-Version': Platform.operatingSystemVersion,
        },
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    )..httpClientAdapter = _adapter();
    _transfer = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(hours: 2),
        sendTimeout: const Duration(hours: 2),
        headers: {
          'X-Seafile-Client-Version': clientVersion,
          'X-Seafile-Platform': Platform.operatingSystem,
        },
      ),
    )..httpClientAdapter = _adapter();
  }

  static const _csrfToken = 'n8ba38951c9ba66418311a25195e2e380';

  final Uri serverUri;
  final String? token;
  final bool allowUntrustedCertificate;
  final String clientVersion;
  final void Function()? onUnauthorized;
  late final Dio _api;
  late final Dio _transfer;
  int serverMajorVersion = 14;
  String? _fileServerRoot;

  String get serverBase {
    var value = serverUri.toString();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String get _baseUrl => '$serverBase/';
  String get _host => serverUri.host;

  IOHttpClientAdapter _adapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 20);
        if (allowUntrustedCertificate) {
          client.badCertificateCallback = (cert, host, port) => host == _host;
        }
        return client;
      },
    );
  }

  Map<String, String> get _authHeaders => {
        if (token != null && token!.isNotEmpty) 'Authorization': 'Token $token',
      };

  static Uri normalizeServerUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) throw FormatException('Empty server address');
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Invalid server address');
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    for (final suffix in ['/api2', '/api/v2.1', '/api']) {
      if (path.toLowerCase().endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
      }
    }
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: path);
  }

  // -------------------------------------------------------------------------
  // Authentication

  Future<String> login({
    required String username,
    required String password,
    String? otp,
    bool rememberDevice = false,
  }) async {
    final headers = <String, String>{
      if (otp != null && otp.isNotEmpty) 'X-Seafile-OTP': otp,
      if (rememberDevice) 'X-SEAFILE-2FA-TRUST-DEVICE': '1',
    };
    final form = <String, String>{
      'username': username,
      'password': password,
    };

    Response<dynamic> response;
    try {
      response = await _api.post<dynamic>(
        'api2/auth-token/',
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: headers),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
    final data = response.data;
    if (data is Map && data['token'] is String) return data['token'] as String;
    throw ApiException(ApiErrorKind.unknown, serverMessage: extractMessage(data));
  }

  Future<String?> clientLoginToken() async {
    try {
      final data = await _postForm('api2/client-login/', const {});
      final token = firstString(asMap(data), ['token']);
      return token?.isEmpty == true ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<Uri> clientSsoLink() async {
    final data = await _postForm('api2/client-sso-link/', const {});
    final raw = firstString(asMap(data), ['link']);
    if (raw == null || raw.isEmpty) throw ApiException(ApiErrorKind.unknown, serverMessage: 'SSO is not available.');
    return Uri.parse(raw);
  }

  Future<({String username, String token})?> clientSsoStatus(Uri link) async {
    final text = link.toString();
    final index = text.indexOf('client-sso/');
    if (index < 0) throw ApiException(ApiErrorKind.decoding);
    final path = text.substring(index + 'client-sso/'.length).split('?').first.replaceAll(RegExp(r'/+$'), '');
    final data = await _get('api2/client-sso-link/$path');
    final map = asMap(data);
    final status = firstString(map, ['status']);
    if (status == 'success') {
      final username = firstString(map, ['username']);
      final token = firstString(map, ['apiToken', 'api_token']);
      if (username == null || token == null) throw ApiException(ApiErrorKind.decoding);
      return (username: username, token: token);
    }
    if (status == 'error') {
      throw ApiException(ApiErrorKind.unknown, serverMessage: firstString(map, ['message', 'error_msg']));
    }
    return null;
  }

  Future<AccountInfo> accountInfo() async {
    final data = await _get('api2/account/info/');
    return AccountInfo.fromJson(asMap(data));
  }

  Future<ServerInfo> serverInfo() async {
    final data = await _get('api2/server-info/');
    final info = ServerInfo.fromJson(asMap(data));
    serverMajorVersion = int.tryParse((info.version ?? '').split('.').first) ?? serverMajorVersion;
    return info;
  }

  Future<Map<String, dynamic>> userProfile() async {
    return asMap(await _get('api/v2.1/user/'));
  }

  Future<String?> uploadAvatar(String filePath) async {
    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    try {
      final response = await _transfer.post<dynamic>(
        '$base/api/v2.1/user-avatar/',
        data: FormData.fromMap({
          'avatar': await MultipartFile.fromFile(filePath),
        }),
        options: Options(headers: {..._authHeaders, 'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data is Map) return firstString(data.cast<String, dynamic>(), ['avatar_url']);
      return null;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> values) async {
    return asMap(await _putJson('api/v2.1/user/', values));
  }

  Future<void> resetPassword({required String oldPassword, required String newPassword}) async {
    await _postJson('api/v2.1/user/reset-password/', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> adminSysInfo() async {
    return asMap(await _get('api/v2.1/admin/sysinfo/'));
  }

  Future<Map<String, dynamic>> adminWebSettings() async {
    return asMap(await _get('api/v2.1/admin/web-settings/'));
  }

  Future<void> updateAdminWebSettings(Map<String, dynamic> values) async {
    await _putJson('api/v2.1/admin/web-settings/', values);
  }

  Future<Map<String, dynamic>> adminUsers({int page = 1, int perPage = 50, String query = ''}) async {
    return asMap(await _get('api/v2.1/admin/users/', query: {
      'page': '$page',
      'per_page': '$perPage',
      if (query.isNotEmpty) 'q': query,
    }));
  }

  Future<Map<String, dynamic>> adminLibraries({int page = 1, int perPage = 50, String query = ''}) async {
    return asMap(await _get('api/v2.1/admin/libraries/', query: {
      'page': '$page',
      'per_page': '$perPage',
      if (query.isNotEmpty) 'q': query,
    }));
  }

  Future<Map<String, dynamic>> adminLogs({int page = 1, int perPage = 50}) async {
    return asMap(await _get('api/v2.1/admin/admin-logs/', query: {
      'page': '$page',
      'per_page': '$perPage',
    }));
  }

  Future<List<Map<String, dynamic>>> adminLoginLogs({required String start, required String end}) async {
    final data = await _get('api/v2.1/admin/logs/login/', query: {'start': start, 'end': end});
    return asMapList(data).map((item) => item).toList();
  }

  Future<List<Map<String, dynamic>>> adminFileUpdateLogs({required String start, required String end}) async {
    final data = await _get('api/v2.1/admin/logs/file-update/', query: {'start': start, 'end': end});
    return asMapList(data).map((item) => item).toList();
  }

  Future<Map<String, dynamic>> adminGroups({int page = 1, int perPage = 50, String name = ''}) async {
    return asMap(await _get('api/v2.1/admin/groups/', query: {
      'page': '$page',
      'per_page': '$perPage',
      if (name.isNotEmpty) 'name': name,
    }));
  }

  Future<Map<String, dynamic>> createAdminGroup(String name, String owner) async {
    return asMap(await _postJson('api/v2.1/admin/groups/', {
      'group_name': name,
      'group_owner': owner,
    }));
  }

  Future<void> deleteAdminGroup(int id) async {
    await _delete('api/v2.1/admin/groups/$id/');
  }

  Future<Map<String, dynamic>> adminShareLinks({int page = 1, int perPage = 50}) async {
    return asMap(await _get('api/v2.1/admin/share-links/', query: {
      'page': '$page',
      'per_page': '$perPage',
    }));
  }

  Future<void> deleteAdminShareLink(String token) async {
    await _delete('api/v2.1/admin/share-links/$token/');
  }

  Future<Map<String, dynamic>> createAdminUser(Map<String, dynamic> values) async {
    return asMap(await _postJson('api/v2.1/admin/users/', values));
  }

  Future<Map<String, dynamic>> updateAdminUser(String email, Map<String, dynamic> values) async {
    final encoded = Uri.encodeComponent(email);
    return asMap(await _putJson('api/v2.1/admin/users/$encoded/', values));
  }

  Future<void> resetAdminUserPassword(String email, String password) async {
    final encoded = Uri.encodeComponent(email);
    await _postJson('api/v2.1/admin/users/$encoded/reset-password/', {'password': password});
  }

  Future<void> deleteAdminUser(String email) async {
    final encoded = Uri.encodeComponent(email);
    await _delete('api/v2.1/admin/users/$encoded/');
  }

  // -------------------------------------------------------------------------
  // SeaDoc

  Future<(String token, String fileUuid, String serverUrl)> _seadocSession(String repoId, String path) async {
    final data = asMap(await _get('api/v2.1/seadoc/access-token/$repoId/', query: {'p': path}));
    final token = firstString(data, ['access_token']) ?? '';
    if (token.isEmpty) throw ApiException(ApiErrorKind.decoding);
    String fileUuid = '';
    try {
      final payload = token.split('.');
      if (payload.length >= 2) {
        final normalized = base64Url.normalize(payload[1]);
        final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
        if (decoded is Map) fileUuid = firstString(decoded.cast<String, dynamic>(), ['file_uuid']) ?? '';
      }
    } catch (_) {}
    if (fileUuid.isEmpty) throw ApiException(ApiErrorKind.decoding);

    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final candidates = ['$base/sdoc-server', base];
    for (final candidate in candidates) {
      try {
        final response = await _transfer.get<dynamic>(
          '${candidate.replaceFirst(RegExp(r'/+$'), '')}/api/v1/docs/$fileUuid/',
          options: Options(
            headers: {'Authorization': 'Token $token', 'Accept': 'application/json'},
            validateStatus: (status) => status != null && status >= 200 && status < 500,
          ),
        );
        if (response.statusCode == 200) return (token, fileUuid, candidate);
      } catch (_) {}
    }
    throw ApiException(ApiErrorKind.server, serverMessage: 'SeaDoc server unavailable');
  }

  Future<String> uploadSdocImage(String repoId, String path, String filePath) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    final extension = filePath.contains('.') ? filePath.substring(filePath.lastIndexOf('.')) : '';
    final name = 'image-${DateTime.now().microsecondsSinceEpoch}$extension';
    try {
      final response = await _api.post<dynamic>(
        'api/v2.1/seadoc/upload-image/$fileUuid/',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: name),
        }),
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
      final data = asMap(response.data);
      final raw = data['relative_path'];
      if (raw is String) return raw;
      if (raw is List && raw.isNotEmpty) return raw.first.toString();
      throw ApiException(ApiErrorKind.decoding);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<String> uploadSdocVideo(String repoId, String path, String filePath) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    final extension = filePath.contains('.') ? filePath.substring(filePath.lastIndexOf('.')) : '';
    final name = 'video-${DateTime.now().microsecondsSinceEpoch}$extension';
    try {
      final response = await _api.post<dynamic>(
        'api/v2.1/seadoc/upload-video/$fileUuid/',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: name),
        }),
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
      final data = asMap(response.data);
      final raw = data['relative_path'];
      if (raw is String) return raw;
      if (raw is List && raw.isNotEmpty) return raw.first.toString();
      throw ApiException(ApiErrorKind.decoding);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Uint8List> loadSdocImage(String repoId, String path, String src) async {
    final (_, fileUuid, _) = await _seadocSession(repoId, path);
    final name = src.split('/').last;
    try {
      final response = await _api.get<List<int>>(
        'api/v2.1/seadoc/download-image/$fileUuid/${Uri.encodeComponent(name)}',
        options: Options(responseType: ResponseType.bytes, headers: _authHeaders),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> seadocComments(String repoId, String path) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    try {
      final response = await _api.get<dynamic>(
        'api/v2.1/seadoc/comments/$fileUuid/',
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
      return asMap(response.data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> addSeadocComment(String repoId, String path, String comment, {String detail = ''}) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    try {
      await _api.post<dynamic>(
        'api/v2.1/seadoc/comments/$fileUuid/',
        data: {'comment': comment, 'detail': detail},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'Token $token', 'Accept': 'application/json'},
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> addSeadocCommentReply(String repoId, String path, int commentId, String reply) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    try {
      await _api.post<dynamic>(
        'api/v2.1/seadoc/comments/$fileUuid/$commentId/replies/',
        data: {'reply': reply},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'Token $token', 'Accept': 'application/json'},
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> setSeadocCommentResolved(String repoId, String path, int commentId, bool resolved) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    try {
      await _api.put<dynamic>(
        'api/v2.1/seadoc/comments/$fileUuid/$commentId/',
        data: {'resolved': '$resolved'},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'Token $token', 'Accept': 'application/json'},
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> deleteSeadocComment(String repoId, String path, int commentId) async {
    final (token, fileUuid, _) = await _seadocSession(repoId, path);
    try {
      await _api.delete<dynamic>(
        'api/v2.1/seadoc/comments/$fileUuid/$commentId/',
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Uint8List> loadSdocVideo(String repoId, String path, String src) async {
    final (_, fileUuid, _) = await _seadocSession(repoId, path);
    final name = src.split('/').last;
    try {
      final response = await _api.get<List<int>>(
        'api/v2.1/seadoc/download-video/$fileUuid/${Uri.encodeComponent(name)}',
        options: Options(responseType: ResponseType.bytes, headers: _authHeaders, receiveTimeout: const Duration(minutes: 10)),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Map<String, dynamic>> loadSdocDocument(String repoId, String path) async {
    final (token, fileUuid, serverUrl) = await _seadocSession(repoId, path);
    try {
      final response = await _transfer.get<dynamic>(
        '${serverUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/docs/$fileUuid/',
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      if (data is String) return asMap(jsonDecode(data));
      throw ApiException(ApiErrorKind.decoding);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> saveSdocDocument(String repoId, String path, Map<String, dynamic> document) async {
    final (token, fileUuid, serverUrl) = await _seadocSession(repoId, path);
    final base = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final name = path.split('/').last;
    try {
      await _transfer.post<dynamic>(
        '$base/api/v2.1/seadoc/upload-file/$fileUuid/',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            utf8.encode(jsonEncode(document)),
            filename: name,
          ),
        }),
        options: Options(headers: {'Authorization': 'Token $token', 'Accept': 'application/json'}),
      );
      await _transfer.post<dynamic>(
        '${serverUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1/docs/$fileUuid/replace/',
        data: {'doc_name': name},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Authorization': 'Token $token', 'Accept': 'application/json'},
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // -------------------------------------------------------------------------
  // Libraries

  Future<List<Repository>> repositories() async {
    try {
      final data = await _get('api/v2.1/repos/');
      final raw = data is Map ? (data['repos'] ?? data['repositories']) : data;
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => Repository.fromJson(item.cast<String, dynamic>()))
            .where((repo) => repo.id.isNotEmpty && repo.name.isNotEmpty)
            .toList();
      }
    } on ApiException catch (error) {
      if (error.status != 400 && error.status != 404) rethrow;
    }
    final data = await _get('api2/repos/');
    return asMapList(data)
        .map(Repository.fromJson)
        .where((repo) => repo.id.isNotEmpty && repo.name.isNotEmpty)
        .toList();
  }

  Future<Repository> repoInfoV21(String repoId) async {
    final data = await _get('api/v2.1/repos/$repoId/');
    return Repository.fromJson(asMap(data));
  }

  Future<Repository> createLibrary({required String name, String description = '', String? password}) async {
    final data = await _postForm('api2/repos/', {
      'name': name,
      'desc': description,
      if (password != null && password.isNotEmpty) 'passwd': password,
    });
    return Repository.fromJson(asMap(data));
  }

  Future<void> renameLibrary(String repoId, String newName) async {
    await _postForm('api2/repos/$repoId/', {'repo_name': newName}, query: {'op': 'rename'});
  }

  Future<void> deleteLibrary(String repoId) async {
    await _delete('api/v2.1/repos/$repoId/');
  }

  Future<void> setRepoPassword(String repoId, String password) async {
    await _postForm('api/v2.1/repos/$repoId/set-password/', {'password': password});
  }

  Future<int> repoHistoryLimit(String repoId) async {
    final data = await _get('api2/repos/$repoId/history-limit/', query: {'op': 'get'});
    return firstInt(asMap(data), ['keep_days']) ?? -1;
  }

  Future<void> setRepoHistoryLimit(String repoId, int keepDays) async {
    await _postForm('api2/repos/$repoId/history-limit/', {'keep_days': '$keepDays'});
  }

  // -------------------------------------------------------------------------
  // Directory browsing

  Future<List<Dirent>> listDir(String repoId, String path) async {
    final normalized = normalizeRepoPath(path);
    try {
      final data = await _get(
        'api/v2.1/repos/$repoId/dir/',
        query: {'p': normalized, 'with_thumbnail': 'true'},
      );
      return _parseDirents(data, normalized);
    } on ApiException catch (error) {
      if (error.status != 400 && error.status != 404) rethrow;
    }
    final data = await _get('api2/repos/$repoId/dir/', query: {'p': normalized});
    return _parseDirents(data, normalized);
  }

  List<Dirent> _parseDirents(dynamic data, String parentPath) {
    final raw = data is Map ? (data['dirent_list'] ?? data['entries']) : data;
    final entries = <Dirent>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final entry = Dirent.fromJson(item.cast<String, dynamic>(), parentPath);
          if (entry.name.isNotEmpty) entries.add(entry);
        }
      }
    }
    return entries;
  }

  Future<FileDetail> fileDetail(String repoId, String path) async {
    final data = await _get('api2/repos/$repoId/file/detail/', query: {'p': path});
    return FileDetail.fromJson(asMap(data));
  }

  // -------------------------------------------------------------------------
  // Mutations

  Future<void> createDirectory(String repoId, String parentPath, String name) async {
    final fullPath = joinRepoPath(parentPath, name);
    await _postForm(
      'api2/repos/$repoId/dir/',
      {'operation': 'mkdir'},
      query: {'p': fullPath, 'reloaddir': 'true'},
    );
  }

  Future<void> renameEntry(String repoId, Dirent entry, String newName) async {
    final endpoint = entry.isDir ? 'api2/repos/$repoId/dir/' : 'api2/repos/$repoId/file/';
    await _postForm(
      endpoint,
      {'operation': 'rename', 'newname': newName},
      query: {'p': entry.path, 'reloaddir': 'true'},
    );
  }

  Future<void> setFileLock(String repoId, String path, bool lock) async {
    try {
      await _api.put<dynamic>(
        'api/v2.1/repos/$repoId/file/',
        queryParameters: {'p': path},
        data: FormData.fromMap({'operation': lock ? 'lock' : 'unlock'}),
        options: Options(headers: _authHeaders),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> createFile(String repoId, String path) async {
    await _postForm(
      'api2/repos/$repoId/file/',
      {'operation': 'create'},
      query: {'p': path, 'reloaddir': 'true'},
    );
  }

  Future<NotificationBundle> notifications({int page = 1, int perPage = 25}) async {
    final data = await _get(
      'api/v2.1/all-notifications/',
      query: {'page': '$page', 'per_page': '$perPage'},
    );
    final map = asMap(data);
    final general = asMap(map['general']);
    final discussion = asMap(map['discussion']);
    final items = <NotificationItem>[
      for (final item in asMapList(general['notification_list'])) NotificationItem.fromJson(item),
      for (final item in asMapList(discussion['notification_list'])) NotificationItem.fromJson(item),
    ]..sort((a, b) => (b.time?.millisecondsSinceEpoch ?? 0).compareTo(a.time?.millisecondsSinceEpoch ?? 0));
    return NotificationBundle(
      items: items,
      totalUnseen: firstInt(map, ['total_unseen_count']) ?? 0,
      generalUnseen: firstInt(general, ['unseen_count']) ?? 0,
      discussionUnseen: firstInt(discussion, ['unseen_count']) ?? 0,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _put('api/v2.1/all-notifications/');
  }

  Future<void> markNotificationRead(NotificationItem item, {bool discussion = false}) async {
    final endpoint = discussion ? 'api/v2.1/sdoc-notification/' : 'api/v2.1/notification/';
    try {
      await _api.put<dynamic>(
        endpoint,
        data: FormData.fromMap({'notice_id': '${item.id}'}),
        options: Options(headers: _authHeaders),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<WikiInfo>> wikis() async {
    final result = <WikiInfo>[];
    ApiException? lastError;
    try {
      final data = await _get('api/v2.1/wikis2/');
      final map = asMap(data);
      for (final item in asMapList(map['wikis'])) {
        final wiki = WikiInfo.fromJson(item);
        if (wiki.id.isNotEmpty && wiki.name.isNotEmpty) result.add(wiki);
      }
      for (final group in asMapList(map['group_wikis'])) {
        final groupName = firstString(group, ['group_name']) ?? '';
        for (final item in asMapList(group['wiki_info'])) {
          final wiki = WikiInfo.fromJson(item, groupName: groupName);
          if (wiki.id.isNotEmpty && wiki.name.isNotEmpty) result.add(wiki);
        }
      }
    } on ApiException catch (error) {
      lastError = error;
      if (error.status != 404) rethrow;
    }
    try {
      final data = await _get('api/v2.1/wikis/');
      final raw = asMap(data)['data'] ?? data;
      for (final item in asMapList(raw)) {
        final wiki = WikiInfo.fromJson(item, legacy: true);
        if (wiki.name.isNotEmpty) result.add(wiki);
      }
    } on ApiException catch (error) {
      lastError = error;
    }
    if (result.isEmpty && lastError != null) throw lastError;
    return result;
  }

  Future<void> importSdoc(String repoId, String parentDir, String filePath) async {
    final form = FormData.fromMap({
      'parent_dir': parentDir,
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split(Platform.pathSeparator).last),
    });
    try {
      await _api.post<dynamic>(
        'api/v2.1/seadoc/import/$repoId/',
        data: form,
        options: Options(
          headers: _authHeaders,
          sendTimeout: const Duration(hours: 2),
          receiveTimeout: const Duration(hours: 2),
        ),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<bool> seaDocAvailable(String repoId) async {
    try {
      final response = await _api.get<dynamic>(
        'api/v2.1/seadoc/import/$repoId/',
        options: Options(headers: _authHeaders),
      );
      return response.statusCode != 404;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return status != null && status != 404;
    }
  }

  Future<bool> exdrawAvailable(String repoId) async {
    try {
      final response = await _api.get<dynamic>(
        'api/v2.1/exdraw/access-token/$repoId/',
        queryParameters: {'p': '/'},
        options: Options(headers: _authHeaders),
      );
      return response.statusCode != 404;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return status != null && status != 404;
    }
  }

  Future<void> deleteEntries(String repoId, String dirPath, List<String> names) async {
    if (names.isEmpty) return;
    await _postForm(
      'api2/repos/$repoId/fileops/delete/',
      {'file_names': names.join(':')},
      query: {'p': dirPath, 'reloaddir': 'true'},
    );
  }

  Future<void> copyEntries({
    required String repoId,
    required String dirPath,
    required List<String> names,
    required String destinationRepoId,
    required String destinationPath,
  }) async {
    if (names.isEmpty) return;
    await _postForm(
      'api2/repos/$repoId/fileops/copy/',
      {'dst_repo': destinationRepoId, 'dst_dir': destinationPath, 'file_names': names.join(':')},
      query: {'p': dirPath, 'reloaddir': 'true'},
    );
  }

  Future<void> moveEntries({
    required String repoId,
    required String dirPath,
    required List<String> names,
    required String destinationRepoId,
    required String destinationPath,
  }) async {
    if (names.isEmpty) return;
    await _postForm(
      'api2/repos/$repoId/fileops/move/',
      {'dst_repo': destinationRepoId, 'dst_dir': destinationPath, 'file_names': names.join(':')},
      query: {'p': dirPath, 'reloaddir': 'true'},
    );
  }

  // -------------------------------------------------------------------------
  // Trash

  Future<TrashPage> listTrash(String repoId, {int page = 1, int perPage = 100, String? scanStat}) async {
    if (serverMajorVersion >= 14) {
      final data = await _get(
        'api/v2.1/repos/$repoId/trash2/',
        query: {'page': '$page', 'per_page': '$perPage'},
      );
      final map = asMap(data);
      final items = asMapList(map['items']).map(TrashEntry.fromJson).toList();
      final total = firstInt(map, ['total_count']);
      return TrashPage(
        items: items,
        totalCount: total,
        hasMore: total != null && page * perPage < total,
        canSearch: asBool(map['can_search']),
      );
    }
    final data = await _get(
      'api/v2.1/repos/$repoId/trash/',
      query: {'path': '/', if (scanStat != null) 'scan_stat': scanStat},
    );
    final map = asMap(data);
    final items = asMapList(map['data']).map(TrashEntry.fromJson).toList();
    return TrashPage(
      items: items,
      hasMore: asBool(map['more']),
      scanStat: firstString(map, ['scan_stat']),
    );
  }

  Future<void> restoreTrash(String repoId, List<TrashEntry> entries) async {
    if (entries.isEmpty) return;
    if (serverMajorVersion >= 14) {
      final byCommit = <String, List<String>>{};
      for (final entry in entries) {
        final parent = entry.parentDir ?? parentRepoPath(entry.path ?? '/');
        final path = entry.path ?? joinRepoPath(parent, entry.name);
        byCommit.putIfAbsent(entry.commitId, () => []).add(path);
      }
      await _postJson('api/v2.1/repos/$repoId/trash2/revert/', byCommit);
      return;
    }
    final groups = <String, List<String>>{};
    for (final entry in entries) {
      final parent = entry.parentDir ?? parentRepoPath(entry.path ?? '/');
      final path = entry.path ?? joinRepoPath(parent, entry.name);
      groups.putIfAbsent(entry.commitId, () => []).add(path);
    }
    for (final group in groups.entries) {
      final form = FormData();
      form.fields.add(MapEntry('commit_id', group.key));
      for (final path in group.value) {
        form.fields.add(MapEntry('path', path));
      }
      try {
        await _api.post<dynamic>(
          'api/v2.1/repos/$repoId/trash/revert-dirents/',
          data: form,
          options: Options(headers: _authHeaders),
        );
      } on DioException catch (error) {
        throw _mapError(error);
      }
    }
  }

  Future<void> emptyTrash(String repoId) async {
    await _delete('api/v2.1/repos/$repoId/trash/', query: {'keep_days': '0'});
  }

  // -------------------------------------------------------------------------
  // History

  Future<List<RepoCommit>> repoHistory(String repoId, {int page = 1, int perPage = 50}) async {
    final data = await _get(
      'api/v2.1/repos/$repoId/history/',
      query: {'page': '$page', 'per_page': '$perPage'},
    );
    final map = asMap(data);
    return asMapList(map['data'] ?? map['commits']).map(RepoCommit.fromJson).toList();
  }

  Future<List<FileVersion>> fileHistory(String repoId, String path, {int limit = 100}) async {
    try {
      final data = await _get(
        'api/v2.1/repos/$repoId/file/history/',
        query: {'path': path, 'limit': '$limit'},
      );
      final map = asMap(data);
      return asMapList(map['data'] ?? map['commits']).map(FileVersion.fromJson).toList();
    } on ApiException catch (error) {
      if (error.status != 400 && error.status != 404) rethrow;
    }
    final data = await _get(
      'api2/repos/$repoId/file/history/',
      query: {'p': path, 'page': '1', 'per_page': '$limit'},
    );
    return asMapList(asMap(data)['commits']).map(FileVersion.fromJson).toList();
  }

  Future<Uri> revisionDownloadLink(String repoId, String path, String commitId) async {
    final data = await _get(
      'api2/repos/$repoId/file/revision/',
      query: {'p': path, 'commit_id': commitId},
    );
    final raw = data is String ? data : (data is Map ? (data['url'] ?? data['download_link']) : null);
    if (raw is String && raw.isNotEmpty) return _rememberFileServer(resolveUrl(raw));
    throw ApiException(ApiErrorKind.decoding);
  }

  Future<void> revertFile(String repoId, String path, bool isDir, String commitId) async {
    final endpoint = isDir ? 'api/v2.1/repos/$repoId/dir/' : 'api/v2.1/repos/$repoId/file/';
    await _postForm(endpoint, {'operation': 'revert', 'commit_id': commitId}, query: {'p': path});
  }

  Future<void> revertRepo(String repoId, String commitId) async {
    await _postJson('api/v2.1/repos/$repoId/commits/$commitId/revert/', const {});
  }

  // -------------------------------------------------------------------------
  // Downloads

  Future<Uri> fileDownloadLink(String repoId, String path) async {
    final data = await _get(
      'api2/repos/$repoId/file/',
      query: {'p': path, 'reuse': '1'},
    );
    final raw = data is String ? data : (data is Map ? (data['url'] ?? data['download_link']) : null);
    if (raw is String && raw.isNotEmpty) return _rememberFileServer(resolveUrl(raw));
    throw ApiException(ApiErrorKind.decoding);
  }

  Future<Uri> zipTask(String repoId, String parentDir, List<String> dirents) async {
    final form = FormData();
    form.fields.add(MapEntry('parent_dir', parentDir));
    for (final dirent in dirents) {
      form.fields.add(MapEntry('dirents', dirent));
    }
    dynamic data;
    try {
      final response = await _api.post<dynamic>(
        'api/v2.1/repos/$repoId/zip-task/',
        data: form,
        options: Options(headers: _authHeaders),
      );
      data = response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
    final token = firstString(asMap(data), ['zip_token']);
    if (token == null || token.isEmpty) throw ApiException(ApiErrorKind.decoding);
    return Uri.parse('${_fileServerBase()}/zip/$token');
  }

  Future<void> downloadUrlToFile(
    Uri url,
    String savePath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _transfer.download(
        url.toString(),
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(hours: 2)),
      );
    } on DioException catch (error) {
      await _deleteIfExists(savePath);
      throw _mapError(error);
    }
  }

  Future<void> downloadFile(
    String repoId,
    String path,
    String savePath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final link = await fileDownloadLink(repoId, path);
    await downloadUrlToFile(link, savePath, onProgress: onProgress, cancelToken: cancelToken);
  }

  // -------------------------------------------------------------------------
  // Uploads

  Future<Uri> uploadLink(String repoId, String dirPath) async {
    final data = await _get('api2/repos/$repoId/upload-link/', query: {'p': dirPath});
    final raw = data is String ? data : (data is Map ? data['url'] : null);
    if (raw is String && raw.isNotEmpty) return _rememberFileServer(resolveUrl(raw), upload: true);
    throw ApiException(ApiErrorKind.decoding);
  }

  Future<void> uploadFile({
    required String repoId,
    required String dirPath,
    required String filePath,
    required String fileName,
    bool replace = false,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final link = await uploadLink(repoId, dirPath);
    final file = File(filePath);
    final length = await file.length();
    final form = FormData.fromMap({
      'parent_dir': dirPath,
      'file_name': fileName,
      'file_size': '$length',
      'ret-json': '1',
      'last_modify': _isoTimestamp(file.lastModifiedSync()),
      'csrfmiddlewaretoken': _csrfToken,
      if (replace) 'replace': '1',
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    try {
      await _transfer.post<dynamic>(
        link.toString(),
        data: form,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(sendTimeout: const Duration(hours: 2), receiveTimeout: const Duration(hours: 2)),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // -------------------------------------------------------------------------
  // Share links

  Future<List<ShareLink>> shareLinks({String? repoId, String? path, int page = 1, int perPage = 100}) async {
    final data = await _get(
      'api/v2.1/share-links/',
      query: {
        if (repoId != null) 'repo_id': repoId,
        if (path != null) 'path': path,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
    final raw = data is Map ? (data['share_links'] ?? data['links']) : data;
    return asMapList(raw).map(ShareLink.fromJson).toList();
  }

  Future<List<SharedAccess>> sharedAccess(String repoId, String path) async {
    final result = <SharedAccess>[];
    for (final type in ['user', 'group']) {
      final data = await _get(
        'api2/repos/$repoId/dir/shared_items/',
        query: {'p': path, 'share_type': type},
      );
      final raw = data is Map ? (data['data'] ?? data['shared_items'] ?? []) : data;
      for (final item in asMapList(raw)) {
        final access = SharedAccess.fromJson(item, type: type);
        if (access.id.isNotEmpty) result.add(access);
      }
    }
    return result;
  }

  Future<({List<String> success, List<String> failed})> shareAccess({
    required String repoId,
    required String path,
    required String type,
    required List<String> ids,
    String permission = 'rw',
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('share_type', type));
    form.fields.add(MapEntry('permission', permission));
    for (final id in ids) {
      form.fields.add(MapEntry(type == 'user' ? 'username' : 'group_id', id));
    }
    try {
      final response = await _api.put<dynamic>(
        'api2/repos/$repoId/dir/shared_items/',
        queryParameters: {'p': path},
        data: form,
        options: Options(headers: _authHeaders),
      );
      final map = asMap(response.data);
      final success = asMapList(map['success']);
      final failed = asMapList(map['failed']);
      return (
        success: success.map((item) {
          if (type == 'user') {
            return firstString(item, ['user_email', 'email']) ?? firstString(asMap(item['user_info']), ['name']) ?? '';
          }
          return firstString(item, ['group_id', 'id']) ?? firstString(asMap(item['group_info']), ['id']) ?? '';
        }).where((id) => id.isNotEmpty).toList(),
        failed: failed.map((item) => item.toString()).toList(),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> removeSharedAccess(String repoId, String path, String type, String id) async {
    try {
      await _api.delete<dynamic>(
        'api2/repos/$repoId/dir/shared_items/',
        queryParameters: {
          'p': path,
          'share_type': type,
          if (type == 'user') 'username': id else 'group_id': id,
        },
        options: Options(headers: _authHeaders),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<List<ShareableGroup>> shareableGroups() async {
    final data = await _get('api/v2.1/shareable-groups/');
    final raw = data is Map ? (data['groups'] ?? data['data'] ?? []) : data;
    return asMapList(raw).map(ShareableGroup.fromJson).where((group) => group.id.isNotEmpty).toList();
  }

  Future<ShareLink> createShareLink({
    required String repoId,
    required String path,
    String? password,
    DateTime? expireDate,
    bool canDownload = true,
    bool canUpload = false,
    bool canEdit = false,
  }) async {
    final permissions = jsonEncode({'can_download': canDownload, 'can_upload': canUpload, 'can_edit': canEdit});
    final data = await _postForm('api/v2.1/share-links/', {
      'repo_id': repoId,
      'path': path,
      'permissions': permissions,
      if (password != null && password.isNotEmpty) 'password': password,
      if (expireDate != null) 'expiration_time': expireDate.toUtc().toIso8601String(),
    });
    final link = ShareLink.fromJson(asMap(data));
    if (link.link.isEmpty && link.token.isNotEmpty) {
      return ShareLink(
        token: link.token,
        link: '$serverBase/d/${link.token}/',
        path: link.path,
        repoId: link.repoId,
        hasPassword: link.hasPassword,
        expireDate: link.expireDate,
      );
    }
    return link;
  }

  Future<void> deleteShareLink(String token) async {
    await _delete('api/v2.1/share-links/$token/');
  }

  Future<List<ActivityEvent>> activities({int page = 1}) async {
    final data = await _get('api/v2.1/activities/', query: {'page': '$page'});
    return asMapList(asMap(data)['events']).map(ActivityEvent.fromJson).toList();
  }

  Future<List<DeletedLibrary>> deletedLibraries() async {
    final data = await _get('api/v2.1/deleted-repos/');
    return asMapList(data).map(DeletedLibrary.fromJson).where((repo) => repo.id.isNotEmpty).toList();
  }

  Future<void> restoreDeletedLibrary(String repoId) async {
    await _postForm('api/v2.1/deleted-repos/', {'repo_id': repoId});
  }

  Future<void> cleanDeletedLibraries() async {
    await _delete('api/v2.1/deleted-repos/');
  }

  // -------------------------------------------------------------------------
  // Search

  Future<List<SearchResult>> globalSearch(String keyword, {String? repoScope, int perPage = 100}) async {
    final data = await _get(
      'api2/search/',
      query: {
        'q': keyword,
        'per_page': '$perPage',
        if (repoScope != null) 'search_repo': repoScope,
      },
    );
    final raw = asMap(data)['results'] ?? data;
    return asMapList(raw).map(SearchResult.fromJson).toList();
  }

  Future<List<SearchResult>> searchInRepo(String repoId, String keyword) async {
    final data = await _get(
      'api/v2.1/search-file/',
      query: {'repo_id': repoId, 'q': keyword},
    );
    final raw = asMap(data)['data'] ?? data;
    return asMapList(raw).map((item) {
      final path = firstString(item, ['path']) ?? '';
      return SearchResult(
        repoId: repoId,
        repoName: '',
        path: path,
        name: baseName(path),
        isDir: (firstString(item, ['type']) ?? 'file') == 'dir',
        size: firstInt(item, ['size']) ?? 0,
        mtime: firstDate(item, ['mtime']),
      );
    }).toList();
  }

  // -------------------------------------------------------------------------
  // Thumbnails

  Future<Uint8List> thumbnail(String repoId, String path, {int size = 256}) async {
    if (serverMajorVersion >= 14) {
      try {
        final response = await _api.get<List<int>>(
          'thumbnail/$repoId/$size/${encodeRepoPath(path).replaceFirst(RegExp(r'^/'), '')}',
          options: Options(responseType: ResponseType.bytes, headers: _authHeaders),
        );
        return Uint8List.fromList(response.data ?? const []);
      } on DioException {
        // fall back to the legacy endpoint below
      }
    }
    try {
      final response = await _api.get<List<int>>(
        'api2/repos/$repoId/thumbnail/',
        queryParameters: {'size': '$size', 'p': path},
        options: Options(responseType: ResponseType.bytes, headers: _authHeaders),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  // -------------------------------------------------------------------------
  // Starred items

  Future<List<StarredItem>> starredItems() async {
    final data = await _get('api/v2.1/starred-items/');
    final raw = data is Map ? (data['starred_item_list'] ?? data['items']) : data;
    return asMapList(raw).map(StarredItem.fromJson).toList();
  }

  Future<void> setStarred({required String repoId, required String path, required bool starred}) async {
    if (starred) {
      await _postForm('api/v2.1/starred-items/', {'repo_id': repoId, 'path': path});
    } else {
      await _delete('api/v2.1/starred-items/', query: {'repo_id': repoId, 'path': path});
    }
  }

  // -------------------------------------------------------------------------
  // Metadata & tags

  Future<MetadataStatus> metadataStatus(String repoId) async {
    final data = await _get('api/v2.1/repos/$repoId/metadata/');
    return MetadataStatus.fromJson(asMap(data));
  }

  Future<void> setMetadataEnabled(String repoId, bool enabled) async {
    if (enabled) {
      await _put('api/v2.1/repos/$repoId/metadata/');
    } else {
      await _delete('api/v2.1/repos/$repoId/metadata/');
    }
  }

  Future<void> setTagsEnabled(String repoId, bool enabled) async {
    if (enabled) {
      await _put('api/v2.1/repos/$repoId/metadata/tags-status/');
    } else {
      await _delete('api/v2.1/repos/$repoId/metadata/tags-status/');
    }
  }

  Future<void> setSummaryEnabled(String repoId, bool enabled) async {
    if (enabled) {
      await _postForm('api/v2.1/repos/$repoId/metadata/summary-status/', const {});
    } else {
      await _delete('api/v2.1/repos/$repoId/metadata/summary-status/');
    }
  }

  Future<List<TagInfo>> tags(String repoId) async {
    final data = await _get(
      'api/v2.1/repos/$repoId/metadata/tags/',
      query: {'start': '0', 'limit': '1000'},
    );
    return asMapList(asMap(data)['results']).map(TagInfo.fromJson).where((tag) => tag.id.isNotEmpty).toList();
  }

  Future<TagInfo> createTag(String repoId, String name, String color) async {
    final data = await _postJson('api/v2.1/repos/$repoId/metadata/tags/', {
      'tags_data': [
        {'_tag_name': name, '_tag_color': color},
      ],
    });
    if (data is Map) {
      final tags = asMapList(data['tags']).map(TagInfo.fromJson).toList();
      if (tags.isNotEmpty) return tags.first;
    }
    throw ApiException(ApiErrorKind.decoding);
  }

  Future<void> updateFileTags(String repoId, String recordId, List<String> tagIds) async {
    await _putJson('api/v2.1/repos/$repoId/metadata/file-tags/', {
      'file_tags_data': [
        {'record_id': recordId, 'tags': tagIds},
      ],
    });
  }

  Future<MetadataRecord?> record(
    String repoId, {
    String? parentDir,
    String? fileName,
    String? recordId,
  }) async {
    final data = await _get(
      'api/v2.1/repos/$repoId/metadata/record/',
      query: {
        if (recordId != null) 'record_id': recordId,
        if (recordId == null && parentDir != null) 'parent_dir': parentDir,
        if (recordId == null && fileName != null) 'file_name': fileName,
        if (recordId == null) 'fallback_to_basic_info': 'true',
      },
    );
    final results = asMapList(asMap(data)['results']);
    if (results.isEmpty) return null;
    return MetadataRecord.fromJson(results.first);
  }

  Future<List<MetadataRecord>> records(String repoId, List<MapEntry<String, String>> files) async {
    if (files.isEmpty) return const [];
    final data = await _postJson('api/v2.1/repos/$repoId/metadata/batch-records/', {
      'files': files.map((file) => {'parent_dir': file.key, 'file_name': file.value}).toList(),
    });
    final raw = data is Map ? (data['results'] ?? data['data']) : data;
    final list = asMapList(raw).map(MetadataRecord.fromJson).toList();
    if (list.isNotEmpty) return list;
    final recordData = asMap(data)['records'];
    if (recordData is List) {
      return asMapList(recordData).map(MetadataRecord.fromJson).toList();
    }
    return const [];
  }

  Future<void> updateRecord(
    String repoId,
    MetadataRecord record,
    Map<String, dynamic> data,
  ) async {
    await _putJson('api/v2.1/repos/$repoId/metadata/record/', {
      'record_id': record.recordId,
      'data': data,
    });
  }

  Future<void> setGlobalHiddenColumns(String repoId, List<String> columns) async {
    await _putJson('api/v2.1/repos/$repoId/metadata/global-hidden-columns/', {
      'global_hidden_columns': columns,
    });
  }

  Future<List<Map<String, dynamic>>> metadataViews(String repoId) async {
    final data = await _get('api/v2.1/repos/$repoId/metadata/views/');
    return asMapList(asMap(data)['views']);
  }

  // -------------------------------------------------------------------------
  // AI chat

  Future<bool> aiAvailable(String repoId) async {
    try {
      await listChatSessions(repoId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AiChatSession>> listChatSessions(String repoId) async {
    final data = await _get('api/v2.1/ai/chat/sessions/', query: {'repo_id': repoId});
    return asMapList(asMap(data)['sessions']).map(AiChatSession.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<AiChatSession> createChatSession(String repoId, String name) async {
    final data = await _postJson('api/v2.1/ai/chat/sessions/', {
      'repo_id': repoId,
      'session_name': name,
    });
    final session = asMap(asMap(data)['session']);
    final parsed = AiChatSession.fromJson(session);
    if (parsed.id.isEmpty) throw ApiException(ApiErrorKind.decoding);
    return parsed;
  }

  Future<List<Map<String, dynamic>>> chatMessages(String sessionId) async {
    final data = await _get('api/v2.1/ai/chat/sessions/$sessionId/messages/');
    return asMapList(asMap(data)['messages'] ?? asMap(data)['data']);
  }

  Stream<AiChatEvent> sendChat({
    required String repoId,
    required String query,
    required String sessionId,
    List<Map<String, dynamic>> attachments = const [],
    String? model,
    CancelToken? cancelToken,
  }) async* {
    Response<ResponseBody> response;
    try {
      response = await _api.post<ResponseBody>(
        'api/v2.1/ai/chat/',
        data: {
          'repo_id': repoId,
          'query': query,
          'session_uuid': sessionId,
          'attachments': attachments,
          if (model != null) 'model': model,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            ..._authHeaders,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(minutes: 10),
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
    final body = response.data;
    if (body == null) return;
    final buffer = StringBuffer();
    await for (final chunk in body.stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      var content = buffer.toString();
      while (true) {
        final index = content.indexOf('\n');
        if (index < 0) break;
        final line = content.substring(0, index).trimRight();
        content = content.substring(index + 1);
        final event = _parseSseLine(line);
        if (event != null) {
          yield event;
          if (event.done) return;
        }
      }
      buffer
        ..clear()
        ..write(content);
    }
    final trailing = _parseSseLine(buffer.toString().trim());
    if (trailing != null) yield trailing;
  }

  AiChatEvent? _parseSseLine(String line) {
    if (!line.startsWith('data:')) return null;
    final data = line.substring(5).trim();
    if (data.isEmpty) return null;
    if (data == '[DONE]') return const AiChatEvent(done: true);
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final statusMap = asMap(map['status']);
        return AiChatEvent(
          answer: asString(map['answer']),
          status: firstString(statusMap, ['type', 'detail']),
          searchFound: firstInt(map, ['search_found']),
          done: false,
          raw: map,
        );
      }
    } catch (_) {}
    return AiChatEvent(answer: data);
  }

  Future<void> deleteChatSession(String sessionId) async {
    await _delete('api/v2.1/ai/chat/sessions/$sessionId/');
  }

  // -------------------------------------------------------------------------
  // Plumbing

  Uri resolveUrl(String raw) {
    final text = raw.trim();
    final parsed = Uri.tryParse(text);
    if (parsed != null && parsed.hasScheme) return parsed;
    if (text.startsWith('//')) return Uri.parse('${serverUri.scheme}:$text');
    if (text.startsWith('/')) {
      return Uri(
        scheme: serverUri.scheme,
        host: serverUri.host,
        port: serverUri.hasPort ? serverUri.port : null,
        path: text,
      );
    }
    return serverUri.resolve(text);
  }

  Uri _rememberFileServer(Uri url, {bool upload = false}) {
    final path = url.path;
    for (final marker in upload ? ['/upload-api/'] : ['/files/', '/revision/']) {
      final index = path.indexOf(marker);
      if (index > 0) {
        _fileServerRoot = Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null, path: path.substring(0, index))
            .toString();
        break;
      }
    }
    return url;
  }

  String _fileServerBase() {
    final cached = _fileServerRoot;
    if (cached != null && cached.isNotEmpty) return cached;
    return Uri(
      scheme: serverUri.scheme,
      host: serverUri.host,
      port: serverUri.hasPort ? serverUri.port : null,
      path: '/seafhttp',
    ).toString();
  }

  String _isoTimestamp(DateTime value) => value.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _api.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: _authHeaders),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> _postForm(
    String path,
    Map<String, dynamic> form, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        path,
        data: form,
        queryParameters: query,
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: _authHeaders),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> _postJson(String path, Object? body) async {
    try {
      final response = await _api.post<dynamic>(
        path,
        data: body,
        options: Options(headers: {..._authHeaders, 'Content-Type': 'application/json'}),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> _put(String path) async {
    try {
      final response = await _api.put<dynamic>(
        path,
        options: Options(headers: _authHeaders),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> _putJson(String path, Object? body) async {
    try {
      final response = await _api.put<dynamic>(
        path,
        data: body,
        options: Options(headers: {..._authHeaders, 'Content-Type': 'application/json'}),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> _delete(String path, {Map<String, dynamic>? query}) async {
    try {
      await _api.delete<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: _authHeaders),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode ?? 0;
      final otpRequired = response.headers.value('x-seafile-otp')?.toLowerCase() == 'required';
      final message = extractMessage(response.data);
      if (status == 400 && otpRequired) {
        return ApiException(ApiErrorKind.twoFactorRequired, status: status, serverMessage: message);
      }
      switch (status) {
        case 400:
          return ApiException(ApiErrorKind.unknown, status: status, serverMessage: message);
        case 401:
          if (token != null && token!.isNotEmpty) onUnauthorized?.call();
          return ApiException(ApiErrorKind.unauthorized, status: status, serverMessage: message);
        case 403:
          return ApiException(ApiErrorKind.forbidden, status: status, serverMessage: message);
        case 404:
          return ApiException(ApiErrorKind.notFound, status: status, serverMessage: message);
        case 440:
          return ApiException(ApiErrorKind.repoPasswordRequired, status: status, serverMessage: message);
        default:
          if (status >= 500) {
            return ApiException(ApiErrorKind.server, status: status, serverMessage: message);
          }
          return ApiException(ApiErrorKind.unknown, status: status, serverMessage: message);
      }
    }
    if (error.type == DioExceptionType.cancel) return ApiException(ApiErrorKind.cancelled);
    if (error.error is SocketException ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ApiException(ApiErrorKind.network);
    }
    return ApiException(ApiErrorKind.unknown, serverMessage: error.message);
  }

  static String? extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      for (final key in ['error_msg', 'error', 'detail', 'message']) {
        final value = asString(data[key]);
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
      for (final key in ['non_field_errors', 'errors']) {
        final value = data[key];
        if (value is List) {
          final strings = value.whereType<String>().where((item) => item.trim().isNotEmpty);
          if (strings.isNotEmpty) return strings.join('\n');
        }
      }
      return null;
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed.length > 500) return null;
      final lower = trimmed.toLowerCase();
      if (lower.contains('<!doctype') || lower.contains('<html')) return null;
      return trimmed;
    }
    return null;
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void close() {
    _api.close(force: true);
    _transfer.close(force: true);
  }
}
