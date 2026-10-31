import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'repo_actions.dart';
import 'widgets.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.onOpen});

  final void Function(Repository repo, String path, bool isDir)? onOpen;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unseen = 0;
  bool _available = true;
  NotificationBundle? _bundle;
  final Set<int> _readIds = {};
  bool _loadingBundle = false;
  String? _error;
  MenuController? _menuController;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    try {
      final bundle = await api.notifications(perPage: 1);
      if (!mounted) return;
      setState(() {
        _unseen = bundle.totalUnseen;
        _available = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _available = false;
      });
    }
  }

  Future<void> _loadBundle() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    setState(() {
      _loadingBundle = true;
      _error = null;
    });
    try {
      final bundle = await api.notifications(perPage: 25);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _unseen = bundle.totalUnseen;
        _loadingBundle = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBundle = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _markAllRead() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    try {
      await api.markAllNotificationsRead();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _unseen = 0;
      for (final item in _bundle?.items ?? const <NotificationItem>[]) {
        _readIds.add(item.id);
      }
    });
  }

  Future<void> _openItem(NotificationItem item, MenuController controller) async {
    if (!_readIds.contains(item.id)) {
      setState(() {
        _readIds.add(item.id);
        if (_unseen > 0) _unseen--;
      });
      try {
        await context.read<AppSession>().api!.markNotificationRead(
              item,
              discussion: item.type == 'reply' || item.type == 'comment',
            );
      } catch (_) {}
    }
    final repoId = item.repoId;
    if (repoId.isEmpty) return;
    final session = context.read<AppSession>();
    final repo = session.findRepo(repoId);
    if (repo == null) return;
    controller.close();
    if (!await ensureRepoUnlocked(context, repo) || !mounted) return;
    final filePath = item.filePath;
    final folderPath = item.folderPath;
    if (filePath.isNotEmpty) {
      widget.onOpen?.call(repo, filePath, false);
    } else if (folderPath.isNotEmpty) {
      widget.onOpen?.call(repo, folderPath, true);
    }
  }

  String _message(NotificationItem item, L10n l10n) {
    final detail = item.detail;
    final repo = item.repoName;
    final file = (detail['file_name'] as String?) ?? '';
    final folder = (detail['folder_name'] as String?) ?? '';
    switch (item.type) {
      case 'file_uploaded':
        return l10n.notificationFileUploaded(file.isNotEmpty ? file : (detail['folder_name'] as String? ?? ''), repo);
      case 'folder_uploaded':
        return l10n.notificationFileUploaded(folder.isNotEmpty ? folder : file, repo);
      case 'file_comment':
        return l10n.notificationFileComment(file, repo);
      case 'repo_share':
        final path = detail['path'] as String? ?? '/';
        return path == '/'
            ? l10n.notificationRepoShare(repo)
            : l10n.notificationFolderShare((detail['folder_name'] as String?) ?? path, repo);
      case 'repo_share_to_group':
        return l10n.notificationRepoShare(repo);
      case 'add_user_to_group':
        return l10n.notificationGroup((detail['group_name'] as String?) ?? '');
      case 'deleted_files':
        return l10n.notificationDeleted(repo);
      case 'reply':
      case 'comment':
        return l10n.notificationDiscussion(repo);
      case 'repo_monitor':
      case 'repo_share_perm_change':
      case 'repo_share_perm_delete':
        return l10n.notificationFileUploaded(file.isNotEmpty ? file : repo, repo);
      default:
        if (file.isNotEmpty) return l10n.notificationFileUploaded(file, repo);
        return l10n.notificationGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (!_available) return const SizedBox.shrink();
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        )),
      ),
      alignmentOffset: const Offset(-340, 8),
      menuChildren: [
        SizedBox(
          width: 400,
          height: 470,
          child: Column(
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.only(left: 14, right: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    Text(l10n.notifications, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    if (_unseen > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        child: Text('$_unseen', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _unseen == 0 ? null : _markAllRead,
                      child: Text(l10n.markAllRead, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loadingBundle
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          )
                        : (_bundle?.items.isEmpty ?? true)
                            ? EmptyState(title: l10n.notificationsEmpty, message: l10n.notificationsHint, icon: 'notification')
                            : ListView.separated(
                                itemCount: _bundle!.items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                                itemBuilder: (context, index) {
                                  final item = _bundle!.items[index];
                                  final read = item.seen || _readIds.contains(item.id);
                                  return _NotificationRow(
                                    item: item,
                                    message: _message(item, l10n),
                                    read: read,
                                    onTap: () async {
                                      final controller = _menuController;
                                      if (controller != null) await _openItem(item, controller);
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        _menuController = controller;
        return HoverBuilder(
          builder: (context, hovered) => InkWell(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
                _loadBundle();
              }
            },
            hoverColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: hovered ? AppColors.hover : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const WebIcon('notification', size: 19),
                  if (_unseen > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(7)),
                        alignment: Alignment.center,
                        child: Text(
                          _unseen > 99 ? '99+' : '$_unseen',
                          style: const TextStyle(fontSize: 8, color: Colors.white, height: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.message, required this.read, required this.onTap});

  final NotificationItem item;
  final String message;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.hover,
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: read ? AppColors.hover : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: WebIcon('notification', size: 14, color: read ? AppColors.textSecondary : AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.5)),
                  const SizedBox(height: 3),
                  Text(formatRelative(item.time, zh: l10n.zh), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (!read)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, left: 6),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
