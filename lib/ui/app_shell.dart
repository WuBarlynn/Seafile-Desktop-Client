import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'account_settings_page.dart';
import 'activities_page.dart';
import 'browser_view.dart';
import 'dialogs.dart';
import 'file_studio.dart';
import 'inline_web_editor.dart';
import 'library_home.dart';
import 'notification_bell.dart';
import 'repo_actions.dart';
import 'search_dialog.dart';
import 'share_admin_page.dart';
import 'sidebar.dart';
import 'starred_page.dart';
import 'system_settings_page.dart';
import 'transfers_panel.dart';
import 'web_handoff.dart';
import 'wiki_page.dart';
import 'widgets.dart';

enum ShellSection { libraries, favorites, activities, wikis, shareAdmin, inviteGuests }

enum _TabKind { home, library, file, account, system, web }

class _AppTab {
  _AppTab.home()
      : kind = _TabKind.home,
        title = '',
        workspace = null,
        repo = null,
        entry = null,
        editorKey = null,
        webPath = null;

  _AppTab.library(this.workspace, this.repo)
      : kind = _TabKind.library,
        title = repo!.name,
        entry = null,
        editorKey = null,
        webPath = null;

  _AppTab.file(this.workspace, this.repo, this.entry)
      : kind = _TabKind.file,
        title = entry!.name,
        editorKey = GlobalKey<FileStudioState>(),
        webPath = null;

  _AppTab.account()
      : kind = _TabKind.account,
        title = '',
        workspace = null,
        repo = null,
        entry = null,
        editorKey = null,
        webPath = null;

  _AppTab.system()
      : kind = _TabKind.system,
        title = '',
        workspace = null,
        repo = null,
        entry = null,
        editorKey = null,
        webPath = null;

  _AppTab.web(this.webPath, this.title)
      : kind = _TabKind.web,
        workspace = null,
        repo = null,
        entry = null,
        editorKey = null;

