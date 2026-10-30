import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'activities_page.dart';
import 'browser_view.dart';
import 'dialogs.dart';
import 'library_home.dart';
import 'notification_bell.dart';
import 'share_admin_page.dart';
import 'starred_page.dart';
import 'repo_actions.dart';
import 'preview_page.dart';
import 'search_dialog.dart';
import 'sidebar.dart';
import 'transfers_panel.dart';
import 'wiki_page.dart';
import 'widgets.dart';

enum ShellSection { libraries, favorites, activities, wikis, shareAdmin }

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

  void _selectSection(ShellSection section) {
    final workspace = context.read<WorkspaceController>();
    if (section != ShellSection.libraries) {
      workspace.closeRepo();
    } else {
      workspace.closeRepo();
    }
    setState(() => _section = section);
  }

  void _selectLibraryFilter(LibraryFilter filter) {
    final workspace = context.read<WorkspaceController>();
    workspace.closeRepo();
    setState(() {
      _section = ShellSection.libraries;
      _filter = filter;
    });
  }

  void _openLibraries() {
    final workspace = context.read<WorkspaceController>();
    workspace.closeRepo();
    setState(() {
      _section = ShellSection.libraries;
      _filter = LibraryFilter.all;
    });
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
    await session.signOut();
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
    await workspace.openRepo(repo);
    if (!mounted) return;
    await workspace.enterPath(parentRepoPath(result.path));
    if (!mounted || result.isDir) return;
    Dirent? entry;
    for (final item in workspace.entries) {
      if (item.path == result.path) {
        entry = item;
        break;
      }
    }
    if (entry != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => PreviewPage(repo: repo, entry: entry!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final workspace = context.watch<WorkspaceController>();
    final l10n = L10n.of(context);
    if (workspace.repoId != null) {
      _section = ShellSection.libraries;
    }
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
                      child: workspace.repoId != null
                          ? const BrowserView()
                          : switch (_section) {
                              ShellSection.libraries => LibraryHome(
                                  filter: _filter,
                                  onOpenLibraries: _openLibraries,
                                ),
                              ShellSection.favorites => const StarredPage(),
                              ShellSection.activities => const ActivitiesPage(),
                              ShellSection.wikis => const WikiPage(),
                              ShellSection.shareAdmin => const ShareAdminPage(),
                            },
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
}

class _GlobalHeader extends StatelessWidget {
  const _GlobalHeader({
    required this.sidebarWidth,
    required this.collapsed,
    required this.onSearch,
    required this.onAbout,
    required this.onRefresh,
    required this.onLogout,
  });

  final double sidebarWidth;
  final bool collapsed;
  final VoidCallback onSearch;
  final VoidCallback onAbout;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

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
                  const NotificationBell(),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: '',
                    offset: const Offset(0, 40),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      PopupMenuItem<String>(
                        value: 'refresh',
                        child: Row(children: [const WebIcon('refresh', size: 16), const SizedBox(width: 10), Text(l10n.refreshLibraries)]),
                      ),
                      PopupMenuItem<String>(
                        value: 'about',
                        child: Row(children: [const WebIcon('about', size: 16), const SizedBox(width: 10), Text(l10n.about)]),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(children: [const WebIcon('close', size: 16, color: AppColors.danger), const SizedBox(width: 10), Text(l10n.logout, style: const TextStyle(color: AppColors.danger))]),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'refresh') onRefresh();
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
                        child: AvatarCircle(name: session.displayName, size: 32),
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

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          alignment: Alignment.centerLeft,
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: EmptyState(title: title, message: description, icon: icon)),
      ],
    );
  }
}
