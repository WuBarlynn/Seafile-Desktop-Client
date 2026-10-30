import 'dart:convert';

import '../core/format.dart';
import 'json_utils.dart';

class AccountInfo {
  const AccountInfo({
    this.email,
    this.name,
    this.usage,
    this.totalQuota,
    this.department,
  });

  final String? email;
  final String? name;
  final int? usage;
  final int? totalQuota;
  final String? department;

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      email: firstString(json, ['email', 'username']),
      name: firstString(json, ['name', 'contact_email']),
      usage: firstInt(json, ['usage']),
      totalQuota: firstInt(json, ['total', 'quota_total']),
      department: firstString(json, ['department']),
    );
  }

  bool get hasQuota => totalQuota != null && totalQuota! > 0;

  double? get usageFraction {
    if (!hasQuota || usage == null) return null;
    return (usage! / totalQuota!).clamp(0.0, 1.0);
  }

  static bool isInternalAddress(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    return lower.contains('@auth.local') ||
        lower.contains('@seafile-sso') ||
        lower.endsWith('@seafile.local') ||
        lower.endsWith('@seafile-sso.local');
  }

  String displayName(String? fallbackUsername) {
    final candidate = name?.trim();
    if (candidate != null && candidate.isNotEmpty && !isInternalAddress(candidate)) {
      return candidate;
    }
    final emailValue = email?.trim();
    if (emailValue != null && emailValue.isNotEmpty && !isInternalAddress(emailValue)) {
      return emailValue;
    }
    final username = fallbackUsername?.trim();
    if (username != null && username.isNotEmpty) {
      final local = username.split('@').first;
      return local.isEmpty ? username : local;
    }
    return '';
  }

  String subtitle(String? fallbackUsername) {
    final emailValue = email?.trim();
    if (emailValue != null && emailValue.isNotEmpty && !isInternalAddress(emailValue)) {
      return emailValue;
    }
    return fallbackUsername ?? '';
  }
}

class ServerInfo {
  const ServerInfo({this.version, this.features = const []});

  final String? version;
  final List<String> features;

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      version: asString(json['version']),
      features: asStringList(json['features']),
    );
  }

  bool get isPro => features.contains('seafile-pro');
  bool get supportsSearch => features.contains('file-search');
  bool get supportsWiki => features.contains('wiki');

  bool atLeast(String minimum) {
    final current = _versionParts(version);
    final target = _versionParts(minimum);
    final length = current.length > target.length ? current.length : target.length;
    for (var i = 0; i < length; i++) {
      final left = i < current.length ? current[i] : 0;
      final right = i < target.length ? target[i] : 0;
      if (left != right) return left > right;
    }
    return true;
  }

  static List<int> _versionParts(String? value) {
    if (value == null) return const [];
    return value
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}

class Repository {
  const Repository({
    required this.id,
    required this.name,
    this.owner,
    this.ownerName,
    this.ownerContactEmail,
    this.permission,
    this.kind = 'mine',
    this.size = 0,
    this.mtime,
    this.encrypted = false,
    this.encVersion = 0,
    this.magic,
    this.randomKey,
    this.salt,
    this.groupName,
    this.groupId,
    this.isAdmin = false,
    this.libNeedDecrypt = false,
    this.starred = false,
    this.fileCount = 0,
    this.enableOnlyOffice = false,
  });