  final _TabKind kind;
  final String title;
  final WorkspaceController? workspace;
  final Repository? repo;
  final Dirent? entry;
  final GlobalKey<FileStudioState>? editorKey;
  final String? webPath;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;
  double? _sidebarWidth;
  bool _librariesExpanded = true;
  ShellSection _section = ShellSection.libraries;
  LibraryFilter _filter = LibraryFilter.all;
  final List<_AppTab> _tabs = [];
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs.add(_AppTab.home());
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.workspace?.dispose();
    }
    super.dispose();
  }

  void _selectSection(ShellSection section) {
    setState(() {
      _section = section;
      _activeIndex = 0;
    });
  }

  void _selectLibraryFilter(LibraryFilter filter) {
    setState(() {
      _section = ShellSection.libraries;
      _filter = filter;
      _activeIndex = 0;
    });
  }

  void _openLibraries() {
    setState(() {
      _section = ShellSection.libraries;
      _filter = LibraryFilter.all;
      _activeIndex = 0;
    });
  }

  Future<void> _openLibrary(Repository repo, {String? path}) async {
    final existing = _tabs.indexWhere((tab) => tab.kind == _TabKind.library && tab.repo?.id == repo.id);
    if (existing >= 0) {
      final workspace = _tabs[existing].workspace;
      if (path != null && workspace != null) await workspace.enterPath(path);
      if (!mounted) return;
      setState(() => _activeIndex = existing);
      return;
    }
    final session = context.read<AppSession>();
    final workspace = WorkspaceController(session);
    try {
      await workspace.openRepo(repo);
      if (path != null) await workspace.enterPath(path);
    } catch (_) {
      // The workspace surfaces its own error state inside the tab.
    }
    if (!mounted) {
      workspace.dispose();
      return;
    }
    setState(() {
      _tabs.add(_AppTab.library(workspace, repo));
      _activeIndex = _tabs.length - 1;
    });
  }

  Future<void> _openLibraryAt(Repository repo, String path) => _openLibrary(repo, path: path);

  void _openFile(Repository repo, Dirent entry) {
    final workspace = WorkspaceController(context.read<AppSession>());
    unawaited(workspace.openRepo(repo));
    setState(() {
      _tabs.add(_AppTab.file(workspace, repo, entry));
      _activeIndex = _tabs.length - 1;
    });
  }

  Future<void> _openPath(Repository repo, String path, bool isDir) async {
    if (isDir) {
      await _openLibrary(repo, path: path);
    } else {
      await _openFileByPath(repo, path);
    }
  }

  Future<void> _openFileByPath(Repository repo, String path) async {
    try {
      final api = context.read<AppSession>().api!;
      final detail = await api.fileDetail(repo.id, path);
      if (!mounted) return;
      _openFile(
        repo,
        Dirent(
          name: p.basename(path),
          path: path,
          isDir: false,
          size: detail.size ?? 0,
          mtime: detail.mtime,
          oid: detail.oid,
          permission: detail.permission,
        ),
      );
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  void _openAccountSettings() {
    final existing = _tabs.indexWhere((tab) => tab.kind == _TabKind.account);
    if (existing >= 0) {
      setState(() => _activeIndex = existing);
      return;
    }
    setState(() {
      _tabs.add(_AppTab.account());
      _activeIndex = _tabs.length - 1;
    });
  }

  void _openSystemSettings() {
    final existing = _tabs.indexWhere((tab) => tab.kind == _TabKind.system);
    if (existing >= 0) {
      setState(() => _activeIndex = existing);
      return;
    }
    setState(() {
      _tabs.add(_AppTab.system());
      _activeIndex = _tabs.length - 1;
    });
  }

  void _openWebPage(String path, String title) {
    final existing = _tabs.indexWhere((tab) => tab.kind == _TabKind.web && tab.webPath == path);
    if (existing >= 0) {
      setState(() => _activeIndex = existing);
      return;
    }
    setState(() {
      _tabs.add(_AppTab.web(path, title));
      _activeIndex = _tabs.length - 1;
    });
  }

  Future<void> _closeTab(int index) async {
    if (index <= 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (tab.kind == _TabKind.file) {
      final state = tab.editorKey?.currentState;
      if (state != null && !await state.confirmClose()) return;
      if (!mounted) return;
    }
    final workspace = tab.workspace;
    final wasActive = _activeIndex == index;
    setState(() {
      _tabs.removeAt(index);
      if (index < _activeIndex) {
        _activeIndex--;
      } else if (wasActive) {
        _activeIndex = (index - 1).clamp(0, _tabs.length - 1);
      }
    });
    workspace?.dispose();
  }

  Future<void> _openHelp(String path) async {
    final session = context.read<AppSession>();
    final uri = Uri.parse('${session.serverBase}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _logout() async {
    final l10n = L10n.of(context);
    final session = context.read<AppSession>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.logout,
      message: l10n.logoutConfirm,
      danger: true,
      confirmLabel: l10n.logout,
    );
    if (!confirmed) return;
    await clearAuthenticatedWeb();
    await session.signOut();
    if (!mounted) return;
    for (final tab in _tabs) {
      tab.workspace?.dispose();
    }
    setState(() {
      _tabs
        ..clear()
        ..add(_AppTab.home());
      _activeIndex = 0;
      _section = ShellSection.libraries;
      _filter = LibraryFilter.all;
    });
  }

  Future<void> _search() async {
    final workspace = context.read<WorkspaceController>();
    final result = await showGlobalSearchDialog(context, workspace);
    if (result == null || !mounted) return;
    final session = context.read<AppSession>();
    final repo = session.findRepo(result.repoId);
    if (repo == null) return;
    if (!await ensureRepoUnlocked(context, repo)) return;
    if (!mounted) return;
    await _openLibrary(repo, path: parentRepoPath(result.path));
    if (!mounted || result.isDir) return;
    await _openFileByPath(repo, result.path);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final defaultWidth = (constraints.maxWidth * 0.22).clamp(220.0, 306.0);
              final sidebarWidth = _collapsed ? 64.0 : (_sidebarWidth ?? defaultWidth);
              return Column(
                children: [
                  _GlobalHeader(
                    sidebarWidth: sidebarWidth,
                    collapsed: _collapsed,
                    onSearch: _search,
                    onAbout: () => showSeafileAboutDialog(context),
                    onRefresh: session.refreshLibraries,
                    onLogout: _logout,
                    onAccountSettings: _openAccountSettings,
                    onSystemSettings: _openSystemSettings,
                    onOpenNotification: _openPath,
                    onOpenWebPage: _openWebPage,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: sidebarWidth,
                          child: Sidebar(
                            collapsed: _collapsed,
                            section: _section,
                            filter: _filter,
                            librariesExpanded: _librariesExpanded,
                            onToggleLibraries: () => setState(() => _librariesExpanded = !_librariesExpanded),
                            onSection: _selectSection,
                            onFilter: _selectLibraryFilter,
                            onOpenLibraries: _openLibraries,
                            onHelp: () => _openHelp('/help/'),
                            onClients: () => _openHelp('/download_client_program/'),
                            onAbout: () => showSeafileAboutDialog(context),
                            onInviteGuests: () => setState(() {
                            _section = ShellSection.inviteGuests;
                            _activeIndex = 0;
                          }),
                            onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
                          ),
                        ),
                        if (!_collapsed)
                          ResizeHandle(
                            onDrag: (delta) => setState(() {
                              _sidebarWidth = (sidebarWidth + delta).clamp(200.0, (constraints.maxWidth * 0.4).clamp(240.0, 460.0));
                            }),
                          )
                        else
                          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                        Expanded(
                          child: Column(
                            children: [
                              _TabStrip(
                                tabs: _tabs,
                                activeIndex: _activeIndex,
                                onSelect: (index) => setState(() => _activeIndex = index),
                                onClose: _closeTab,
                              ),
                              Expanded(
                                child: IndexedStack(
                                  index: _activeIndex,
                                  children: [for (final tab in _tabs) _tabContent(tab)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const Positioned(right: 16, bottom: 16, child: TransfersPanel()),
        ],
      ),
    );
  }

  Widget _tabContent(_AppTab tab) {
    switch (tab.kind) {
      case _TabKind.home:
        return _homeContent();
      case _TabKind.library:
        return ChangeNotifierProvider<WorkspaceController>.value(
          value: tab.workspace!,
          child: BrowserView(
            onOpenFile: _openFile,
          ),
        );
      case _TabKind.file:
        return ChangeNotifierProvider<WorkspaceController>.value(
          value: tab.workspace!,
          child: FileStudio(key: tab.editorKey, repo: tab.repo!, entry: tab.entry!),
        );
      case _TabKind.account:
        return AccountSettingsPage(onOpenSystemSettings: _openSystemSettings);
      case _TabKind.system:
        return SystemSettingsPage(onOpenWeb: _openWebPage);
      case _TabKind.web:
        return InlineWebEditor.page(path: tab.webPath!);
    }
  }

  Widget _homeContent() {
    return switch (_section) {
      ShellSection.libraries => LibraryHome(
          filter: _filter,
          onOpenLibraries: _openLibraries,
          onOpenRepository: _openLibrary,
          onOpenWeb: _openWebPage,
        ),
      ShellSection.favorites => StarredPage(
          onOpenLibrary: _openLibraryAt,
          onOpenFile: _openFileByPath,
        ),
      ShellSection.activities => ActivitiesPage(
          onOpenLibrary: _openLibraryAt,
          onOpenFile: _openFileByPath,
        ),
      ShellSection.wikis => WikiPage(onOpenWeb: _openWebPage),
      ShellSection.shareAdmin => const ShareAdminPage(),
      ShellSection.inviteGuests => const InlineWebEditor.page(path: '/invitations/'),
    };
  }
}

class _TabStrip extends StatefulWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  final List<_AppTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _TabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex || oldWidget.tabs.length != widget.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        if (widget.activeIndex >= widget.tabs.length - 1) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F5),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < widget.tabs.length; index++)
                    _TabChip(
                      tab: widget.tabs[index],
                      active: index == widget.activeIndex,
                      closable: index > 0,
                      homeLabel: l10n.zh ? '主页' : 'Home',
                      accountLabel: l10n.accountSettings,
                      systemLabel: l10n.systemSettings,
                      onTap: () => widget.onSelect(index),
                      onClose: () => widget.onClose(index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({
    required this.tab,
    required this.active,
    required this.closable,
    required this.homeLabel,
    required this.accountLabel,
    required this.systemLabel,
    required this.onTap,
    required this.onClose,
  });

  final _AppTab tab;
  final bool active;
  final bool closable;
  final String homeLabel;
  final String accountLabel;
  final String systemLabel;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovered = false;
  bool _closeHovered = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final label = switch (tab.kind) {
      _TabKind.home => widget.homeLabel,
      _TabKind.library => tab.title,
      _TabKind.file => tab.title,
      _TabKind.account => widget.accountLabel,
      _TabKind.system => widget.systemLabel,
      _TabKind.web => tab.title,
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 230),
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: widget.active ? Colors.white : (_hovered ? const Color(0xFFF7F8FA) : Colors.transparent),
            border: Border(
              right: const BorderSide(color: AppColors.border),
              top: BorderSide(color: widget.active ? AppColors.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabIcon(tab),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: widget.active ? AppColors.text : AppColors.textSecondary,
                    fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (widget.closable)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _closeHovered = true),
                  onExit: (_) => setState(() => _closeHovered = false),
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _closeHovered ? AppColors.hover : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(Icons.close, size: 13, color: AppColors.muted),
                    ),
                  ),
                )
              else
                const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabIcon(_AppTab tab) {
    return switch (tab.kind) {
      _TabKind.home => const Icon(Icons.home_outlined, size: 15, color: AppColors.textSecondary),
      _TabKind.library => const WebIcon('folder', size: 15, color: AppColors.folder),
      _TabKind.file => FileTypeIcon(name: tab.entry?.name ?? '', isDir: false, size: 15),
      _TabKind.account => const WebIcon('settings', size: 15),
      _TabKind.system => const WebIcon('admin-logs', size: 15),
      _TabKind.web => const Icon(Icons.language, size: 15, color: AppColors.textSecondary),
    };
  }
}

class _GlobalHeader extends StatelessWidget {
  const _GlobalHeader({
    required this.sidebarWidth,
    required this.collapsed,
    required this.onSearch,
    required this.onAbout,
    required this.onRefresh,
    required this.onLogout,
    required this.onAccountSettings,
    required this.onSystemSettings,
    required this.onOpenNotification,
    required this.onOpenWebPage,
  });

  final double sidebarWidth;
  final bool collapsed;
  final VoidCallback onSearch;
  final VoidCallback onAbout;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final VoidCallback onAccountSettings;
  final VoidCallback onSystemSettings;
  final void Function(Repository repo, String path, bool isDir) onOpenNotification;
  final void Function(String path, String title) onOpenWebPage;

  PopupMenuItem<String> _menuItem(String value, String icon, String label, {bool danger = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          WebIcon(icon, size: 16, color: danger ? AppColors.danger : AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: danger ? AppColors.danger : AppColors.text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final l10n = L10n.of(context);
    final shortcut = Platform.isMacOS ? '⌘ + K' : 'Ctrl + K';
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: sidebarWidth,
            child: Padding(
              padding: EdgeInsets.only(left: collapsed ? 17 : 16),
              child: collapsed
                  ? const WebIcon('logo', size: 26, color: AppColors.primary)
                  : const Align(alignment: Alignment.centerLeft, child: SeafileLogo(height: 30)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Row(
                children: [
                  const Spacer(),
                  _SearchButton(onTap: onSearch, hint: '${l10n.searchFiles} ($shortcut)'),
                  const SizedBox(width: 10),
                  IconAction(
                    icon: 'open-in-new-tab',
                    tooltip: l10n.fullWebApp,
                    size: 18,
                    onPressed: () => onOpenWebPage('/libraries/', l10n.fullWebApp),
                  ),
                  const SizedBox(width: 2),
                  NotificationBell(onOpen: onOpenNotification),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: '',
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 8),
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 12,
                    menuPadding: const EdgeInsets.symmetric(vertical: 6),
                    constraints: const BoxConstraints(minWidth: 224),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 84,
                        child: SizedBox(
                          width: 260,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                session.displayName.isEmpty ? session.username : session.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                session.emailLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              _QuotaLine(session: session),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      _menuItem('refresh', 'refresh', l10n.refreshLibraries),
                      _menuItem('settings', 'settings', l10n.accountSettings),
                      _menuItem('webapp', 'link', l10n.fullWebApp),
                      if (session.accountInfo?.isStaff == true) _menuItem('admin', 'admin-logs', l10n.systemSettings),
                      _menuItem('about', 'about', l10n.about),
                      const PopupMenuDivider(),
                      _menuItem('logout', 'close', l10n.logout, danger: true),
                    ],
                    onSelected: (value) {
                      if (value == 'refresh') onRefresh();
                      if (value == 'settings') onAccountSettings();
                      if (value == 'admin') onSystemSettings();
                      if (value == 'webapp') onOpenWebPage('/libraries/', L10n.of(context).fullWebApp);
                      if (value == 'about') onAbout();
                      if (value == 'logout') onLogout();
                    },
                    child: HoverBuilder(
                      builder: (context, hovered) => Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hovered ? AppColors.hover : Colors.transparent,
                        ),
                        child: AvatarCircle(
                          name: session.displayName,
                          size: 32,
                          image: (session.avatarUrl?.isNotEmpty == true) ? NetworkImage(session.avatarUrl!) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap, required this.hint});

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: 320,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: hovered ? AppColors.primary : AppColors.borderStrong),
            borderRadius: BorderRadius.circular(4),
            color: hovered ? AppColors.hover : Colors.white,
          ),
          child: Row(
            children: [
              const WebIcon('search', size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaLine extends StatelessWidget {
  const _QuotaLine({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final total = session.quotaTotal;
    final usage = session.quotaUsage ?? 0;
    if (total == null || total <= 0) {
      return Text(l10n.unlimitedQuota, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }
    final fraction = session.quotaFraction ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.quotaUsage(formatBytes(usage), formatBytes(total)),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
