import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../core/format.dart';
import 'ai_chat.dart';
import 'session.dart';

enum BrowseMode { files, chat, settings, trash, history }

enum SortField { name, modified, size }

enum FileViewMode { list, grid }

class TreeNode {
  TreeNode({required this.name, required this.path});

  final String name;
  final String path;
  bool expanded = false;
  bool loaded = false;
  bool loading = false;
  List<TreeNode> children = [];
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.session) {
    session.addListener(_onSessionChanged);
    _loadPreferences();
  }

  final AppSession session;
  Repository? _repoSnapshot;
  String? _repoId;
  String _path = '/';

  List<Dirent> _entries = [];
  final Map<String, List<Dirent>> _dirCache = {};
  final Set<String> selectedPaths = {};
  String? _anchorPath;
  String _filter = '';
  SortField _sortField = SortField.name;
  bool _ascending = true;
  FileViewMode _viewMode = FileViewMode.list;
  BrowseMode _mode = BrowseMode.files;
  bool _loading = false;
  bool _refreshing = false;
  ApiException? _error;
  bool _needsUnlock = false;
  int _loadGeneration = 0;

  TreeNode? treeRoot;
  bool treeLoading = false;

  MetadataStatus? metaStatus;
  List<TagInfo> tags = const [];
  Map<String, MetadataRecord> records = {};
  String? selectedTagId;
  bool aiAvailable = false;
  bool seaDocEnabled = false;
  bool exdrawEnabled = false;
  bool officeEnabled = false;

  AiChatController? chat;
  List<AiChatSession> chatSessions = const [];

  List<TrashEntry> trashItems = [];
  bool trashLoading = false;
  bool trashHasMore = false;
  String? _trashScanStat;
  int _trashPage = 1;
  ApiException? trashError;
  final Set<String> trashSelection = {};

  List<RepoCommit> commits = [];
  bool historyLoading = false;
  bool historyHasMore = false;
  int _historyPage = 1;
  ApiException? historyError;

  int? historyLimit;
  bool settingsLoading = false;

  Repository? get repo {
    final id = _repoId;
    if (id == null) return null;
    return session.findRepo(id) ?? _repoSnapshot;
  }

  String? get repoId => _repoId;
  String get path => _path;
  BrowseMode get mode => _mode;
  List<Dirent> get entries => _entries;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  ApiException? get error => _error;
  bool get needsUnlock => _needsUnlock;
  String get filter => _filter;
  SortField get sortField => _sortField;
  bool get ascending => _ascending;
  FileViewMode get viewMode => _viewMode;
  TreeNode? get root => treeRoot;
  bool get canWrite => repo != null && !repo!.isReadOnly;
  bool get isEncrypted => repo?.encrypted == true;

  bool get hasMetadata => metaStatus?.enabled == true;
  bool get hasTags => metaStatus?.enabled == true && metaStatus?.tagsEnabled == true;
  bool get canUseAi => aiAvailable && hasMetadata && (metaStatus?.summaryEnabled == true);

  List<Dirent> get visibleEntries {
    final nameFilter = _filter.trim().toLowerCase();
    final tagId = selectedTagId;
    final list = _entries.where((entry) {
      if (nameFilter.isNotEmpty && !entry.name.toLowerCase().contains(nameFilter)) return false;
      if (tagId != null) {
        final record = records[entry.path];
        if (record == null || !record.tags.contains(tagId)) return false;
      }
      return true;
    }).toList();
    list.sort(_compareEntries);
    if (!_ascending) {
      final folders = list.where((entry) => entry.isDir).toList().reversed.toList();
      final files = list.where((entry) => !entry.isDir).toList().reversed.toList();
      return [...folders, ...files];
    }
    return list;
  }

  List<Dirent> get selectedEntries {
    final map = {for (final entry in _entries) entry.path: entry};
    return selectedPaths.map((path) => map[path]).whereType<Dirent>().toList();
  }

  List<TagInfo> tagsFor(Dirent entry) {
    final ids = records[entry.path]?.tags ?? const [];
    if (ids.isEmpty) return const [];
    final byId = {for (final tag in tags) tag.id: tag};
    return ids.map((id) => byId[id]).whereType<TagInfo>().toList();
  }

  MetadataRecord? recordFor(Dirent entry) => records[entry.path];

  int _compareEntries(Dirent a, Dirent b) {
    if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
    int result;
    switch (_sortField) {
      case SortField.name:
        result = compareNatural(a.name, b.name);
      case SortField.modified:
        result = (a.mtime?.millisecondsSinceEpoch ?? 0).compareTo(b.mtime?.millisecondsSinceEpoch ?? 0);
        if (result == 0) result = compareNatural(a.name, b.name);
      case SortField.size:
        result = a.size.compareTo(b.size);
        if (result == 0) result = compareNatural(a.name, b.name);
    }
    return result;
  }

  Future<void> openRepo(Repository repo) async {
    _repoId = repo.id;
    _repoSnapshot = repo;
    _path = '/';
    _mode = BrowseMode.files;
    _entries = [];
    _dirCache.clear();
    selectedPaths.clear();
    _anchorPath = null;
    _filter = '';
    selectedTagId = null;
    records = {};
    metaStatus = null;
    tags = const [];
    aiAvailable = false;
    seaDocEnabled = false;
    exdrawEnabled = false;
    officeEnabled = false;
    treeRoot = TreeNode(name: '/', path: '/');
    chat?.dispose();
    chat = null;
    notifyListeners();
    await Future.wait([loadDir(), loadMetadata(), _probeCapabilities()]);
  }

  void closeRepo() {
    _repoId = null;
    _repoSnapshot = null;
    _path = '/';
    _mode = BrowseMode.files;
    _entries = [];
    _dirCache.clear();
    selectedPaths.clear();
    selectedTagId = null;
    records = {};
    metaStatus = null;
    tags = const [];
    aiAvailable = false;
    seaDocEnabled = false;
    exdrawEnabled = false;
    officeEnabled = false;
    treeRoot = null;
    chat?.dispose();
    chat = null;
    _error = null;
    notifyListeners();
  }

  Future<void> loadDir({bool force = false}) async {
    final repo = this.repo;
    if (repo == null) return;
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    _needsUnlock = false;
    notifyListeners();
    try {
      final entries = await session.api!.listDir(repo.id, _path);
      if (generation != _loadGeneration) return;
      _entries = entries;
      _dirCache[_path] = entries;
      _loading = false;
      _error = null;
      notifyListeners();
      _syncTreeWithEntries(_path, entries);
      if (hasTags) unawaited(loadRecords());
    } on ApiException catch (error) {
      if (generation != _loadGeneration) return;
      _loading = false;
      _error = error;
      _needsUnlock = repo.encrypted && (error.status == 403 || error.status == 440 || error.status == 400);
      notifyListeners();
    } catch (error) {
      if (generation != _loadGeneration) return;
      _loading = false;
      _error = ApiException(ApiErrorKind.unknown, serverMessage: error.toString());
      notifyListeners();
    }
  }

  Future<void> refresh({bool force = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      if (treeRoot != null) {
        treeRoot!.loaded = false;
        treeRoot!.children = [];
        treeRoot!.expanded = true;
      }
      await loadDir(force: force);
      await loadMetadata();
      if (_mode == BrowseMode.settings) await loadSettings();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> enterPath(String path, {bool refresh = false}) async {
    final next = normalizeRepoPath(path);
    if (next == _path && !refresh) {
      if (_mode != BrowseMode.files) {
        _mode = BrowseMode.files;
        notifyListeners();
      }
      return;
    }
    _path = next;
    _mode = BrowseMode.files;
    selectedPaths.clear();
    _anchorPath = null;
    _filter = '';
    selectedTagId = null;
    notifyListeners();
    ensureTreePath(next);
    await loadDir();
  }

  void goUp() {
    if (_path == '/') return;
    unawaited(enterPath(parentRepoPath(_path)));
  }

  void backToLibraries() => closeRepo();

  void setMode(BrowseMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode == BrowseMode.files) {
      _path = _path;
    }
    notifyListeners();
  }

  void setFilter(String value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setSortField(SortField field) {
    if (_sortField == field) {
      _ascending = !_ascending;
    } else {
      _sortField = field;
      _ascending = true;
    }
    _savePreferences();
    notifyListeners();
  }

  void toggleSortOrder() {
    _ascending = !_ascending;
    _savePreferences();
    notifyListeners();
  }

  void setViewMode(FileViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _savePreferences();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Selection

  void toggleSelection(Dirent entry, {bool additive = false, bool range = false}) {
    if (range && _anchorPath != null) {
      final list = visibleEntries;
      final from = list.indexWhere((item) => item.path == _anchorPath);
      final to = list.indexWhere((item) => item.path == entry.path);
      if (from >= 0 && to >= 0) {
        final start = from < to ? from : to;
        final end = from < to ? to : from;
        if (!additive) selectedPaths.clear();
        for (var i = start; i <= end; i++) {
          selectedPaths.add(list[i].path);
        }
        notifyListeners();
        return;
      }
    }
    if (!additive) selectedPaths.clear();
    if (selectedPaths.contains(entry.path)) {
      selectedPaths.remove(entry.path);
    } else {
      selectedPaths.add(entry.path);
      _anchorPath = entry.path;
    }
    notifyListeners();
  }

  void selectAll(bool selected) {
    selectedPaths.clear();
    if (selected) {
      for (final entry in visibleEntries) {
        selectedPaths.add(entry.path);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    if (selectedPaths.isEmpty) return;
    selectedPaths.clear();
    _anchorPath = null;
    notifyListeners();
  }

  bool isSelected(Dirent entry) => selectedPaths.contains(entry.path);

  // -------------------------------------------------------------------------
  // Tree

  void _syncTreeWithEntries(String path, List<Dirent> entries) {
    final folders = entries.where((entry) => entry.isDir).toList();
    if (path == '/') {
      final root = treeRoot ?? TreeNode(name: '/', path: '/');
      treeRoot = root;
      root.loaded = true;
      root.expanded = true;
      root.children = folders.map((entry) {
        final existing = _findNode(root, entry.path);
        return existing ?? TreeNode(name: entry.name, path: entry.path);
      }).toList();
      return;
    }
    final node = _findNode(treeRoot, path);
    if (node != null) {
      node.loaded = true;
      node.expanded = true;
      node.children = folders.map((entry) {
        return _findNode(node, entry.path) ?? TreeNode(name: entry.name, path: entry.path);
      }).toList();
    }
  }

  TreeNode? _findNode(TreeNode? node, String path) {
    if (node == null) return null;
    if (node.path == path) return node;
    for (final child in node.children) {
      final found = _findNode(child, path);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> toggleTree(TreeNode node) async {
    if (node.expanded) {
      node.expanded = false;
      notifyListeners();
      return;
    }
    node.expanded = true;
    if (!node.loaded && !node.loading) {
      await loadTreeChildren(node);
    } else {
      notifyListeners();
    }
  }

  Future<void> loadTreeChildren(TreeNode node) async {
    final repo = this.repo;
    final api = session.api;
    if (repo == null || api == null || node.loading) return;
    node.loading = true;
    treeLoading = true;
    notifyListeners();
    try {
      final entries = _dirCache[node.path] ?? await api.listDir(repo.id, node.path);
      _dirCache[node.path] = entries;
      node.children = entries
          .where((entry) => entry.isDir)
          .map((entry) => TreeNode(name: entry.name, path: entry.path))
          .toList();
      node.loaded = true;
    } catch (_) {
      node.loaded = true;
    } finally {
      node.loading = false;
      treeLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureTreePath(String path) async {
    if (treeRoot == null) return;
    if (treeRoot!.children.isEmpty && _path == '/') return;
    var current = treeRoot;
    var built = '/';
    for (final segment in normalizeRepoPath(path).split('/').where((s) => s.isNotEmpty)) {
      built = built == '/' ? '/$segment' : '$built/$segment';
      final node = current!.children.where((child) => child.path == built).firstOrNull;
      if (node == null) break;
      current = node;
      if (!node.loaded) {
        await loadTreeChildren(node);
      }
      node.expanded = true;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // File operations

  Future<void> _probeCapabilities() async {
    final repo = this.repo;
    final api = session.api;
    if (repo == null || api == null) return;
    officeEnabled = repo.enableOnlyOffice || (session.serverInfo?.features.contains('onlyoffice') ?? false);
    final seaDoc = await api.seaDocAvailable(repo.id);
    seaDocEnabled = seaDoc && !repo.encrypted;
    exdrawEnabled = seaDocEnabled && await api.exdrawAvailable(repo.id);
    notifyListeners();
  }

  Future<void> createFile(String path) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.createFile(repo.id, path);
    await loadDir();
  }

  Future<void> importSdoc(String filePath) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.importSdoc(repo.id, _path, filePath);
    await loadDir();
  }

  Future<void> createFolder(String name) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.createDirectory(repo.id, _path, name);
    await loadDir();
    _invalidateTree();
  }

  Future<void> renameEntry(Dirent entry, String newName) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.renameEntry(repo.id, entry, newName);
    await loadDir();
    _invalidateTree();
  }

  Future<void> deleteEntries(List<Dirent> entries) async {
    final repo = this.repo;
    if (repo == null || entries.isEmpty) return;
    await session.api!.deleteEntries(repo.id, _path, entries.map((entry) => entry.name).toList());
    selectedPaths.clear();
    await loadDir();
    _invalidateTree();
  }

  Future<void> moveEntries(List<Dirent> entries, String destinationRepoId, String destinationPath) async {
    final repo = this.repo;
    if (repo == null || entries.isEmpty) return;
    await session.api!.moveEntries(
      repoId: repo.id,
      dirPath: _path,
      names: entries.map((entry) => entry.name).toList(),
      destinationRepoId: destinationRepoId,
      destinationPath: destinationPath,
    );
    selectedPaths.clear();
    await loadDir();
    _invalidateTree();
  }

  Future<void> copyEntries(List<Dirent> entries, String destinationRepoId, String destinationPath) async {
    final repo = this.repo;
    if (repo == null || entries.isEmpty) return;
    await session.api!.copyEntries(
      repoId: repo.id,
      dirPath: _path,
      names: entries.map((entry) => entry.name).toList(),
      destinationRepoId: destinationRepoId,
      destinationPath: destinationPath,
    );
    await loadDir();
  }

  Future<void> toggleStar(Dirent entry) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.setStarred(repoId: repo.id, path: entry.path, starred: !entry.starred);
    await loadDir();
  }

  void _invalidateTree() {
    if (treeRoot == null) return;
    treeRoot!.loaded = false;
    treeRoot!.children = [];
    treeRoot!.expanded = true;
    _dirCache.remove('/');
    unawaited(ensureTreePath(_path));
  }

  // -------------------------------------------------------------------------
  // Metadata

  Future<void> loadMetadata() async {
    final repo = this.repo;
    final api = session.api;
    if (repo == null || api == null) return;
    try {
      final status = await api.metadataStatus(repo.id);
      metaStatus = status;
      if (status.enabled) {
        if (status.tagsEnabled) {
          try {
            tags = await api.tags(repo.id);
          } catch (_) {
            tags = const [];
          }
        } else {
          tags = const [];
        }
        if (status.summaryEnabled) {
          aiAvailable = await api.aiAvailable(repo.id);
        } else {
          aiAvailable = false;
        }
        if (hasTags) unawaited(loadRecords());
      } else {
        tags = const [];
        aiAvailable = false;
        records = {};
      }
      notifyListeners();
    } catch (_) {
      metaStatus = null;
      tags = const [];
      records = {};
      aiAvailable = false;
      notifyListeners();
    }
  }

  Future<void> loadRecords() async {
    final repo = this.repo;
    final api = session.api;
    if (repo == null || api == null || _entries.isEmpty) return;
    final files = <MapEntry<String, String>>[
      for (final entry in _entries) MapEntry(_path, entry.name),
    ];
    try {
      final list = await api.records(repo.id, files);
      final map = <String, MetadataRecord>{};
      for (final record in list) {
        final path = record.path;
        if (path != null) map[path] = record;
      }
      if (map.isNotEmpty) {
        records = map;
        notifyListeners();
      }
    } catch (_) {}
  }

  void selectTag(String? tagId) {
    selectedTagId = selectedTagId == tagId ? null : tagId;
    notifyListeners();
    if (selectedTagId != null) unawaited(loadRecords());
  }

  Future<void> assignTag(Dirent entry, TagInfo tag, bool selected) async {
    final repo = this.repo;
    final api = session.api;
    if (repo == null || api == null) return;
    var record = records[entry.path];
    record ??= await api.record(repo.id, parentDir: _path, fileName: entry.name);
    if (record == null) return;
    final ids = [...record.tags];
    if (selected) {
      if (!ids.contains(tag.id)) ids.add(tag.id);
    } else {
      ids.remove(tag.id);
    }
    await api.updateFileTags(repo.id, record.recordId, ids);
    records = {
      ...records,
      entry.path: MetadataRecord(
        recordId: record.recordId,
        parentDir: record.parentDir,
        name: record.name,
        isDir: record.isDir,
        size: record.size,
        mtime: record.mtime,
        tags: ids,
        aiSummary: record.aiSummary,
        values: record.values,
      ),
    };
    notifyListeners();
  }

  Future<TagInfo> createTag(String name, String color) async {
    final repo = this.repo;
    if (repo == null) throw ApiException(ApiErrorKind.network);
    final tag = await session.api!.createTag(repo.id, name, color);
    tags = await session.api!.tags(repo.id);
    notifyListeners();
    return tag;
  }

  Future<void> refreshFavorites() async {}

  // -------------------------------------------------------------------------
  // Library settings

  Future<void> openSettings() async {
    _mode = BrowseMode.settings;
    notifyListeners();
    await loadSettings();
    await loadMetadata();
  }

  Future<void> loadSettings() async {
    final repo = this.repo;
    if (repo == null) return;
    settingsLoading = true;
    notifyListeners();
    try {
      historyLimit = await session.api!.repoHistoryLimit(repo.id);
    } catch (_) {
      historyLimit = -1;
    } finally {
      settingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> setHistoryLimit(int value) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.setRepoHistoryLimit(repo.id, value);
    historyLimit = value;
    notifyListeners();
  }

  Future<void> setMetadataEnabled(bool enabled) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.setMetadataEnabled(repo.id, enabled);
    await loadMetadata();
  }

  Future<void> setTagsEnabled(bool enabled) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.setTagsEnabled(repo.id, enabled);
    await loadMetadata();
  }

  Future<void> setSummaryEnabled(bool enabled) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.setSummaryEnabled(repo.id, enabled);
    await loadMetadata();
  }

  // -------------------------------------------------------------------------
  // Trash

  Future<void> openTrash() async {
    _mode = BrowseMode.trash;
    trashItems = [];
    trashSelection.clear();
    _trashPage = 1;
    _trashScanStat = null;
    notifyListeners();
    await loadTrash(reset: true);
  }

  Future<void> loadTrash({bool reset = false}) async {
    final repo = this.repo;
    if (repo == null) return;
    if (trashLoading) return;
    if (reset) {
      _trashPage = 1;
      _trashScanStat = null;
      trashItems = [];
      trashSelection.clear();
    }
    trashLoading = true;
    trashError = null;
    notifyListeners();
    try {
      final page = await session.api!.listTrash(
        repo.id,
        page: _trashPage,
        scanStat: _trashScanStat,
      );
      trashItems = [...trashItems, ...page.items];
      trashHasMore = page.hasMore;
      _trashScanStat = page.scanStat;
      _trashPage++;
    } on ApiException catch (error) {
      trashError = error;
    } finally {
      trashLoading = false;
      notifyListeners();
    }
  }

  void toggleTrashSelection(TrashEntry entry) {
    final key = trashKey(entry);
    if (trashSelection.contains(key)) {
      trashSelection.remove(key);
    } else {
      trashSelection.add(key);
    }
    notifyListeners();
  }

  void clearTrashSelection() {
    if (trashSelection.isEmpty) return;
    trashSelection.clear();
    notifyListeners();
  }

  void selectAllTrash(bool selected) {
    trashSelection.clear();
    if (selected) {
      for (final entry in trashItems) {
        trashSelection.add(trashKey(entry));
      }
    }
    notifyListeners();
  }

  bool isTrashSelected(TrashEntry entry) => trashSelection.contains(trashKey(entry));

  List<TrashEntry> get selectedTrashEntries =>
      trashItems.where((entry) => trashSelection.contains(trashKey(entry))).toList();

  String trashKey(TrashEntry entry) => '${entry.commitId}|${entry.path ?? entry.parentDir ?? ''}|${entry.name}';

  Future<void> restoreTrashEntries(List<TrashEntry> entries) async {
    final repo = this.repo;
    if (repo == null || entries.isEmpty) return;
    await session.api!.restoreTrash(repo.id, entries);
    trashSelection.clear();
    await loadTrash(reset: true);
    await loadDir();
  }

  Future<void> emptyTrash() async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.emptyTrash(repo.id);
    trashItems = [];
    trashHasMore = false;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // History

  Future<void> openHistory() async {
    _mode = BrowseMode.history;
    commits = [];
    _historyPage = 1;
    notifyListeners();
    await loadHistory(reset: true);
  }

  Future<void> loadHistory({bool reset = false}) async {
    final repo = this.repo;
    if (repo == null || historyLoading) return;
    if (reset) {
      _historyPage = 1;
      commits = [];
    }
    historyLoading = true;
    historyError = null;
    notifyListeners();
    try {
      final list = await session.api!.repoHistory(repo.id, page: _historyPage, perPage: 50);
      commits = [...commits, ...list];
      historyHasMore = list.length >= 50;
      _historyPage++;
    } on ApiException catch (error) {
      historyError = error;
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> revertToCommit(RepoCommit commit) async {
    final repo = this.repo;
    if (repo == null) return;
    await session.api!.revertRepo(repo.id, commit.commitId);
    await refresh();
    await loadHistory(reset: true);
  }

  // -------------------------------------------------------------------------
  // AI chat

  void openChat() {
    final repo = this.repo;
    if (repo == null) return;
    if (chat == null || chat!.repoId != repo.id) {
      chat?.dispose();
      chat = AiChatController(session, repo.id);
    }
    _mode = BrowseMode.chat;
    notifyListeners();
    unawaited(chat!.loadSessions());
  }

  void closeChat() {
    if (_mode == BrowseMode.chat) {
      _mode = BrowseMode.files;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Lifecycle

  void _onSessionChanged() {
    if (!session.hasSession) {
      closeRepo();
      return;
    }
    if (_repoId != null && session.findRepo(_repoId!) == null && session.loadedLibraries) {
      closeRepo();
      return;
    }
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sort = prefs.getString('workspace.sortField');
      _sortField = SortField.values.where((field) => field.name == sort).firstOrNull ?? SortField.name;
      _ascending = prefs.getBool('workspace.ascending') ?? true;
      final view = prefs.getString('workspace.viewMode');
      _viewMode = FileViewMode.values.where((mode) => mode.name == view).firstOrNull ?? FileViewMode.list;
      notifyListeners();
    } catch (_) {}
  }

  void _savePreferences() {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('workspace.sortField', _sortField.name);
        await prefs.setBool('workspace.ascending', _ascending);
        await prefs.setString('workspace.viewMode', _viewMode.name);
      } catch (_) {}
    }());
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    chat?.dispose();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