  final String id;
  final String name;
  final String? owner;
  final String? ownerName;
  final String? ownerContactEmail;
  final String? permission;
  final String kind;
  final int size;
  final DateTime? mtime;
  final bool encrypted;
  final int encVersion;
  final String? magic;
  final String? randomKey;
  final String? salt;
  final String? groupName;
  final int? groupId;
  final bool isAdmin;
  final bool libNeedDecrypt;
  final bool starred;
  final int fileCount;
  final bool enableOnlyOffice;

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      id: firstString(json, ['id', 'repo_id']) ?? '',
      name: firstString(json, ['name', 'repo_name']) ?? '',
      owner: firstString(json, ['owner', 'owner_email']),
      ownerName: firstString(json, ['owner_name']),
      ownerContactEmail: firstString(json, ['owner_contact_email']),
      permission: firstString(json, ['permission']),
      kind: (firstString(json, ['type']) ?? 'mine').toLowerCase(),
      size: firstInt(json, ['size']) ?? 0,
      mtime: firstDate(json, ['mtime', 'last_modified', 'modified']),
      encrypted: asBool(json['encrypted']),
      encVersion: firstInt(json, ['enc_version']) ?? 0,
      magic: firstString(json, ['magic']),
      randomKey: firstString(json, ['random_key']),
      salt: firstString(json, ['salt']),
      groupName: firstString(json, ['group_name']),
      groupId: firstInt(json, ['group_id']),
      isAdmin: asBool(json['is_admin']),
      libNeedDecrypt: asBool(json['lib_need_decrypt']),
      starred: asBool(json['starred']),
      fileCount: firstInt(json, ['file_count']) ?? 0,
      enableOnlyOffice: asBool(json['enable_onlyoffice']),
    );
  }

  bool get isReadOnly => (permission ?? '').toLowerCase() == 'r';
  bool get isOwner => kind == 'mine' || isAdmin;

  String get ownerDisplay {
    final contact = ownerContactEmail?.trim();
    if (contact != null && contact.isNotEmpty && !AccountInfo.isInternalAddress(contact)) return contact;
    final name = ownerName?.trim();
    if (name != null && name.isNotEmpty && !AccountInfo.isInternalAddress(name)) return name;
    final email = owner?.trim();
    if (email != null && email.isNotEmpty && !AccountInfo.isInternalAddress(email)) return email;
    if (name != null && name.isNotEmpty) return name;
    return email ?? '';
  }
  bool get isGroup => kind == 'group';
  bool get isShared => kind == 'shared';

  String kindTitle(bool zh) {
    if (isShared) return zh ? '共享给我的' : 'Shared with me';
    if (isGroup) return groupName?.isNotEmpty == true ? groupName! : (zh ? '群组资料库' : 'Group libraries');
    if (kind == 'public') return zh ? '公开资料库' : 'Public library';
    if (kind == 'mine') return zh ? '我的资料库' : 'My libraries';
    return zh ? '其他资料库' : 'Other libraries';
  }
}

class RepoSection {
  const RepoSection({required this.id, required this.title, required this.repos, this.subtitle});

  final String id;
  final String title;
  final String? subtitle;
  final List<Repository> repos;
}

class Dirent {
  const Dirent({
    required this.name,
    required this.path,
    required this.isDir,
    this.oid,
    this.size = 0,
    this.mtime,
    this.permission,
    this.thumbnailPath,
    this.modifierName,
    this.starred = false,
    this.locked = false,
  });

  final String name;
  final String path;
  final bool isDir;
  final String? oid;
  final int size;
  final DateTime? mtime;
  final String? permission;
  final String? thumbnailPath;
  final String? modifierName;
  final bool starred;
  final bool locked;

  factory Dirent.fromJson(Map<String, dynamic> json, String parentPath) {
    final name = firstString(json, ['name', 'obj_name']) ?? '';
    final type = firstString(json, ['type']) ?? 'file';
    return Dirent(
      name: name,
      path: joinRepoPath(parentPath, name),
      isDir: type == 'dir' || type == 'folder' || asBool(json['is_dir']),
      oid: firstString(json, ['id', 'oid']),
      size: firstInt(json, ['size']) ?? 0,
      mtime: firstDate(json, ['mtime', 'last_modified']),
      permission: firstString(json, ['permission']),
      thumbnailPath: firstString(json, ['encoded_thumbnail_src', 'thumbnail_src']),
      modifierName: firstString(json, ['modifier_name', 'modifier_contact_email']),
      starred: asBool(json['starred']),
      locked: asBool(json['is_locked']),
    );
  }

  bool get isReadOnly => (permission ?? '').toLowerCase() == 'r';

  String get versionKey => '${oid ?? ''}:${mtime?.millisecondsSinceEpoch ?? 0}:$size';
}

class Commit {
  const Commit({
    required this.id,
    this.ctime,
    this.creator,
    this.creatorName,
    this.description,
    this.size,
  });

  final String id;
  final DateTime? ctime;
  final String? creator;
  final String? creatorName;
  final String? description;
  final int? size;

  factory Commit.fromJson(Map<String, dynamic> json) {
    return Commit(
      id: firstString(json, ['commit_id', 'id', 'oid']) ?? '',
      ctime: firstDate(json, ['ctime', 'time', 'mtime']),
      creator: firstString(json, ['creator', 'creator_email', 'email']),
      creatorName: firstString(json, ['creator_name', 'name']),
      description: firstString(json, ['desc', 'description', 'commit_desc']),
      size: firstInt(json, ['size']),
    );
  }

  String authorLabel(String? fallback) {
    final name = creatorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = creator?.trim();
    if (email != null && email.isNotEmpty) return email;
    return fallback ?? '';
  }
}

