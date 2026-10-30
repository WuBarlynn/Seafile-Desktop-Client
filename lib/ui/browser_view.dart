import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/transfer_manager.dart';
import '../state/workspace.dart';
import 'chat_view.dart';
import 'file_actions.dart';
import 'file_area.dart';
import 'new_menu.dart';
import 'history_view.dart';
import 'preview_page.dart';
import 'settings_view.dart';
import 'trash_view.dart';
import 'tree_panel.dart';
import 'widgets.dart';

class BrowserView extends StatefulWidget {
  const BrowserView({super.key});

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  bool _treeVisible = true;
  bool _detailsOpen = false;
  double _treeWidth = 250;
  double _detailsWidth = 330;

  WorkspaceController get ws => context.read<WorkspaceController>();

  Future<void> _newFolder() async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.newFolder,
      label: l10n.folderName,
      validator: (value) => value.trim().isEmpty ? l10n.folderNameRequired : null,
    );
    if (name == null || !mounted) return;
    try {
      await ws.createFolder(name.trim());
      if (mounted) showToast(context, l10n.folderCreated);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<bool> _confirmConflicts(List<String> conflicts) async {
    final l10n = L10n.of(context);
    if (conflicts.isEmpty) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.conflictTitle),
        content: Text(conflicts.length == 1 ? l10n.conflictMessage(conflicts.first) : l10n.selectedCount(conflicts.length)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: Text(l10n.cancel)),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'skip'), child: Text(l10n.skip)),
          FilledButton(onPressed: () => Navigator.pop(context, 'replace'), child: Text(l10n.replace)),
        ],
      ),
    );
    if (result == 'cancel' || result == null) return false;
    _conflictChoice = result;
    return true;
  }

  String? _conflictChoice;

  Future<void> _uploadPaths(List<String> paths) async {
    final workspace = ws;
    final repo = workspace.repo;
    final manager = context.read<TransferManager>();
    if (repo == null || paths.isEmpty) return;
    final l10n = L10n.of(context);
    try {
      final files = <String>[];
      final folders = <String>[];
      for (final path in paths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          folders.add(path);
        } else if (type == FileSystemEntityType.file) {
          files.add(path);
        }
      }
      if (files.isNotEmpty) {
        final existing = workspace.entries.map((entry) => entry.name).toSet();
        final conflicts = files.where((file) => existing.contains(p.basename(file))).map(p.basename).toList();
        _conflictChoice = null;
        if (!await _confirmConflicts(conflicts) || !mounted) return;
        final replace = _conflictChoice == 'replace';
        final uploads = <UploadItem>[];
        for (final file in files) {
          final name = p.basename(file);
          if (conflicts.contains(name) && _conflictChoice == 'skip') continue;
          uploads.add(UploadItem(
            localPath: file,
            remoteDir: workspace.path,
            name: name,
            replace: conflicts.contains(name) && replace,
          ));
        }
        if (uploads.isNotEmpty) await manager.enqueueUploads(repo, uploads);
        unawaited(manager.waitForUploads().then((_) {
          if (mounted) {
            workspace.loadDir();
            showToast(context, l10n.uploadComplete);
          }
        }));
      }
      for (final folder in folders) {
        await manager.enqueueFolderUpload(repo, workspace.path, folder);
        unawaited(manager.waitForUploads().then((_) {
          if (mounted) {
            workspace.loadDir();
            showToast(context, l10n.uploadComplete);
          }
        }));
      }
      if (files.isNotEmpty || folders.isNotEmpty) showToast(context, l10n.addedToUploads);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _pickFiles() async {
    final files = await openFiles();
    if (!mounted || files.isEmpty) return;
    await _uploadPaths(files.map((file) => file.path).toList());
  }

  Future<void> _pickFolder() async {
    final l10n = L10n.of(context);
    final directory = await getDirectoryPath(confirmButtonText: l10n.uploadFolder);
    if (!mounted || directory == null) return;
    await _uploadPaths([directory]);
  }

  Future<void> _openRepoMenu(String value) async {
    final workspace = ws;
    final session = context.read<AppSession>();
    final repo = workspace.repo;
    final l10n = L10n.of(context);
    if (repo == null) return;
    switch (value) {
      case 'new-folder':
        await _newFolder();
      case 'upload-files':
        await _pickFiles();
      case 'upload-folder':
        await _pickFolder();
      case 'settings':
        await workspace.openSettings();
      case 'trash':
        await workspace.openTrash();
      case 'history':
        await workspace.openHistory();
      case 'info':
        await showLibraryInfo(context, workspace);
      case 'share':
        await shareEntry(context, workspace, null);
      case 'rename':
        final name = await showTextPrompt(
          context,
          title: l10n.renameLibrary,
          label: l10n.libraryName,
          initialValue: repo.name,
          validator: (value) => value.trim().isEmpty ? l10n.libraryNameRequired : null,
        );
        if (name == null || !mounted) return;
        try {
          await session.api!.renameLibrary(repo.id, name.trim());
          await session.refreshLibraries();
          if (mounted) showToast(context, l10n.libraryRenamed);
        } catch (error) {
          if (mounted) showToast(context, friendlyError(context, error), error: true);
        }
      case 'delete':
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.deleteLibrary,
          message: l10n.deleteLibraryConfirm(repo.name),
          danger: true,
          confirmLabel: l10n.delete,
        );
        if (!confirmed || !mounted) return;
        try {
          await session.api!.deleteLibrary(repo.id);
          workspace.closeRepo();
          await session.refreshLibraries();
          if (mounted) showToast(context, l10n.libraryDeleted);
        } catch (error) {
          if (mounted) showToast(context, friendlyError(context, error), error: true);
        }
      case 'refresh':
        await workspace.refresh();
    }
  }

  void _showDetails() {
    final selected = ws.selectedEntries;
    if (selected.length != 1) {
      showToast(context, L10n.of(context).noSelection, error: true);
      return;
    }
    setState(() => _detailsOpen = true);
  }

  void _preview(Dirent entry) {
    final repo = ws.repo;
    if (repo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PreviewPage(repo: repo, entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.repo;
    if (repo == null) return const SizedBox.shrink();
    final selected = workspace.selectedEntries;
    final l10n = L10n.of(context);
    return Column(
      children: [
        _buildHeader(context, workspace, repo, selected, l10n),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_treeVisible) ...[
                SizedBox(
                  width: _treeWidth,
                  child: TreePanel(
                    workspace: workspace,
                    onUploadFiles: _pickFiles,
                    onUploadFolder: _pickFolder,
                    onNewFolder: _newFolder,
                    onRenameLibrary: () => _openRepoMenu('rename'),
                    onDeleteLibrary: () => _openRepoMenu('delete'),
                    onLibraryInfo: () => _openRepoMenu('info'),
                    onShareLibrary: () => _openRepoMenu('share'),
                  ),
                ),
                ResizeHandle(
                  onDrag: (delta) => setState(() {
                    _treeWidth = (_treeWidth + delta).clamp(190.0, 430.0);
                  }),
                ),
              ],
              Expanded(
                child: switch (workspace.mode) {
                  BrowseMode.files => FileArea(
                      onPreview: _preview,
                      onUploadFiles: _pickFiles,
                      onUploadPaths: _uploadPaths,
                      detailsOpen: _detailsOpen,
                      detailsWidth: _detailsWidth,
                      onDetailsResize: (delta) => setState(() {
                        _detailsWidth = (_detailsWidth - delta).clamp(280.0, 520.0);
                      }),
                      onCloseDetails: () => setState(() => _detailsOpen = false),
                    ),
                  BrowseMode.chat => const ChatView(),
                  BrowseMode.settings => const LibrarySettingsView(),
                  BrowseMode.trash => const TrashView(),
                  BrowseMode.history => const HistoryView(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WorkspaceController workspace,
    Repository repo,
    List<Dirent> selected,
    L10n l10n,
  ) {
    final inFiles = workspace.mode == BrowseMode.files;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconAction(
            icon: 'side-bar',
            tooltip: l10n.file,
            size: 18,
            onPressed: () => setState(() => _treeVisible = !_treeVisible),
          ),
          const SizedBox(width: 2),
          Container(width: 1, height: 20, color: AppColors.border),
          const SizedBox(width: 8),
          if (inFiles && selected.isNotEmpty) ..._selectionHeader(context, workspace, selected, l10n)
          else
            Expanded(child: _breadcrumb(context, workspace, repo, l10n)),
          if (inFiles && selected.isEmpty) ...[
            IconAction(
              icon: workspace.viewMode == FileViewMode.list ? 'grid-view' : 'list-view',
              tooltip: workspace.viewMode == FileViewMode.list ? l10n.gridView : l10n.listView,
              size: 18,
              onPressed: () => workspace.setViewMode(
                workspace.viewMode == FileViewMode.list ? FileViewMode.grid : FileViewMode.list,
              ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              tooltip: l10n.sortBy,
              offset: const Offset(0, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              itemBuilder: (context) => [
                _sortItem(context, l10n.sortName, SortField.name, workspace),
                _sortItem(context, l10n.sortSize, SortField.size, workspace),
                _sortItem(context, l10n.sortModified, SortField.modified, workspace),
              ],
              onSelected: (value) => workspace.setSortField(
                switch (value) {
                  'size' => SortField.size,
                  'modified' => SortField.modified,
                  _ => SortField.name,
                },
              ),
              child: const Padding(padding: EdgeInsets.all(6), child: WebIcon('sort-ascending', size: 18)),
            ),
            IconAction(icon: 'info', tooltip: l10n.showDetails, size: 18, onPressed: _showDetails),
          ],
          if (workspace.mode == BrowseMode.trash)
            IconAction(icon: 'refresh', tooltip: l10n.refresh, size: 18, onPressed: () => workspace.loadTrash(reset: true)),
          if (workspace.mode == BrowseMode.history)
            IconAction(icon: 'refresh', tooltip: l10n.refresh, size: 18, onPressed: () => workspace.loadHistory(reset: true)),
        ],
      ),
    );
  }

  List<Widget> _selectionHeader(
    BuildContext context,
    WorkspaceController workspace,
    List<Dirent> selected,
    L10n l10n,
  ) {
    final canWrite = workspace.canWrite && selected.every((entry) => !entry.isReadOnly);
    return [
      IconAction(icon: 'close', tooltip: l10n.clearSelection, size: 15, onPressed: workspace.clearSelection),
      const SizedBox(width: 6),
      Text(l10n.selectedCount(selected.length), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(width: 12),
      IconAction(icon: 'download', tooltip: l10n.download, size: 17, onPressed: () => downloadEntries(context, workspace, selected)),
      IconAction(icon: 'share', tooltip: l10n.share, size: 17, onPressed: selected.length == 1 ? () => shareEntry(context, workspace, selected.single) : null),
      if (canWrite) IconAction(icon: 'move', tooltip: l10n.move, size: 17, onPressed: () => moveEntries(context, workspace, selected)),
      IconAction(icon: 'copy', tooltip: l10n.copy, size: 17, onPressed: () => copyEntries(context, workspace, selected)),
      if (selected.length == 1) IconAction(icon: 'info', tooltip: l10n.showDetails, size: 17, onPressed: _showDetails),
      if (canWrite) IconAction(icon: 'delete', tooltip: l10n.delete, size: 17, color: AppColors.danger, onPressed: () => deleteEntries(context, workspace, selected)),
      const Spacer(),
    ];
  }

  PopupMenuItem<String> _sortItem(BuildContext context, String label, SortField field, WorkspaceController workspace) {
    final active = workspace.sortField == field;
    return PopupMenuItem(
      value: field.name,
      child: Row(
        children: [
          SizedBox(width: 24, child: active ? const WebIcon('check', size: 14, color: AppColors.primary) : null),
          Text(label, style: TextStyle(fontSize: 13, color: active ? AppColors.primary : AppColors.text)),
          if (active) ...[
            const Spacer(),
            WebIcon(workspace.ascending ? 'sort-ascending' : 'sort-descending', size: 14, color: AppColors.primary),
          ],
        ],
      ),
    );
  }

  Widget _breadcrumb(BuildContext context, WorkspaceController workspace, Repository repo, L10n l10n) {
    final segments = workspace.path.split('/').where((segment) => segment.isNotEmpty).toList();
    final modeLabel = switch (workspace.mode) {
      BrowseMode.files => null,
      BrowseMode.chat => l10n.chatWithAi,
      BrowseMode.settings => l10n.settings,
      BrowseMode.trash => l10n.trash,
      BrowseMode.history => l10n.historyNav,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _crumb(l10n.file, () => workspace.closeRepo()),
          const _crumbSeparator(),
          _crumb(repo.name, () => workspace.enterPath('/')),
          if (modeLabel == null) _buildRepoPlusMenu(context, workspace, l10n) else ...[
            const _crumbSeparator(),
            Text(modeLabel, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ],
          for (var index = 0; index < segments.length; index++) ...[
            const _crumbSeparator(),
            _crumb(
              segments[index],
              () => workspace.enterPath('/${segments.sublist(0, index + 1).join('/')}'),
              last: index == segments.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepoPlusMenu(BuildContext context, WorkspaceController workspace, L10n l10n) {
    return NewMenuButton(
      workspace: workspace,
      onUploadFiles: _pickFiles,
      onUploadFolder: _pickFolder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WebIcon('plus-sign', size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 1),
          const WebIcon('arrow-down', size: 11, color: AppColors.textSecondary),
        ],
      ),
    );
  }



  Widget _crumb(String label, VoidCallback onTap, {bool last = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      hoverColor: AppColors.hover,
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: last ? AppColors.text : AppColors.textSecondary,
            fontWeight: last ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _crumbSeparator extends StatelessWidget {
  const _crumbSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: Text('/', style: TextStyle(fontSize: 13, color: AppColors.muted)),
    );
  }
}
