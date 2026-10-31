import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'deleted_libraries_dialog.dart';
import 'dialogs.dart';
import 'repo_actions.dart';
import 'sidebar.dart';
import 'widgets.dart';

enum _LibrarySort { name, size, modified }

class LibraryHome extends StatefulWidget {
  const LibraryHome({
    super.key,
    required this.filter,
    required this.onOpenLibraries,
    required this.onOpenRepository,
    this.onOpenWeb,
  });

  final LibraryFilter filter;
  final VoidCallback onOpenLibraries;
  final ValueChanged<Repository> onOpenRepository;
  final void Function(String path, String title)? onOpenWeb;

  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  _LibrarySort _sort = _LibrarySort.name;
  bool _ascending = true;
  bool _grid = false;

  Future<void> _openRepo(Repository repo) async {
    if (!await ensureRepoUnlocked(context, repo)) return;
    if (!mounted) return;
    widget.onOpenRepository(repo);
  }

  Future<void> _createLibrary() async {
    final l10n = L10n.of(context);
    final created = await showCreateLibraryDialog(context);
    if (created != null && mounted) showToast(context, l10n.libraryCreated);
  }

  Future<void> _createGroup() async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.newGroup,
      label: l10n.name,
      validator: (value) => value.trim().isEmpty ? l10n.name : null,
    );
    if (name == null || !mounted) return;
    try {
      await context.read<AppSession>().api!.createUserGroup(name.trim());
      await context.read<AppSession>().refreshLibraries();
      if (mounted) showToast(context, l10n.zh ? '群组已创建' : 'Group created');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _renameLibrary(Repository repo) async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.renameLibrary,
      label: l10n.libraryName,
      initialValue: repo.name,
      validator: (value) => value.trim().isEmpty ? l10n.libraryNameRequired : null,
    );
    if (name == null || !mounted) return;
    try {
      await context.read<AppSession>().api!.renameLibrary(repo.id, name.trim());
      await context.read<AppSession>().refreshLibraries();
      if (mounted) showToast(context, l10n.libraryRenamed);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteLibrary(Repository repo) async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLibrary,
      message: l10n.deleteLibraryConfirm(repo.name),
      danger: true,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.deleteLibrary(repo.id);
      await context.read<AppSession>().refreshLibraries();
      if (mounted) showToast(context, l10n.libraryDeleted);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _showContextMenu(Repository repo, Offset position) async {
    final l10n = L10n.of(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(value: 'open', child: _menuRow('folder-open', l10n.open)),
        PopupMenuItem(value: 'star', child: _menuRow('starred', repo.starred ? (l10n.zh ? '取消星标' : 'Remove star') : (l10n.zh ? '添加星标' : 'Add star'))),
        if (repo.isOwner) PopupMenuItem(value: 'rename', child: _menuRow('rename', l10n.rename)),
        if (repo.isOwner) const PopupMenuDivider(),
        if (repo.isOwner) PopupMenuItem(value: 'delete', child: _menuRow('delete', l10n.delete, danger: true)),
      ],
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'open':
        await _openRepo(repo);
      case 'star':
        try {
          await context.read<AppSession>().api!.setStarred(repoId: repo.id, path: '/', starred: !repo.starred);
          await context.read<AppSession>().refreshLibraries();
        } catch (error) {
          if (mounted) showToast(context, friendlyError(context, error), error: true);
        }
      case 'rename':
        await _renameLibrary(repo);
      case 'delete':
        await _deleteLibrary(repo);
    }
  }

  Widget _menuRow(String icon, String label, {bool danger = false}) {
    return Row(
      children: [
        WebIcon(icon, size: 16, color: danger ? AppColors.danger : AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: danger ? AppColors.danger : AppColors.text)),
      ],
    );
  }

  List<Repository> get _allRepos {
    final repos = context.watch<AppSession>().repositories;
    return switch (widget.filter) {
      LibraryFilter.all => repos,
      LibraryFilter.mine => repos.where((repo) => repo.kind == 'mine').toList(),
      LibraryFilter.shared => repos.where((repo) => repo.kind == 'shared').toList(),
      LibraryFilter.group => repos.where((repo) => repo.kind == 'group').toList(),
    };
  }

  List<Repository> _sortRepos(Iterable<Repository> repos) {
    final list = repos.toList();
    list.sort((a, b) {
      int result;
      switch (_sort) {
        case _LibrarySort.name:
          result = compareNatural(a.name, b.name);
        case _LibrarySort.size:
          result = a.size.compareTo(b.size);
        case _LibrarySort.modified:
          result = (a.mtime?.millisecondsSinceEpoch ?? 0).compareTo(b.mtime?.millisecondsSinceEpoch ?? 0);
      }
      return _ascending ? result : -result;
    });
    return list;
  }

  void _setSort(_LibrarySort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final l10n = L10n.of(context);
    final repos = _allRepos;
    final mine = _sortRepos(repos.where((repo) => repo.kind == 'mine'));
    final shared = _sortRepos(repos.where((repo) => repo.kind == 'shared'));
    final publicRepos = _sortRepos(repos.where((repo) => repo.kind == 'public'));
    final groups = <String, List<Repository>>{};
    for (final repo in repos.where((repo) => repo.kind == 'group')) {
      groups.putIfAbsent(repo.groupName?.isNotEmpty == true ? repo.groupName! : l10n.groupLibraries, () => []).add(repo);
    }

    final sections = <Widget>[];
    if (widget.filter == LibraryFilter.all || widget.filter == LibraryFilter.mine) {
      sections.add(_buildSection(
        title: l10n.myLibraries,
        icon: 'my-libraries',
        repos: mine,
        showNew: true,
        emptyMessage: l10n.noLibraries,
      ));
    }
    if (widget.filter == LibraryFilter.all || widget.filter == LibraryFilter.shared) {
      sections.add(_buildSection(
        title: l10n.sharedWithMe,
        icon: 'share-with-me',
        repos: shared,
        emptyMessage: l10n.noSharedLibraries,
      ));
    }
    if (widget.filter == LibraryFilter.all || widget.filter == LibraryFilter.group) {
      final names = groups.keys.toList()..sort(compareNatural);
      for (final name in names) {
        sections.add(_buildSection(
          title: name,
          icon: 'group',
          repos: _sortRepos(groups[name]!),
          emptyMessage: l10n.noMatches,
        ));
      }
    }
    if (widget.filter == LibraryFilter.all) {
      sections.add(_buildSection(
        title: l10n.owner == '' ? '公共资料库' : (l10n.zh ? '公共资料库' : 'Public libraries'),
        icon: 'organizations',
        repos: publicRepos,
        emptyMessage: l10n.noPublicLibraries,
      ));
    }

    return Column(
      children: [
        _buildHeader(context, l10n, session),
        Expanded(
          child: session.repositories.isEmpty && session.loadingLibraries
              ? const Center(child: CircularProgressIndicator())
              : session.repositories.isEmpty
                  ? EmptyState(
                      title: l10n.noLibraries,
                      message: l10n.noLibrariesHint,
                      icon: 'libraries',
                      action: FilledButton(onPressed: _createLibrary, child: Text(l10n.createLibrary)),
                    )
                  : RefreshIndicator(
                      onRefresh: session.refreshLibraries,
                      color: AppColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
                        children: [
                          if (session.librariesError != null)
                            _ErrorBanner(
                              message: session.librariesError!.friendly(l10n),
                              onRetry: session.refreshLibraries,
                            ),
                          ...sections,
                          if (widget.filter == LibraryFilter.all) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _createGroup,
                                icon: const WebIcon('plus-sign', size: 14),
                                label: Text(l10n.newGroup),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, L10n l10n, AppSession session) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(l10n.libraries, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text)),
          const Spacer(),
          IconAction(
            icon: _grid ? 'list-view' : 'grid-view',
            tooltip: _grid ? l10n.listView : l10n.gridView,
            size: 18,
            onPressed: () => setState(() => _grid = !_grid),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: l10n.sortBy,
            offset: const Offset(0, 34),
            color: Colors.white,
            shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
            itemBuilder: (context) => [
              _sortItem(context, 'name', l10n.sortName, _LibrarySort.name),
              _sortItem(context, 'size', l10n.sortSize, _LibrarySort.size),
              _sortItem(context, 'modified', l10n.sortModified, _LibrarySort.modified),
            ],
            onSelected: (value) => _setSort(switch (value) {
              'size' => _LibrarySort.size,
              'modified' => _LibrarySort.modified,
              _ => _LibrarySort.name,
            }),
            child: HoverBuilder(
              builder: (context, hovered) => Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hovered ? AppColors.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const WebIcon('sort-ascending', size: 18),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            offset: const Offset(0, 34),
            color: Colors.white,
            shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'refresh', child: _menuRow('refresh', l10n.refresh)),
              PopupMenuItem(value: 'create', child: _menuRow('new-folder', l10n.newLibrary)),
            ],
            onSelected: (value) {
              if (value == 'refresh') session.refreshLibraries();
              if (value == 'create') _createLibrary();
            },
            child: HoverBuilder(
              builder: (context, hovered) => Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hovered ? AppColors.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const WebIcon('more-vertical', size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortItem(BuildContext context, String value, String label, _LibrarySort sort) {
    final active = _sort == sort;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          SizedBox(width: 24, child: active ? const WebIcon('check', size: 14, color: AppColors.primary) : null),
          Text(label, style: TextStyle(fontSize: 13, color: active ? AppColors.primary : AppColors.text)),
          if (active) ...[
            const Spacer(),
            WebIcon(_ascending ? 'sort-ascending' : 'sort-descending', size: 14, color: AppColors.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String icon,
    required List<Repository> repos,
    required String emptyMessage,
    bool showNew = false,
  }) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                WebIcon(icon, size: 17, color: AppColors.textSecondary),
                const SizedBox(width: 7),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
                if (showNew) ...[
                  const SizedBox(width: 7),
                  IconAction(icon: 'plus-sign', tooltip: l10n.newLibrary, size: 15, onPressed: _createLibrary),
                ],
                const Spacer(),
                if (showNew)
                  TextButton(
                    onPressed: () => showDeletedLibrariesDialog(context),
                    child: Text(l10n.deletedLibraries, style: const TextStyle(fontSize: 13, color: AppColors.text)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (repos.isEmpty)
            Container(
              height: 50,
              alignment: Alignment.center,
              child: Text(emptyMessage, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            )
          else
            _grid ? _buildGrid(repos, session) : _buildTable(repos, session),
        ],
      ),
    );
  }

  Widget _buildTable(List<Repository> repos, AppSession session) {
    final l10n = L10n.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 40,
            color: AppColors.tableHeader,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const SizedBox(width: 34),
                Expanded(flex: 4, child: Text(l10n.name, style: _headerStyle)),
                SizedBox(width: 110, child: Text(l10n.size, style: _headerStyle)),
                SizedBox(width: 160, child: Text(l10n.modified, style: _headerStyle)),
                SizedBox(width: 150, child: Text(l10n.owner, style: _headerStyle)),
              ],
            ),
          ),
          for (var index = 0; index < repos.length; index++)
            _RepositoryRow(
              repo: repos[index],
              session: session,
              last: index == repos.length - 1,
              onTap: () => _openRepo(repos[index]),
              onContextMenu: (position) => _showContextMenu(repos[index], position),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Repository> repos, AppSession session) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 760 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: repos.length,
          itemBuilder: (context, index) {
            final repo = repos[index];
            return _RepositoryGridCard(
              repo: repo,
              session: session,
              onTap: () => _openRepo(repo),
              onContextMenu: (position) => _showContextMenu(repo, position),
            );
          },
        );
      },
    );
  }

  static const _headerStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w400);
}