class TrashEntry {
  const TrashEntry({
    required this.commitId,
    required this.name,
    this.path,
    this.isDir = false,
    this.size = 0,
    this.deletedAt,
    this.deletedBy,
    this.originalPath,
    this.parentDir,
  });

  final String commitId;
  final String name;
  final String? path;
  final bool isDir;
  final int size;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? originalPath;
  final String? parentDir;

  factory TrashEntry.fromJson(Map<String, dynamic> json) {
    final type = firstString(json, ['type', 'obj_type']) ?? 'file';
    final name = firstString(json, ['obj_name', 'name']) ?? '';
    final path = firstString(json, ['path', 'parent_dir']) ??
        (firstString(json, ['parent_path']) != null
            ? joinRepoPath(firstString(json, ['parent_path'])!, name)
            : null);
    return TrashEntry(
      commitId: firstString(json, ['commit_id', 'id', 'oid']) ?? '',
      name: name,
      path: path,
      isDir: type == 'dir' || type == 'folder' || asBool(json['is_dir']),
      size: firstInt(json, ['size']) ?? 0,
      deletedAt: firstDate(json, ['deleted_time', 'ctime', 'delete_time', 'mtime']),
      deletedBy: firstString(json, ['deleted_by', 'creator_name', 'creator']),
      originalPath: firstString(json, ['original_path']),
      parentDir: firstString(json, ['parent_dir', 'parent_path']),
    );
  }
}

class ShareLink {
  const ShareLink({
    required this.token,
    required this.link,
    this.path,
    this.repoId,
    this.hasPassword = false,
    this.expireDate,
    this.permissions,
    this.isDir = false,
    this.isExpired = false,
    this.objName,
    this.createdAt,
    this.repoName,
  });

  final String token;
  final String link;
  final String? path;
  final String? repoId;
  final bool hasPassword;
  final DateTime? expireDate;
  final Map<String, dynamic>? permissions;
  final bool isDir;
  final bool isExpired;
  final String? objName;
  final DateTime? createdAt;
  final String? repoName;

  factory ShareLink.fromJson(Map<String, dynamic> json) {
    final token = firstString(json, ['token', 'link_token']) ?? '';
    final rawLink = firstString(json, ['link', 'share_link', 'url']) ?? '';
    return ShareLink(
      token: token,
      link: rawLink,
      path: firstString(json, ['path']),
      repoId: firstString(json, ['repo_id']),
      hasPassword: asBool(json['password']),
      expireDate: firstDate(json, ['expire_date', 'expire_time']),
      permissions: json['permissions'] is Map ? asMap(json['permissions']) : null,
      isDir: asBool(json['is_dir']),
      isExpired: asBool(json['is_expired']),
      objName: firstString(json, ['obj_name']),
      createdAt: firstDate(json, ['ctime', 'created_at']),
      repoName: firstString(json, ['repo_name']),
    );
  }

  String linkForServer(String serverBase) {
    if (link.startsWith('http://') || link.startsWith('https://')) return link;
    final base = serverBase.endsWith('/') ? serverBase.substring(0, serverBase.length - 1) : serverBase;
    return '$base${link.startsWith('/') ? '' : '/'}$link';
  }
}

class SearchResult {
  const SearchResult({
    required this.repoId,
    required this.repoName,
    required this.path,
    required this.name,
    this.isDir = false,
    this.size = 0,
    this.mtime,
  });

  final String repoId;
  final String repoName;
  final String path;
  final String name;
  final bool isDir;
  final int size;
  final DateTime? mtime;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final path = firstString(json, ['path', 'full_path']) ?? '';
    return SearchResult(
      repoId: firstString(json, ['repo_id']) ?? '',
      repoName: firstString(json, ['repo_name', 'library']) ?? '',
      path: path,
      name: firstString(json, ['name', 'obj_name']) ?? baseName(path),
      isDir: (firstString(json, ['type']) ?? 'file') == 'dir',
      size: firstInt(json, ['size']) ?? 0,
      mtime: firstDate(json, ['mtime', 'last_modified', 'time']),
    );
  }
}

class FileDetail {
  const FileDetail({this.size, this.mtime, this.oid, this.permission});

  final int? size;
  final DateTime? mtime;
  final String? oid;
  final String? permission;

  factory FileDetail.fromJson(Map<String, dynamic> json) {
    return FileDetail(
      size: firstInt(json, ['size']),
      mtime: firstDate(json, ['mtime', 'last_modified']),
      oid: firstString(json, ['id', 'oid']),
      permission: firstString(json, ['permission']),
    );
  }
}

