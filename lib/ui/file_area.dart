import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/file_kind.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/workspace.dart';
import 'details_panel.dart';
import 'file_actions.dart';
import 'repo_actions.dart';
import 'thumbnail_view.dart';
import 'web_handoff.dart';
import 'widgets.dart';

class FileArea extends StatefulWidget {
  const FileArea({
    super.key,
    required this.onPreview,
    required this.onUploadFiles,
    required this.onUploadPaths,
    required this.detailsOpen,
    required this.detailsWidth,
    required this.onDetailsResize,
    required this.onCloseDetails,
  });

  final ValueChanged<Dirent> onPreview;
  final VoidCallback onUploadFiles;
  final ValueChanged<List<String>> onUploadPaths;
  final bool detailsOpen;
  final double detailsWidth;
  final ValueChanged<double> onDetailsResize;
  final VoidCallback onCloseDetails;

  @override
  State<FileArea> createState() => _FileAreaState();
}

class _FileAreaState extends State<FileArea> {
  bool _dragging = false;
  String? _lastOpenPath;
  DateTime? _lastOpenAt;

  WorkspaceController get ws => context.read<WorkspaceController>();

  void _handleTap(Dirent entry, int index) {
    final keyboard = HardwareKeyboard.instance;
    final additive = keyboard.isMetaPressed || keyboard.isControlPressed;
    final range = keyboard.isShiftPressed;
    if (additive || range) {
      ws.toggleSelection(entry, additive: true, range: range);
      return;
    }
    final now = DateTime.now();
    final repeated = _lastOpenPath == entry.path && _lastOpenAt != null && now.difference(_lastOpenAt!) < const Duration(milliseconds: 450);
    if (repeated) return;
    _lastOpenPath = entry.path;
    _lastOpenAt = now;
    ws.toggleSelection(entry, additive: false);
    if (entry.isDir) {
      ws.enterPath(entry.path);
    } else {
      widget.onPreview(entry);
    }
  }

