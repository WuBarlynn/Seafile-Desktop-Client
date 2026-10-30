import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../api/api_error.dart';
import '../api/models.dart';
import '../api/seafile_api.dart';
import '../core/format.dart';
import 'session.dart';

enum TransferDirection { upload, download }

enum TransferStatus { waiting, running, done, failed, cancelled }

class TransferTask {
  TransferTask({
    required this.id,
    required this.direction,
    required this.name,
    required this.location,
    required this.isFolder,
    this.total = 0,
    this.savePath,
  });

  final String id;
  final TransferDirection direction;
  final String name;
  final String location;
  final bool isFolder;
  final CancelToken cancelToken = CancelToken();
  String? savePath;

  TransferStatus status = TransferStatus.waiting;
  int done = 0;
  int total = 0;
  double speed = 0;
  Object? error;

  DateTime _lastSample = DateTime.now();
  int _lastSampleBytes = 0;

  double? get fraction => total > 0 ? (done / total).clamp(0.0, 1.0) : null;
  bool get isActive => status == TransferStatus.waiting || status == TransferStatus.running;

  void updateProgress(int completed, int overall) {
    if (overall > 0) total = overall;
    done = completed < 0 ? 0 : completed;
    final now = DateTime.now();
    final elapsed = now.difference(_lastSample).inMilliseconds;
    if (elapsed >= 600) {
      final delta = done - _lastSampleBytes;
      if (delta >= 0) speed = delta / (elapsed / 1000);
      _lastSample = now;
      _lastSampleBytes = done;
    }
  }
}

class UploadItem {
  const UploadItem({
    required this.localPath,
    required this.remoteDir,
    required this.name,
    this.replace = false,
  });

  final String localPath;
  final String remoteDir;
  final String name;
  final bool replace;
}

class TransferManager extends ChangeNotifier {
  TransferManager(this._session);

  final AppSession _session;
  final List<TransferTask> _tasks = [];
  final List<Future<void> Function()> _uploadQueue = [];
  final List<Completer<void>> _uploadIdleCompleters = [];
  int _activeUploads = 0;
  Timer? _notifyTimer;
  bool _disposed = false;

  List<TransferTask> get tasks => List.unmodifiable(_tasks);
  bool get hasActive => _tasks.any((task) => task.isActive);

  static const _uploadConcurrency = 2;

  List<TransferTask> get activeTasks => _tasks.where((task) => task.isActive).toList();

  void _addTask(TransferTask task) {
    _tasks.insert(0, task);
    _scheduleNotify();
  }

  void cancel(TransferTask task) {
    if (!task.isActive) return;
    task.cancelToken.cancel();
    if (task.status == TransferStatus.waiting) {
      task.status = TransferStatus.cancelled;
    }
    _scheduleNotify();
  }

  void clearFinished() {
    _tasks.removeWhere((task) => !task.isActive);
    _scheduleNotify();
  }

  void clearAllFinished() {
    _tasks.clear();
    _scheduleNotify();
  }

  Future<void> enqueueUploads(Repository repo, List<UploadItem> items) async {
    final api = _session.api;
    if (api == null) throw ApiException(ApiErrorKind.network);
    for (final item in items) {
      final file = File(item.localPath);
      int size = 0;
      try {
        size = await file.length();
      } catch (_) {}
      final task = TransferTask(
        id: '${DateTime.now().microsecondsSinceEpoch}-${item.localPath.hashCode}',
        direction: TransferDirection.upload,
        name: item.name,
        location: _location(repo.name, item.remoteDir),
        isFolder: false,
        total: size,
      );
      _addTask(task);
      _uploadQueue.add(() async {
        if (task.cancelToken.isCancelled) {
          task.status = TransferStatus.cancelled;
          return;
        }
        task.status = TransferStatus.running;
        _scheduleNotify();
        try {
          await api.uploadFile(
            repoId: repo.id,
            dirPath: item.remoteDir,
            filePath: item.localPath,
            fileName: item.name,
            replace: item.replace,
            cancelToken: task.cancelToken,
            onProgress: (done, total) {
              task.updateProgress(done, total > 0 ? total : size);
              _scheduleNotify();
            },
          );
          task.status = TransferStatus.done;
          task.done = task.total;
          task.speed = 0;
        } on ApiException catch (error) {
          task.error = error;
          task.status = error.kind == ApiErrorKind.cancelled ? TransferStatus.cancelled : TransferStatus.failed;
        } catch (error) {
          task.error = error;
          task.status = TransferStatus.failed;
        } finally {
          _scheduleNotify();
        }
      });
    }
    _pumpUploads();
  }