class RepoPasswordInfo {
  const RepoPasswordInfo({
    required this.encrypted,
    required this.version,
    this.magic,
    this.randomKey,
    this.salt,
  });

  final bool encrypted;
  final int version;
  final String? magic;
  final String? randomKey;
  final String? salt;

  factory RepoPasswordInfo.fromJson(Map<String, dynamic> json) {
    return RepoPasswordInfo(
      encrypted: asBool(json['encrypted']),
      version: firstInt(json, ['enc_version']) ?? 0,
      magic: firstString(json, ['magic']),
      randomKey: firstString(json, ['random_key']),
      salt: firstString(json, ['salt']),
    );
  }
}

class TrashPage {
  const TrashPage({required this.items, this.totalCount, this.hasMore = false, this.scanStat, this.canSearch = false});

  final List<TrashEntry> items;
  final int? totalCount;
  final bool hasMore;
  final String? scanStat;
  final bool canSearch;
}

class RepoCommit {
  const RepoCommit({
    required this.commitId,
    this.time,
    this.description,
    this.authorName,
    this.authorEmail,
    this.tags = const [],
  });

  final String commitId;
  final DateTime? time;
  final String? description;
  final String? authorName;
  final String? authorEmail;
  final List<String> tags;

  factory RepoCommit.fromJson(Map<String, dynamic> json) {
    return RepoCommit(
      commitId: firstString(json, ['commit_id', 'id']) ?? '',
      time: firstDate(json, ['time', 'ctime']),
      description: firstString(json, ['description', 'desc']),
      authorName: firstString(json, ['name', 'creator_name']),
      authorEmail: firstString(json, ['contact_email', 'creator_contact_email', 'email', 'creator']),
      tags: asStringList(json['tags']),
    );
  }
}

class FileVersion {
  const FileVersion({
    required this.commitId,
    this.time,
    this.authorName,
    this.authorEmail,
    this.description,
    this.size,
    this.path,
  });

  final String commitId;
  final DateTime? time;
  final String? authorName;
  final String? authorEmail;
  final String? description;
  final int? size;
  final String? path;

  factory FileVersion.fromJson(Map<String, dynamic> json) {
    return FileVersion(
      commitId: firstString(json, ['commit_id', 'id']) ?? '',
      time: firstDate(json, ['ctime', 'time']),
      authorName: firstString(json, ['creator_name', 'name']),
      authorEmail: firstString(json, ['creator_contact_email', 'creator_email', 'creator']),
      description: firstString(json, ['description', 'desc']),
      size: firstInt(json, ['size', 'rev_file_size']),
      path: firstString(json, ['path']),
    );
  }
}

class StarredItem {
  const StarredItem({
    required this.repoId,
    required this.repoName,
    required this.path,
    this.isDir = false,
    this.size = 0,
    this.mtime,
  });

  final String repoId;
  final String repoName;
  final String path;
  final bool isDir;
  final int size;
  final DateTime? mtime;

  factory StarredItem.fromJson(Map<String, dynamic> json) {
    final path = firstString(json, ['path', 'obj_path']) ?? '/';
    return StarredItem(
      repoId: firstString(json, ['repo_id']) ?? '',
      repoName: firstString(json, ['repo_name']) ?? '',
      path: path,
      isDir: asBool(json['is_dir']),
      size: firstInt(json, ['size']) ?? 0,
      mtime: firstDate(json, ['mtime', 'last_modified']),
    );
  }

  String get name => path == '/' ? repoName : baseName(path);
}

class TagInfo {
  const TagInfo({required this.id, required this.name, this.color = '#FF8000'});

  final String id;
  final String name;
  final String color;

  factory TagInfo.fromJson(Map<String, dynamic> json) {
    return TagInfo(
      id: firstString(json, ['_id', 'id']) ?? '',
      name: firstString(json, ['_tag_name', 'name']) ?? '',
      color: firstString(json, ['_tag_color', 'color']) ?? '#FF8000',
    );
  }
}

class MetadataStatus {
  const MetadataStatus({
    this.enabled = false,
    this.tagsEnabled = false,
    this.summaryEnabled = false,
    this.showView = false,
    this.faceRecognitionEnabled = false,
    this.detailsSettings = const {},
    this.hiddenColumns = const [],
  });

  final bool enabled;
  final bool tagsEnabled;
  final bool summaryEnabled;
  final bool showView;
  final bool faceRecognitionEnabled;
  final Map<String, dynamic> detailsSettings;
  final List<String> hiddenColumns;

