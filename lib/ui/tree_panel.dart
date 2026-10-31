import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'new_menu.dart';
import 'widgets.dart';

class TreePanel extends StatefulWidget {
  const TreePanel({
    super.key,
    required this.workspace,
    required this.onUploadFiles,
    required this.onUploadFolder,
    required this.onNewFolder,
    required this.onRenameLibrary,
    required this.onDeleteLibrary,
    required this.onLibraryInfo,
    required this.onShareLibrary,
    this.showQuickActions = true,
  });

  final WorkspaceController workspace;
  final VoidCallback onUploadFiles;
  final VoidCallback onUploadFolder;
  final VoidCallback onNewFolder;
  final VoidCallback onRenameLibrary;
  final VoidCallback onDeleteLibrary;
  final VoidCallback onLibraryInfo;
  final VoidCallback onShareLibrary;
  final bool showQuickActions;

  @override
  State<TreePanel> createState() => _TreePanelState();
}

class _TreePanelState extends State<TreePanel> {
  bool _filesExpanded = true;
  bool _viewsExpanded = true;
  bool _tagsExpanded = true;
  bool _othersExpanded = true;
  bool? _watching;

  WorkspaceController get ws => widget.workspace;

  @override
  void didUpdateWidget(covariant TreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.repo?.id != widget.workspace.repo?.id) {
      _watching = null;
    }
  }

  Future<void> _toggleWatch() async {
    final l10n = L10n.of(context);
    final repo = ws.repo;
    if (repo == null) return;
    final watch = !(_watching ?? repo.monitored);
    try {
      final api = context.read<AppSession>().api!;
      if (watch) {
        await api.monitorRepository(repo.id);
      } else {
        await api.unmonitorRepository(repo.id);
      }
      if (!mounted) return;
      setState(() => _watching = watch);
      showToast(context, watch ? (l10n.zh ? '已关注资料库改动' : 'Now watching library changes') : (l10n.zh ? '已取消关注资料库' : 'Stopped watching library changes'));
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final root = workspace.root;
    return Container(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showQuickActions)
            Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: NewMenuButton(
                    workspace: workspace,
                    onUploadFiles: widget.onUploadFiles,
                    onUploadFolder: widget.onUploadFolder,
                  ),
                ),
                if (workspace.canUseAi) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: l10n.chatWithAi,
                    child: InkWell(
                      onTap: () => workspace.openChat(),
                      borderRadius: BorderRadius.circular(4),
                      hoverColor: AppColors.hover,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderStrong),
                          borderRadius: BorderRadius.circular(4),
                          color: workspace.mode == BrowseMode.chat ? AppColors.primarySoft : Colors.white,
                        ),
                        alignment: Alignment.center,
                        child: WebIcon('new-chat', size: 16, color: workspace.mode == BrowseMode.chat ? AppColors.primary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(
                    title: l10n.file,
                    expanded: _filesExpanded,
                    onToggle: () => setState(() => _filesExpanded = !_filesExpanded),
                    onTitleTap: () => ws.enterPath('/'),
                    active: workspace.mode == BrowseMode.files && workspace.path == '/' && workspace.selectedTagId == null,
                  ),
                  if (_filesExpanded && root != null)
                    for (final node in root.children)
                      _TreeNodeWidget(
                        node: node,
                        depth: 0,
                        workspace: workspace,
                      ),
                  if (_filesExpanded && root != null && root.children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(34, 4, 16, 4),
                      child: Text('—', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: l10n.view,
                    expanded: _viewsExpanded,
                    onToggle: () => setState(() => _viewsExpanded = !_viewsExpanded),
                  ),
                  if (_viewsExpanded)
                    _SimpleRow(
                      label: l10n.allFiles,
                      icon: 'table',
                      depth: 0,
                      active: workspace.mode == BrowseMode.files && workspace.path == '/' && workspace.selectedTagId == null,
                      onTap: () => ws.enterPath('/'),
                    ),
                  if (_viewsExpanded && workspace.hasTags) ...[
                    _SectionHeader(
                      title: l10n.tags,
                      expanded: _tagsExpanded,
                      onToggle: () => setState(() => _tagsExpanded = !_tagsExpanded),
                    ),
                    if (_tagsExpanded) ...[
                      _SimpleRow(
                        label: l10n.allTags,
                        icon: 'tag-stroked',
                        depth: 0,
                        active: workspace.selectedTagId == null,
                        onTap: () => ws.selectTag(null),
                      ),
                      for (final tag in workspace.tags)
                        _TagRow(
                          name: tag.name,
                          color: tag.color,
                          active: workspace.selectedTagId == tag.id,
                          onTap: () => ws.selectTag(tag.id),
                        ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: l10n.other,
                    expanded: _othersExpanded,
                    onToggle: () => setState(() => _othersExpanded = !_othersExpanded),
                  ),
                  if (_othersExpanded) ...[
                    _SimpleRow(
                      label: (_watching ?? ws.repo?.monitored ?? false) ? l10n.unwatchFileChanges : l10n.watchFileChanges,
                      icon: 'notification',
                      depth: 0,
                      active: false,
                      onTap: _toggleWatch,
                    ),
                    _SimpleRow(
                      label: l10n.settings,
                      icon: 'settings',
                      depth: 0,
                      active: workspace.mode == BrowseMode.settings,
                      onTap: workspace.openSettings,
                    ),
                    _SimpleRow(
                      label: l10n.trash,
                      icon: 'trash',
                      depth: 0,
                      active: workspace.mode == BrowseMode.trash,
                      onTap: workspace.openTrash,
                    ),
                    _SimpleRow(
                      label: l10n.historyNav,
                      icon: 'history',
                      depth: 0,
                      active: workspace.mode == BrowseMode.history,
                      onTap: workspace.openHistory,
                    ),
                    _MoreRow(
                      onRename: widget.onRenameLibrary,
                      onDelete: widget.onDeleteLibrary,
                      onInfo: widget.onLibraryInfo,
                      onShare: widget.onShareLibrary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.onTitleTap,
    this.active = false,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onTitleTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTitleTap,
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          color: active ? AppColors.hover : (hovered ? AppColors.hover : Colors.transparent),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Transform.rotate(
                    angle: expanded ? 0 : -1.57,
                    child: const WebIcon('down', size: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreeNodeWidget extends StatefulWidget {
  const _TreeNodeWidget({required this.node, required this.depth, required this.workspace});

  final TreeNode node;
  final int depth;
  final WorkspaceController workspace;

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final workspace = widget.workspace;
    final active = workspace.mode == BrowseMode.files && workspace.path == node.path && workspace.selectedTagId == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: () => workspace.enterPath(node.path),
            hoverColor: Colors.transparent,
            child: Container(
              height: 32,
              color: active ? AppColors.hover : (_hovered ? AppColors.hover : Colors.transparent),
              padding: EdgeInsets.only(left: 14.0 + widget.depth * 15, right: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => workspace.toggleTree(node),
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 18,
                      height: 24,
                      child: Center(
                        child: node.loading
                            ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                            : Transform.rotate(
                                angle: node.expanded ? 1.57 : 0,
                                child: const WebIcon('arrow-right', size: 10, color: AppColors.muted),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const WebIcon('folder', size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? AppColors.primary : AppColors.text,
                        fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (node.expanded)
          for (final child in node.children)
            _TreeNodeWidget(node: child, depth: widget.depth + 1, workspace: workspace),
      ],
    );
  }
}

class _SimpleRow extends StatefulWidget {
  const _SimpleRow({
    required this.label,
    required this.icon,
    required this.depth,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final int depth;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SimpleRow> createState() => _SimpleRowState();
}

class _SimpleRowState extends State<_SimpleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        child: Container(
          height: 32,
          color: widget.active ? AppColors.hover : (_hovered ? AppColors.hover : Colors.transparent),
          padding: EdgeInsets.only(left: 34.0 + widget.depth * 15, right: 12),
          child: Row(
            children: [
              WebIcon(widget.icon, size: 15, color: widget.active ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.active ? AppColors.primary : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends StatefulWidget {
  const _TagRow({required this.name, required this.color, required this.active, required this.onTap});

  final String name;
  final String color;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  bool _hovered = false;

  Color get _color {
    final parsed = int.tryParse(widget.color.replaceFirst('#', ''), radix: 16);
    if (parsed == null) return AppColors.primary;
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        child: Container(
          height: 30,
          color: widget.active ? AppColors.hover : (_hovered ? AppColors.hover : Colors.transparent),
          padding: const EdgeInsets.only(left: 35, right: 12),
          child: Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: widget.active ? AppColors.primary : AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.onRename,
    required this.onDelete,
    required this.onInfo,
    required this.onShare,
  });

  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 32),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'refresh', child: _row('refresh', l10n.refresh)),
        PopupMenuItem(value: 'info', child: _row('info', l10n.libraryInfo)),
        PopupMenuItem(value: 'share', child: _row('share', l10n.shareLink)),
        PopupMenuItem(value: 'rename', child: _row('rename', l10n.renameLibrary)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: _row('delete', l10n.deleteLibrary, danger: true)),
      ],
      onSelected: (value) {
        final workspace = context.read<WorkspaceController>();
        switch (value) {
          case 'refresh':
            workspace.refresh();
          case 'info':
            onInfo();
          case 'share':
            onShare();
          case 'rename':
            onRename();
          case 'delete':
            onDelete();
        }
      },
      child: HoverBuilder(
        builder: (context, hovered) => Container(
          height: 32,
          padding: const EdgeInsets.only(left: 35, right: 12),
          color: hovered ? AppColors.hover : Colors.transparent,
          child: Row(
            children: [
              const WebIcon('more-vertical', size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.more, style: const TextStyle(fontSize: 13, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
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
}