  Future<void> enqueueFolderUpload(Repository repo, String parentDir, String localFolderPath) async {
    final api = _session.api;
    if (api == null) throw ApiException(ApiErrorKind.network);
    final root = Directory(localFolderPath);
    if (!await root.exists()) throw ApiException(ApiErrorKind.notFound);
    final folderName = p.basename(localFolderPath);
    final remoteRoot = joinRepoPath(parentDir, folderName);
    await api.createDirectory(repo.id, parentDir, folderName);

    final items = <UploadItem>[];
    final dirs = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: localFolderPath);
      final segments = p.split(relative);
      if (entity is Directory) {
        dirs.add(segments.join('/'));
      } else if (entity is File) {
        final remoteDir = segments.length <= 1 ? remoteRoot : '$remoteRoot/${segments.sublist(0, segments.length - 1).join('/')}';
        items.add(UploadItem(
          localPath: entity.path,
          remoteDir: remoteDir,
          name: segments.last,
        ));
      }
    }
    dirs.sort((a, b) => a.split('/').length.compareTo(b.split('/').length));
    for (final relative in dirs) {
      final segments = relative.split('/');
      final parent = segments.length == 1 ? remoteRoot : '$remoteRoot/${segments.sublist(0, segments.length - 1).join('/')}';
      await api.createDirectory(repo.id, parent, segments.last);
    }
    await enqueueUploads(repo, items);
  }

  Future<void> enqueueDownload(
    Repository repo,
    Dirent entry,
    String savePath,
  ) async {
    final api = _session.api;
    if (api == null) throw ApiException(ApiErrorKind.network);
    final task = TransferTask(
      id: '${DateTime.now().microsecondsSinceEpoch}-${entry.path.hashCode}',
      direction: TransferDirection.download,
      name: entry.name,
      location: _location(repo.name, parentRepoPath(entry.path)),
      isFolder: false,
      total: entry.size,
      savePath: savePath,
    );
    _addTask(task);
    unawaited(_runDownload(api, task, () {
      return api.downloadFile(
        repo.id,
        entry.path,
        savePath,
        cancelToken: task.cancelToken,
        onProgress: (done, total) {
          task.updateProgress(done, total);
          _scheduleNotify();
        },
      );
    }));
  }

  Future<void> enqueueFolderDownload(
    Repository repo,
    Dirent entry,
    String savePath,
  ) async {
    final api = _session.api;
    if (api == null) throw ApiException(ApiErrorKind.network);
    final task = TransferTask(
      id: '${DateTime.now().microsecondsSinceEpoch}-${entry.path.hashCode}',
      direction: TransferDirection.download,
      name: '${entry.name}.zip',
      location: _location(repo.name, parentRepoPath(entry.path)),
      isFolder: true,
      savePath: savePath,
    );
    _addTask(task);
    unawaited(_runDownload(api, task, () async {
      final link = await api.zipTask(repo.id, parentRepoPath(entry.path), [entry.name]);
      await api.downloadUrlToFile(
        link,
        savePath,
        cancelToken: task.cancelToken,
        onProgress: (done, total) {
          task.updateProgress(done, total);
          _scheduleNotify();
        },
      );
    }));
  }

  Future<void> _runDownload(SeafileApi api, TransferTask task, Future<void> Function() run) async {
    if (task.cancelToken.isCancelled) {
      task.status = TransferStatus.cancelled;
      _scheduleNotify();
      return;
    }
    task.status = TransferStatus.running;
    _scheduleNotify();
    try {
      await run();
      task.status = TransferStatus.done;
      task.done = task.total;
      task.speed = 0;
    } on ApiException catch (error) {
      task.error = error;
      task.status = error.kind == ApiErrorKind.cancelled ? TransferStatus.cancelled : TransferStatus.failed;
    } catch (error) {
      task.error = error;
      task.status = TransferStatus.failed;
    }
    _scheduleNotify();
  }

  void _pumpUploads() {
    while (_activeUploads < _uploadConcurrency && _uploadQueue.isNotEmpty) {
      final job = _uploadQueue.removeAt(0);
      _activeUploads++;
      unawaited(job().whenComplete(() {
        _activeUploads--;
        _pumpUploads();
        _checkUploadIdle();
      }));
    }
    _checkUploadIdle();
  }

  void _checkUploadIdle() {
    if (_activeUploads == 0 && _uploadQueue.isEmpty) {
      for (final completer in _uploadIdleCompleters) {
        if (!completer.isCompleted) completer.complete();
      }
      _uploadIdleCompleters.clear();
    }
  }

  Future<void> waitForUploads() {
    if (_activeUploads == 0 && _uploadQueue.isEmpty) return Future.value();
    final completer = Completer<void>();
    _uploadIdleCompleters.add(completer);
    return completer.future;
  }

  String _location(String repoName, String dirPath) {
    if (dirPath == '/') return repoName;
    return '$repoName $dirPath';
  }

  void _scheduleNotify() {
    if (_disposed) return;
    if (_notifyTimer?.isActive == true) return;
    _notifyTimer = Timer(const Duration(milliseconds: 90), () {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    for (final task in _tasks) {
      if (task.isActive) task.cancelToken.cancel();
    }
    super.dispose();
  }
}