  factory MetadataStatus.fromJson(Map<String, dynamic> json) {
    return MetadataStatus(
      enabled: asBool(json['enabled']),
      tagsEnabled: asBool(json['tags_enabled']),
      summaryEnabled: asBool(json['summary_enabled']),
      showView: asBool(json['show_view']),
      faceRecognitionEnabled: asBool(json['face_recognition_enabled']),
      detailsSettings: _decodeMap(json['details_settings']),
      hiddenColumns: asStringList(json['global_hidden_columns']),
    );
  }

  static Map<String, dynamic> _decodeMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return const {};
  }
}

class MetadataRecord {
  const MetadataRecord({
    required this.recordId,
    this.parentDir,
    this.name,
    this.isDir = false,
    this.size = 0,
    this.mtime,
    this.tags = const [],
    this.aiSummary,
    this.values = const {},
  });

  final String recordId;
  final String? parentDir;
  final String? name;
  final bool isDir;
  final int size;
  final DateTime? mtime;
  final List<String> tags;
  final String? aiSummary;
  final Map<String, dynamic> values;

  factory MetadataRecord.fromJson(Map<String, dynamic> json) {
    return MetadataRecord(
      recordId: firstString(json, ['_id', 'record_id']) ?? '',
      parentDir: firstString(json, ['_parent_dir', 'parent_dir']),
      name: firstString(json, ['_name', 'name']),
      isDir: asBool(json['_is_dir']),
      size: firstInt(json, ['_size', 'size']) ?? 0,
      mtime: firstDate(json, ['_file_mtime', '_mtime', 'mtime']),
      tags: asStringList(json['_tags']),
      aiSummary: firstString(json, ['_ai_summary']),
      values: json,
    );
  }

  String? get path {
    final parent = parentDir;
    final fileName = name;
    if (parent == null || fileName == null) return null;
    return joinRepoPath(parent, fileName);
  }
}

class AiChatSession {
  const AiChatSession({required this.id, this.name = '', this.updatedAt});

  final String id;
  final String name;
  final DateTime? updatedAt;

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    return AiChatSession(
      id: firstString(json, ['session_uuid', 'id']) ?? '',
      name: firstString(json, ['session_name', 'name']) ?? '',
      updatedAt: firstDate(json, ['updated_at', 'mtime', 'ctime']),
    );
  }
}

class AiChatEvent {
  const AiChatEvent({this.answer, this.status, this.searchFound, this.done = false, this.raw});

  final String? answer;
  final String? status;
  final int? searchFound;
  final bool done;
  final Map<String, dynamic>? raw;
}


class ActivityEvent {
  const ActivityEvent({
    required this.opType,
    required this.repoId,
    required this.repoName,
    required this.objType,
    required this.path,
    required this.name,
    this.authorName,
    this.time,
    this.count = 1,
  });

  final String opType;
  final String repoId;
  final String repoName;
  final String objType;
  final String path;
  final String name;
  final String? authorName;
  final DateTime? time;
  final int count;

  bool get isDir => objType == 'dir' || objType == 'folder';

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final details = asMapList(json['details']);
    final first = details.isNotEmpty ? details.first : const <String, dynamic>{};
    return ActivityEvent(
      opType: firstString(json, ['op_type']) ?? 'create',
      repoId: firstString(json, ['repo_id']) ?? '',
      repoName: firstString(json, ['repo_name']) ?? firstString(first, ['repo_name']) ?? '',
      objType: firstString(json, ['obj_type']) ?? 'file',
      path: firstString(json, ['path']) ?? firstString(first, ['path']) ?? '/',
      name: firstString(json, ['name']) ?? firstString(first, ['name']) ?? baseName(firstString(json, ['path']) ?? '/'),
      authorName: firstString(json, ['author_name', 'name']),
      time: firstDate(json, ['time', 'ctime']),
      count: firstInt(json, ['count']) ?? 1,
    );
  }
}

class DeletedLibrary {
  const DeletedLibrary({required this.id, required this.name, this.deletedAt, this.size = 0});

  final String id;
  final String name;
  final DateTime? deletedAt;
  final int size;

  factory DeletedLibrary.fromJson(Map<String, dynamic> json) {
    return DeletedLibrary(
      id: firstString(json, ['repo_id', 'id']) ?? '',
      name: firstString(json, ['repo_name', 'name']) ?? '',
      deletedAt: firstDate(json, ['del_time', 'deleted_time', 'delete_time', 'mtime', 'last_modified']),
      size: firstInt(json, ['size']) ?? 0,
    );
  }
}
