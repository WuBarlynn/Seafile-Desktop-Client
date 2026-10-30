import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'app_shell.dart';
import 'widgets.dart';

enum LibraryFilter { all, mine, shared, group }

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.collapsed,
    required this.section,
    required this.filter,
    required this.librariesExpanded,
    required this.onToggleLibraries,
    required this.onSection,
    required this.onFilter,
    required this.onOpenLibraries,
    required this.onHelp,
    required this.onClients,
    required this.onAbout,
    required this.onInviteGuests,
    required this.onToggleCollapse,
  });

  final bool collapsed;
  final ShellSection section;
  final LibraryFilter filter;
  final bool librariesExpanded;
  final VoidCallback onToggleLibraries;
  final ValueChanged<ShellSection> onSection;
  final ValueChanged<LibraryFilter> onFilter;
  final VoidCallback onOpenLibraries;
  final VoidCallback onHelp;
  final VoidCallback onClients;
  final VoidCallback onAbout;
  final VoidCallback onInviteGuests;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    final mineCount = session.repositories.where((repo) => repo.kind == 'mine').length;
    final sharedCount = session.repositories.where((repo) => repo.kind == 'shared').length;
    final groupCount = session.repositories.where((repo) => repo.kind == 'group').length;

    return Container(
      color: AppColors.sidebar,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 14, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 16, 10),
                      child: Text(
                        l10n.workspace,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ),
                  _NavItem(
                    icon: 'libraries',
                    label: l10n.libraries,
                    collapsed: collapsed,
                    active: section == ShellSection.libraries,
                    onTap: onOpenLibraries,
                    trailing: collapsed
                        ? null
                        : IconAction(
                            icon: 'down',
                            tooltip: librariesExpanded ? l10n.collapse : l10n.expand,
                            onPressed: onToggleLibraries,
                            size: 12,
                            color: AppColors.textSecondary,
                            padding: const EdgeInsets.all(5),
                          ),
                    trailingRotation: librariesExpanded ? 0 : -1.57,
                  ),
                  if (!collapsed && librariesExpanded) ...[
                    _SubNavItem(
                      label: l10n.myLibraries,
                      count: mineCount,
                      active: section == ShellSection.libraries && filter == LibraryFilter.mine,
                      onTap: () => onFilter(LibraryFilter.mine),
                    ),
                    _SubNavItem(
                      label: l10n.sharedWithMe,
                      count: sharedCount,
                      active: section == ShellSection.libraries && filter == LibraryFilter.shared,
                      onTap: () => onFilter(LibraryFilter.shared),
                    ),
                    _SubNavItem(
                      label: l10n.groupLibraries,
                      count: groupCount,
                      active: section == ShellSection.libraries && filter == LibraryFilter.group,
                      onTap: () => onFilter(LibraryFilter.group),
                    ),
                    const SizedBox(height: 4),
                  ],
                  _NavItem(
                    icon: 'favorites',
                    label: l10n.favorites,
                    collapsed: collapsed,
                    active: section == ShellSection.favorites,
                    onTap: () => onSection(ShellSection.favorites),
                  ),
                  _NavItem(
                    icon: 'activities',
                    label: l10n.activities,
                    collapsed: collapsed,
                    active: section == ShellSection.activities,
                    onTap: () => onSection(ShellSection.activities),
                  ),
                  _NavItem(
                    icon: 'wiki',
                    label: l10n.wikis,
                    collapsed: collapsed,
                    active: section == ShellSection.wikis,
                    onTap: () => onSection(ShellSection.wikis),
                  ),
                  _NavItem(
                    icon: 'invite-guests',
                    label: l10n.inviteGuests,
                    collapsed: collapsed,
                    active: section == ShellSection.inviteGuests,
                    onTap: onInviteGuests,
                  ),
                  _NavItem(
                    icon: 'share-admin',
                    label: l10n.shareAdmin,
                    collapsed: collapsed,
                    active: section == ShellSection.shareAdmin,
                    onTap: () => onSection(ShellSection.shareAdmin),
                  ),
                  const SizedBox(height: 24),
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 16, 10),
                      child: Text(
                        l10n.helpResources,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ),
                  _NavItem(icon: 'help', label: l10n.help, collapsed: collapsed, active: false, onTap: onHelp),
                  _NavItem(icon: 'clients', label: l10n.clients, collapsed: collapsed, active: false, onTap: onClients),
                  _NavItem(icon: 'about', label: l10n.about, collapsed: collapsed, active: false, onTap: onAbout),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: _CollapseButton(collapsed: collapsed, label: l10n.collapseSidebar, onTap: onToggleCollapse),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.active,
    required this.onTap,
    this.trailing,
    this.trailingRotation = 0,
  });

  final String icon;
  final String label;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;
  final Widget? trailing;
  final double trailingRotation;

  @override
  Widget build(BuildContext context) {
    final content = HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF2F2F2) : (hovered ? AppColors.hover : Colors.transparent),
          ),
          child: Row(
            children: [
              Container(width: 3, height: 40, color: active ? AppColors.primary : Colors.transparent),
              if (collapsed)
                Expanded(
                  child: Center(child: WebIcon(icon, size: 20, color: active ? AppColors.text : AppColors.textSecondary)),
                )
              else ...[
                const SizedBox(width: 15),
                WebIcon(icon, size: 20, color: active ? AppColors.text : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null)
                  Transform.rotate(
                    angle: trailingRotation,
                    child: Padding(padding: const EdgeInsets.only(right: 10), child: trailing),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ],
          ),
        ),
      ),
    );
    final cursorContent = MouseRegion(cursor: SystemMouseCursors.click, child: content);
    return collapsed ? Tooltip(message: label, child: cursorContent) : cursorContent;
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({required this.label, required this.count, required this.active, required this.onTap});

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: 32,
          color: active ? const Color(0xFFF2F2F2) : (hovered ? AppColors.hover : Colors.transparent),
          padding: const EdgeInsets.only(left: 47, right: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (count > 0)
                Text('$count', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.label, required this.onTap});

  final bool collapsed;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          height: 44,
          color: hovered ? AppColors.hover : Colors.transparent,
          padding: EdgeInsets.only(left: collapsed ? 0 : 18, right: collapsed ? 0 : 14),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              WebIcon(collapsed ? 'unfold-sidebar' : 'fold-sidebar', size: 18, color: AppColors.textSecondary),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
