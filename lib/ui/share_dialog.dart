import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'widgets.dart';

Future<void> shareEntry(BuildContext context, WorkspaceController workspace, Dirent? entry) async {
  final repo = workspace.repo;
  if (repo == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _ShareDialog(
      workspace: workspace,
      repo: repo,
      entry: entry,
    ),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.workspace, required this.repo, this.entry});

  final WorkspaceController workspace;
  final Repository repo;
  final Dirent? entry;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _passwordController = TextEditingController();
  List<ShareLink> _links = [];
  bool _loading = true;
  bool _creating = false;
  int _expireDays = 0;
  bool _canDownload = true;
  bool _canUpload = false;
  bool _canEdit = false;
  String? _error;

  String get _path => widget.entry?.path ?? '/';
  bool get _isDir => widget.entry?.isDir ?? true;

  @override
  void initState() {
    super.initState();
    _canUpload = _isDir;
    _load();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    try {
      final links = await api.shareLinks(repoId: widget.repo.id, path: _path);
      if (!mounted) return;
      setState(() {
        _links = links;
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

  Future<void> _create() async {
    final api = context.read<AppSession>().api;
    if (api == null || _creating) return;
    final l10n = L10n.of(context);
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final link = await api.createShareLink(
        repoId: widget.repo.id,
        path: _path,
        password: _passwordController.text,
        expireDate: _expireDays > 0 ? DateTime.now().add(Duration(days: _expireDays)) : null,
        canDownload: _canDownload,
        canUpload: _isDir && _canUpload,
        canEdit: _canEdit,
      );
      if (!mounted) return;
      setState(() {
        _links = [link, ..._links];
        _creating = false;
        _passwordController.clear();
      });
      showToast(context, l10n.shareLinkCreated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _copy(ShareLink link) async {
    final l10n = L10n.of(context);
    final url = link.linkForServer(context.read<AppSession>().serverBase);
    await Clipboard.setData(ClipboardData(text: url));
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

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    final title = widget.entry?.name ?? widget.repo.name;
    return AlertDialog(
      title: Row(
        children: [
          const WebIcon('share', size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('${l10n.shareLink} · $title', maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shareLinkHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _links.isEmpty
                      ? Center(
                          child: Text(l10n.noShareLinks, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          itemCount: _links.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            return _LinkRow(
                              link: link,
                              serverBase: session.serverBase,
                              onCopy: () => _copy(link),
                              onDelete: () => _delete(link),
                            );
                          },
                        ),
            ),
            const Divider(height: 24),
            Text(l10n.createShareLink, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: false,
                    decoration: InputDecoration(labelText: l10n.linkPassword, hintText: l10n.optional),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _expireDays,
                    decoration: InputDecoration(labelText: l10n.expireDays),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(l10n.expireNever, style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 1, child: Text(l10n.expireOneDay, style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 7, child: Text(l10n.expireSevenDays, style: const TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 30, child: Text(l10n.expireThirtyDays, style: const TextStyle(fontSize: 13))),
                    ],
                    onChanged: _creating ? null : (value) => setState(() => _expireDays = value ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              children: [
                _permission(l10n.allowDownload, _canDownload, (value) => setState(() => _canDownload = value)),
                if (_isDir) _permission(l10n.allowUpload, _canUpload, (value) => setState(() => _canUpload = value)),
                if (!_isDir) _permission(l10n.allowEdit, _canEdit, (value) => setState(() => _canEdit = value)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const WebIcon('plus-sign', size: 14, color: Colors.white),
                label: Text(l10n.createLink),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }

  Widget _permission(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Checkbox(value: value, onChanged: _creating ? null : (selected) => onChanged(selected ?? false)),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.serverBase, required this.onCopy, required this.onDelete});

  final ShareLink link;
  final String serverBase;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final url = link.linkForServer(serverBase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const WebIcon('links', size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  url,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.primary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (link.hasPassword) ...[
                      const WebIcon('lock', size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(l10n.passwordProtected, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      link.expireDate == null
                          ? l10n.expireNever
                          : '${l10n.expiresOn} ${formatDateTime(link.expireDate)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconAction(icon: 'copy', tooltip: l10n.copyLink, size: 15, onPressed: onCopy),
          const SizedBox(width: 4),
          IconAction(icon: 'delete', tooltip: l10n.deleteLink, size: 15, color: AppColors.danger, onPressed: onDelete),
        ],
      ),
    );
  }
}