class _RepositoryRow extends StatefulWidget {
  const _RepositoryRow({
    required this.repo,
    required this.session,
    required this.last,
    required this.onTap,
    required this.onContextMenu,
  });

  final Repository repo;
  final AppSession session;
  final bool last;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_RepositoryRow> createState() => _RepositoryRowState();
}

class _RepositoryRowState extends State<_RepositoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final repo = widget.repo;
    final owner = repo.kind == 'mine'
        ? widget.session.displayName
        : (repo.ownerDisplay.isNotEmpty ? repo.ownerDisplay : (repo.groupName ?? ''));
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hover : Colors.white,
            border: widget.last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 34),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    RepoTypeIcon(repo: repo, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        repo.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.primary),
                      ),
                    ),
                    if (repo.encrypted) ...[
                      const SizedBox(width: 6),
                      const WebIcon('lock', size: 13, color: AppColors.muted),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(formatBytes(repo.size), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
              SizedBox(
                width: 160,
                child: Text(formatRelative(repo.mtime, zh: l10n.zh), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
              SizedBox(
                width: 150,
                child: Text(
                  owner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepositoryGridCard extends StatefulWidget {
  const _RepositoryGridCard({
    required this.repo,
    required this.session,
    required this.onTap,
    required this.onContextMenu,
  });

  final Repository repo;
  final AppSession session;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_RepositoryGridCard> createState() => _RepositoryGridCardState();
}

class _RepositoryGridCardState extends State<_RepositoryGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onContextMenu(details.globalPosition),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hover : Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              RepoTypeIcon(repo: widget.repo, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.repo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatBytes(widget.repo.size)} · ${formatRelative(widget.repo.mtime, zh: l10n.zh)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          const WebIcon('exclamation-circle', size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
          TextButton(onPressed: onRetry, child: Text(L10n.of(context).retry)),
        ],
      ),
    );
  }
}
