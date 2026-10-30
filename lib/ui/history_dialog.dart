import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'widgets.dart';

Future<void> showFileHistory(BuildContext context, WorkspaceController workspace, Dirent entry) async {
  if (entry.isDir) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _FileHistoryDialog(workspace: workspace, entry: entry),
  );
}

class _FileHistoryDialog extends StatefulWidget {
  const _FileHistoryDialog({required this.workspace, required this.entry});

  final WorkspaceController workspace;
  final Dirent entry;

  @override
  State<_FileHistoryDialog> createState() => _FileHistoryDialogState();
}

class _FileHistoryDialogState extends State<_FileHistoryDialog> {
  List<FileVersion> _versions = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    final repo = widget.workspace.repo;
    if (api == null || repo == null) return;
    try {
      final versions = await api.fileHistory(repo.id, widget.entry.path);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _download(FileVersion version) async {
    final l10n = L10n.of(context);
    final api = context.read<AppSession>().api;
    final repo = widget.workspace.repo;
    if (api == null || repo == null) return;
    final location = await getSaveLocation(suggestedName: widget.entry.name);
    if (location == null || !mounted) return;
    final progress = ValueNotifier<double?>(0);
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.download),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => LinearProgressIndicator(value: value),
        ),
      ),
    );
    try {
      final link = await api.revisionDownloadLink(repo.id, widget.entry.path, version.commitId);
      await api.downloadUrlToFile(
        link,
        location.path,
        onProgress: (done, total) {
          progress.value = total > 0 ? (done / total).clamp(0.0, 1.0) : null;
        },
      );
      if (mounted) {
        Navigator.pop(context);
        showToast(context, l10n.versionDownloaded);
      }
    } catch (error) {
      if (mounted) {
        Navigator.pop(context);
        showToast(context, friendlyError(context, error), error: true);
      }
    } finally {
      progress.dispose();
      await dialogFuture;
    }
  }

  Future<void> _restore(FileVersion version) async {
    final l10n = L10n.of(context);
    final api = context.read<AppSession>().api;
    final repo = widget.workspace.repo;
    if (api == null || repo == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.restoreVersion,
      message: l10n.restoreVersionConfirm,
      danger: true,
      confirmLabel: l10n.restore,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(version.commitId));
    try {
      await api.revertFile(repo.id, widget.entry.path, false, version.commitId);
      await widget.workspace.refresh();
      if (!mounted) return;
      showToast(context, l10n.versionRestored);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(version.commitId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const WebIcon('history', size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${l10n.versionHistory} · ${widget.entry.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                : _versions.isEmpty
                    ? Center(child: Text(l10n.noHistory, style: const TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                        itemCount: _versions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final version = _versions[index];
                          final busy = _busy.contains(version.commitId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: index == 0 ? AppColors.primarySoft : AppColors.hover,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: WebIcon(
                                    index == 0 ? 'history' : 'file',
                                    size: 15,
                                    color: index == 0 ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            formatDateTime(version.time),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
                                          if (index == 0) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.currentVersion,
                                              style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [version.authorName, version.description, formatBytes(version.size)]
                                            .whereType<String>()
                                            .where((value) => value.isNotEmpty)
                                            .join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconAction(
                                  icon: 'download',
                                  tooltip: l10n.downloadVersion,
                                  size: 16,
                                  onPressed: busy ? null : () => _download(version),
                                ),
                                IconAction(
                                  icon: 'history',
                                  tooltip: l10n.restoreVersion,
                                  size: 16,
                                  onPressed: busy || index == 0 ? null : () => _restore(version),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