  Future<void> _showContextMenu(Dirent entry, Offset position) async {
    final l10n = L10n.of(context);
    final workspace = ws;
    final selected = workspace.selectedEntries;
    final targets = selected.any((item) => item.path == entry.path) && selected.length > 1 ? selected : [entry];
    final single = targets.singleOrNull;
    final canWrite = workspace.canWrite && targets.every((item) => !item.isReadOnly);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'open',
        child: _row(entry.isDir ? 'folder-open' : 'open-in-new-tab', entry.isDir ? l10n.open : l10n.preview),
      ),
      if (single != null && !single.isDir)
        PopupMenuItem(value: 'web', child: _row('link', l10n.openInBrowser)),
      PopupMenuItem(value: 'download', child: _row('download', l10n.download)),
      PopupMenuItem(value: 'share', child: _row('share', l10n.share)),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'star',
        child: _row(entry.starred ? 'unstarred' : 'starred', entry.starred ? (l10n.zh ? '取消星标' : 'Remove star') : (l10n.zh ? '添加星标' : 'Add star')),
      ),
      if (canWrite) PopupMenuItem(value: 'rename', child: _row('rename', l10n.rename)),
      if (canWrite) PopupMenuItem(value: 'move', child: _row('move', l10n.move)),
      PopupMenuItem(value: 'copy', child: _row('copy', l10n.copy)),
      if (single != null && !single.isDir && FileKind.of(single.name).isPreviewable && (FileKind.of(single.name) == FileKind.text || FileKind.of(single.name) == FileKind.markdown) && canWrite)
        PopupMenuItem(value: 'edit', child: _row('edit', l10n.edit)),
      if (single != null && !single.isDir && canWrite && !single.name.toLowerCase().endsWith('.sdoc'))
        PopupMenuItem(
          value: single.locked ? 'unlock' : 'lock',
          child: _row(single.locked ? 'unlock' : 'lock', single.locked ? l10n.unlockFile : l10n.lockFile),
        ),
      if (single != null && !single.isDir) PopupMenuItem(value: 'history', child: _row('history', l10n.history)),
      const PopupMenuDivider(),
      PopupMenuItem(value: 'details', child: _row('info', l10n.details)),
      if (canWrite) PopupMenuItem(value: 'delete', child: _row('delete', l10n.delete, danger: true)),
    ];
    final selectedValue = await showMenu<String>(
      popUpAnimationStyle: AppMotion.menuAnimation,
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: items,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    );
    if (!mounted || selectedValue == null) return;
    switch (selectedValue) {
      case 'open':
        if (entry.isDir) {
          workspace.enterPath(entry.path);
        } else {
          widget.onPreview(entry);
        }
      case 'web':
        if (single != null) {
          final path = encodeRepoPath(single.path);
          await openAuthenticatedWeb(context, '/lib/${workspace.repo!.id}/file$path', title: single.name);
        }
      case 'download':
        await downloadEntries(context, workspace, targets);
      case 'share':
        if (single != null) await shareEntry(context, workspace, single);
      case 'star':
        await toggleStar(context, workspace, entry);
      case 'rename':
        if (single != null) await renameEntry(context, workspace, single);
      case 'move':
        await moveEntries(context, workspace, targets);
      case 'copy':
        await copyEntries(context, workspace, targets);
      case 'edit':
        if (single != null) widget.onPreview(single);
      case 'lock':
      case 'unlock':
        if (single != null) {
          try {
            await workspace.session.api!.setFileLock(workspace.repo!.id, single.path, selectedValue == 'lock');
            await workspace.loadDir();
            if (context.mounted) showToast(context, selectedValue == 'lock' ? l10n.fileLocked : l10n.fileUnlocked);
          } catch (error) {
            if (context.mounted) showToast(context, friendlyError(context, error), error: true);
          }
        }
      case 'history':
        if (single != null) await showFileHistory(context, workspace, single);
      case 'details':
        workspace.toggleSelection(entry, additive: false);
      case 'delete':
        await deleteEntries(context, workspace, targets);
    }
  }

  Widget _row(String icon, String label, {bool danger = false}) {
    return Row(
      children: [
        WebIcon(icon, size: 16, color: danger ? AppColors.danger : AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: danger ? AppColors.danger : AppColors.text)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.repo;
    if (repo == null) return const SizedBox.shrink();
    final entries = workspace.visibleEntries;
    final selected = workspace.selectedEntries;
    final detailEntry = widget.detailsOpen && selected.length == 1 ? selected.single : null;

    Widget content;
    if (workspace.error != null && workspace.entries.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WebIcon('exclamation-circle', size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(workspace.error!.friendly(L10n.of(context)), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (workspace.needsUnlock)
                  FilledButton(
                    onPressed: () async {
                      final unlocked = await ensureRepoUnlocked(context, repo);
                      if (unlocked) await workspace.loadDir();
                    },
                    child: Text(L10n.of(context).unlock),
                  ),
                if (workspace.needsUnlock) const SizedBox(width: 8),
                OutlinedButton(onPressed: () => workspace.loadDir(), child: Text(L10n.of(context).retry)),
              ],
            ),
          ],
        ),
      );
    } else if (workspace.loading && workspace.entries.isEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (entries.isEmpty) {
      content = EmptyState(
        title: workspace.filter.isNotEmpty ? L10n.of(context).noMatchingFiles : L10n.of(context).emptyFolder,
        message: workspace.filter.isNotEmpty ? null : L10n.of(context).emptyFolderHint,
        icon: 'folder-open',
        action: workspace.canWrite && workspace.filter.isEmpty
            ? OutlinedButton.icon(
                onPressed: widget.onUploadFiles,
                icon: const WebIcon('upload-files', size: 14),
                label: Text(L10n.of(context).uploadFiles),
              )
            : null,
      );
    } else {
      content = workspace.viewMode == FileViewMode.grid
          ? _buildGrid(context, workspace, repo, entries)
          : _buildList(context, workspace, repo, entries);
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        final paths = detail.files.map((file) => file.path).where((path) => path.isNotEmpty).toList();
        if (paths.isNotEmpty) widget.onUploadPaths(paths);
      },
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: content),
              if (detailEntry != null)
                DetailsPanel(
                  workspace: workspace,
                  entry: detailEntry,
                  width: widget.detailsWidth,
                  onResize: widget.onDetailsResize,
                  onClose: widget.onCloseDetails,
                ),
            ],
          ),
          if (workspace.loading && workspace.entries.isNotEmpty)
            const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator(minHeight: 2)),
          if (_dragging)
            Positioned.fill(
              child: Container(
                color: AppColors.primary.withValues(alpha: 0.06),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WebIcon('upload-files', size: 22, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(L10n.of(context).dropToUpload, style: const TextStyle(fontSize: 14, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, WorkspaceController workspace, Repository repo, List<Dirent> entries) {
    final l10n = L10n.of(context);
    final showTags = workspace.hasTags;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tagsWidth = showTags && constraints.maxWidth > 820 ? 190.0 : 0.0;
        return Column(
          children: [
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.tableHeader,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Checkbox(
                      value: entries.isNotEmpty && entries.every(workspace.isSelected),
                      tristate: true,
                      onChanged: (value) => workspace.selectAll(value ?? false),
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: _SortHeader(
                      label: l10n.name,
                      active: workspace.sortField == SortField.name,
                      ascending: workspace.ascending,
                      onTap: () => workspace.setSortField(SortField.name),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: _SortHeader(
                        label: l10n.size,
                        active: workspace.sortField == SortField.size,
                        ascending: workspace.ascending,
                        onTap: () => workspace.setSortField(SortField.size),
                        alignEnd: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: _SortHeader(
                      label: l10n.modified,
                      active: workspace.sortField == SortField.modified,
                      ascending: workspace.ascending,
                      onTap: () => workspace.setSortField(SortField.modified),
                    ),
                  ),
                  if (tagsWidth > 0)
                    SizedBox(
                      width: tagsWidth,
                      child: Text(l10n.tags, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _FileRow(
                      key: ValueKey(entry.path),
                      repo: repo,
                      entry: entry,
                      index: index,
                      selected: workspace.isSelected(entry),
                      tags: workspace.tagsFor(entry),
                      showTags: tagsWidth > 0,
                      tagsWidth: tagsWidth,
                      onTap: () => _handleTap(entry, index),
                      onCheck: () => workspace.toggleSelection(entry, additive: true),
                      onStar: () => toggleStar(context, workspace, entry),
                      onContextMenu: (position) => _showContextMenu(entry, position),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, WorkspaceController workspace, Repository repo, List<Dirent> entries) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 190).floor().clamp(2, 8);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 168,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _FileGridCard(
              key: ValueKey(entry.path),
              repo: repo,
              entry: entry,
              selected: workspace.isSelected(entry),
              onTap: () => _handleTap(entry, index),
              onCheck: () => workspace.toggleSelection(entry, additive: true),
              onContextMenu: (position) => _showContextMenu(entry, position),
              onStar: () => toggleStar(context, workspace, entry),
            );
          },
        );
      },
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: hovered ? AppColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? AppColors.text : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 3),
                Transform.rotate(
                  angle: ascending ? 0 : 3.14159,
                  child: const Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    super.key,
    required this.repo,
    required this.entry,
    required this.index,
    required this.selected,
    required this.tags,
    required this.showTags,
    required this.tagsWidth,
    required this.onTap,
    required this.onCheck,
    required this.onStar,
    required this.onContextMenu,
  });

  final Repository repo;
  final Dirent entry;
  final int index;
  final bool selected;
  final List<TagInfo> tags;
  final bool showTags;
  final double tagsWidth;
  final VoidCallback onTap;
  final VoidCallback onCheck;
  final VoidCallback onStar;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          height: 46,
          padding: const EdgeInsets.only(left: 8, right: 12),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.selected : (_hovered ? AppColors.hover : Colors.white),
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: (_) => widget.onCheck(),
                ),
              ),
              SizedBox(
                width: 30,
                child: IconAction(
                  icon: entry.starred ? 'starred' : 'unstarred',
                  tooltip: entry.starred ? (l10n.zh ? '取消星标' : 'Remove star') : (l10n.zh ? '添加星标' : 'Add star'),
                  size: 15,
                  color: entry.starred ? const Color(0xFFF5A623) : AppColors.muted,
                  onPressed: widget.onStar,
                  padding: const EdgeInsets.all(4),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    FileTypeIcon(name: entry.name, isDir: entry.isDir, size: 24, permission: entry.permission),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: entry.isReadOnly ? AppColors.text : AppColors.primary,
                        ),
                      ),
                    ),
                    if (entry.locked) ...[
                      const SizedBox(width: 6),
                      const WebIcon('lock', size: 12, color: AppColors.muted),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(
                      entry.isDir ? '—' : formatBytes(entry.size),
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: Text(
                  formatRelative(entry.mtime, zh: l10n.zh),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              if (widget.showTags)
                SizedBox(
                  width: widget.tagsWidth,
                  child: Row(
                    children: [
                      for (final tag in widget.tags.take(2)) ...[
                        TagPill(tag: tag),
                        const SizedBox(width: 4),
                      ],
                      if (widget.tags.length > 2)
                        Text('+${widget.tags.length - 2}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileGridCard extends StatefulWidget {
  const _FileGridCard({
    super.key,
    required this.repo,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onCheck,
    required this.onContextMenu,
    required this.onStar,
  });

  final Repository repo;
  final Dirent entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCheck;
  final ValueChanged<Offset> onContextMenu;
  final VoidCallback onStar;

  @override
  State<_FileGridCard> createState() => _FileGridCardState();
}

class _FileGridCardState extends State<_FileGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.selected : (_hovered ? AppColors.hover : Colors.white),
            border: Border.all(color: widget.selected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: entry.isDir
                            ? FileTypeIcon(name: entry.name, isDir: true, size: 48)
                            : ThumbnailView(
                                repo: widget.repo,
                                entry: entry,
                                width: 140,
                                height: 96,
                                iconSize: 48,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.text, height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.isDir ? formatRelative(entry.mtime, zh: l10n.zh) : formatBytes(entry.size),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 4,
                top: 4,
                child: Checkbox(
                  value: widget.selected,
                  onChanged: (_) => widget.onCheck(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: IconAction(
                  icon: entry.starred ? 'starred' : 'unstarred',
                  tooltip: entry.starred ? (l10n.zh ? '取消星标' : 'Remove star') : (l10n.zh ? '添加星标' : 'Add star'),
                  size: 14,
                  color: entry.starred ? const Color(0xFFF5A623) : AppColors.muted,
                  onPressed: widget.onStar,
                  padding: const EdgeInsets.all(3),
                ),
              ),
              if (entry.isDir)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Text(
                    l10n.folder,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? first : null;
}
