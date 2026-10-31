import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class ShareAdminPage extends StatefulWidget {
  const ShareAdminPage({super.key});

  @override
  State<ShareAdminPage> createState() => _ShareAdminPageState();
}

class _ShareAdminPageState extends State<ShareAdminPage> {
  List<ShareLink> _links = [];
  List<Map<String, dynamic>> _uploads = [];
  List<Map<String, dynamic>> _sharedRepos = [];
  int _tab = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([api.shareLinks(perPage: 200), api.uploadLinks(perPage: 200), api.sharedRepos()]);
      if (!mounted) return;
      setState(() {
        _links = results[0] as List<ShareLink>;
        _uploads = results[1] as List<Map<String, dynamic>>;
        _sharedRepos = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _copy(ShareLink link) async {
    final session = context.read<AppSession>();
    final l10n = L10n.of(context);
    await Clipboard.setData(ClipboardData(text: link.linkForServer(session.serverBase)));
    if (mounted) showToast(context, l10n.linkCopied);
  }

  Future<void> _delete(ShareLink link) async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLink,
      message: l10n.deleteLinkConfirm,
      danger: true,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.deleteShareLink(link.token);
      if (!mounted) return;
      setState(() => _links = _links.where((item) => item.token != link.token).toList());
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _copyUpload(Map<String, dynamic> link, AppSession session) async {
    final l10n = L10n.of(context);
    final token = '${link['token'] ?? ''}';
    final raw = '${link['link'] ?? ''}';
    final url = raw.isNotEmpty ? raw : '${session.serverBase}/u/d/$token/';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showToast(context, l10n.linkCopied);
  }

  Future<void> _deleteUpload(Map<String, dynamic> link) async {
    final l10n = L10n.of(context);
    final token = '${link['token'] ?? ''}';
    if (token.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLink,
      message: l10n.deleteLinkConfirm,
      danger: true,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.deleteUploadLink(token);
      if (!mounted) return;
      setState(() => _uploads = _uploads.where((item) => '${item['token'] ?? ''}' != token).toList());
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _sharedReposView(L10n l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final items = _sharedRepos.where((item) {
      final path = '${item['path'] ?? '/'}';
      return _tab == 0 ? (path.isEmpty || path == '/') : (path.isNotEmpty && path != '/');
    }).toList();
    if (items.isEmpty) {
      return EmptyState(
        title: _tab == 0 ? (l10n.zh ? '没有共享的资料库' : 'No shared libraries') : (l10n.zh ? '没有共享的目录' : 'No shared folders'),
        message: _tab == 0
            ? (l10n.zh ? '你还没共享任何资料库给其他用户。' : 'You have not shared any library with other users.')
            : (l10n.zh ? '你还没共享任何目录给其他用户。' : 'You have not shared any folder with other users.'),
        icon: _tab == 0 ? 'libraries' : 'folder',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final item = items[index];
        final name = '${item['repo_name'] ?? item['name'] ?? ''}';
        final path = '${item['path'] ?? '/'}';
        final from = '${item['from_user'] ?? item['from_email'] ?? item['share_to'] ?? ''}';
        final permission = '${item['permission'] ?? ''}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: WebIcon(_tab == 0 ? 'libraries' : 'folder', size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(path == '/' ? name : baseName(path), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      '$name · $path${from.isEmpty ? '' : ' · $from'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (permission.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(4)),
                  child: Text(permission, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ),
              const SizedBox(width: 4),
              IconAction(icon: 'delete', tooltip: l10n.zh ? '取消共享' : 'Unshare', size: 15, color: AppColors.danger, onPressed: () => _unshareShared(item)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unshareShared(Map<String, dynamic> item) async {
    final l10n = L10n.of(context);
    final repoId = '${item['repo_id'] ?? item['id'] ?? ''}';
    final shareType = '${item['share_type'] ?? 'personal'}';
    if (repoId.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.zh ? '取消共享' : 'Unshare',
      message: l10n.zh ? '确定取消共享 ${item['repo_name'] ?? item['name'] ?? ''}？' : 'Unshare ${item['repo_name'] ?? item['name'] ?? ''}?',
      danger: true,
      confirmLabel: l10n.zh ? '取消共享' : 'Unshare',
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.unshareSharedRepo(
        repoId,
        shareType: shareType,
        user: '${item['user_email'] ?? item['user'] ?? ''}',
        groupId: (item['group_id'] as num?)?.toInt(),
        path: '${item['path'] ?? '/'}',
      );
      if (!mounted) return;
      setState(() => _sharedRepos = _sharedRepos.where((entry) => '${entry['repo_id'] ?? entry['id'] ?? ''}' != repoId || '${entry['share_type'] ?? 'personal'}' != shareType).toList());
      showToast(context, l10n.zh ? '已取消共享' : 'Unshared');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _cleanInvalidLinks() async {
    final l10n = L10n.of(context);
    try {
      await context.read<AppSession>().api!.cleanInvalidShareLinks();
      await _load();
      if (mounted) showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _uploadLinksView(L10n l10n, AppSession session) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (_uploads.isEmpty) {
      return EmptyState(
        title: l10n.zh ? '暂无上传链接' : 'No upload links',
        message: l10n.zh ? '你创建的所有上传链接会显示在这里。' : 'All upload links you created are listed here.',
        icon: 'upload-files',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _uploads.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final link = _uploads[index];
        final title = '${link['obj_name'] ?? link['repo_name'] ?? baseName('${link['path'] ?? '/'}')}';
        final token = '${link['token'] ?? ''}';
        final url = '${link['link'] ?? '${session.serverBase}/u/d/$token/'}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: const WebIcon('upload-files', size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${link['repo_name'] ?? ''} · ${link['path'] ?? '/'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(url, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconAction(icon: 'copy', tooltip: l10n.copyLink, size: 15, onPressed: () => _copyUpload(link, session)),
              IconAction(icon: 'delete', tooltip: l10n.deleteLink, size: 15, color: AppColors.danger, onPressed: () => _deleteUpload(link)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('share-admin', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.shareAdmin, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
            ],
          ),
        ),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              for (final entry in [(0, l10n.zh ? '资料库' : 'Libraries'), (1, l10n.zh ? '目录' : 'Folders'), (2, l10n.zh ? '链接' : 'Links'), (3, l10n.zh ? '上传链接' : 'Upload links')])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => setState(() => _tab = entry.$1),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _tab == entry.$1 ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        entry.$2,
                        style: TextStyle(fontSize: 12.5, color: _tab == entry.$1 ? AppColors.primaryDark : AppColors.textSecondary, fontWeight: _tab == entry.$1 ? FontWeight.w500 : FontWeight.w400),
                      ),
                    ),
                  ),
                ),
              if (_tab == 2) ...[
                const Spacer(),
                TextButton(onPressed: _cleanInvalidLinks, child: Text(l10n.zh ? '清理无效链接' : 'Clean invalid links', style: const TextStyle(fontSize: 12))),
              ],
            ],
          ),
        ),
        Expanded(
          child: _tab == 3 ? _uploadLinksView(l10n, session) : _tab <= 1 ? _sharedReposView(l10n) : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
                        ],
                      ),
                    )
                  : _links.isEmpty
                      ? EmptyState(title: l10n.shareAdminEmpty, message: l10n.shareAdminHint, icon: 'share-admin')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _links.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            final title = link.objName ?? baseName(link.path ?? '/');
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                                    alignment: Alignment.center,
                                    child: const WebIcon('links', size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: AppColors.text)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${link.repoName?.isNotEmpty == true ? '${link.repoName} · ' : ''}${link.path ?? '/'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 3),
                                        SelectableText(
                                          link.linkForServer(session.serverBase),
                                          maxLines: 1,
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        link.expireDate == null ? l10n.expireNever : formatDateTime(link.expireDate, withTime: false),
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                      if (link.hasPassword)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const WebIcon('lock', size: 10, color: AppColors.muted),
                                              const SizedBox(width: 3),
                                              Text(l10n.passwordProtected, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  IconAction(icon: 'copy', tooltip: l10n.copyLink, size: 15, onPressed: () => _copy(link)),
                                  IconAction(icon: 'delete', tooltip: l10n.deleteLink, size: 15, color: AppColors.danger, onPressed: () => _delete(link)),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
