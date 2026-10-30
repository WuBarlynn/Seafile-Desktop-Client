import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

Future<void> showPeopleShareDialog(
  BuildContext context, {
  required Repository repo,
  required String path,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PeopleShareDialog(repo: repo, path: path, title: title),
  );
}

class _PeopleShareDialog extends StatefulWidget {
  const _PeopleShareDialog({required this.repo, required this.path, required this.title});

  final Repository repo;
  final String path;
  final String title;

  @override
  State<_PeopleShareDialog> createState() => _PeopleShareDialogState();
}

class _PeopleShareDialogState extends State<_PeopleShareDialog> {
  final _emailController = TextEditingController();
  List<SharedAccess> _access = [];
  List<ShareableGroup> _groups = [];
  String? _selectedGroupId;
  String _userPermission = 'rw';
  String _groupPermission = 'rw';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await api.sharedAccess(widget.repo.id, widget.path);
      List<ShareableGroup> groups = [];
      try {
        groups = await api.shareableGroups();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _access = access;
        _groups = groups;
        _selectedGroupId = _selectedGroupId == null || !groups.any((g) => g.id == _selectedGroupId)
            ? (groups.isNotEmpty ? groups.first.id : null)
            : _selectedGroupId;
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

  Future<void> _addUser() async {
    final l10n = L10n.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = l10n.shareUserEmail);
      return;
    }
    await _share(type: 'user', ids: [email], permission: _userPermission);
    if (mounted) _emailController.clear();
  }

  Future<void> _addGroup() async {
    final groupId = _selectedGroupId;
    if (groupId == null) return;
    await _share(type: 'group', ids: [groupId], permission: _groupPermission);
  }

  Future<void> _share({required String type, required List<String> ids, required String permission}) async {
    final l10n = L10n.of(context);
    final api = context.read<AppSession>().api;
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await api.shareAccess(
        repoId: widget.repo.id,
        path: widget.path,
        type: type,
        ids: ids,
        permission: permission,
      );
      if (!mounted) return;
      if (result.failed.isNotEmpty) {
        setState(() => _error = result.failed.join('\n'));
      } else {
        showToast(context, l10n.shareSuccess);
      }
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SharedAccess access) async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.removeShare,
      message: '${l10n.removeShare}: ${access.name}',
      danger: true,
      confirmLabel: l10n.removeShare,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.removeSharedAccess(widget.repo.id, widget.path, access.type, access.id);
      if (!mounted) return;
      setState(() => _access = _access.where((item) => !(item.id == access.id && item.type == access.type)).toList());
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  String _permissionLabel(L10n l10n, String permission) {
    if (permission == 'r') return l10n.permissionReadOnly;
    if (permission == 'rw') return l10n.permissionReadWrite;
    return permission;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const WebIcon('share', size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('${l10n.shareWithPeople} · ${widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.peopleShareHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Text(l10n.sharedWithPeople, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 5,
                    child: _access.isEmpty
                        ? Center(child: Text(l10n.noSharedPeople, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)))
                        : ListView.separated(
                            itemCount: _access.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final access = _access[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    AvatarCircle(name: access.name, size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(access.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                          Text(
                                            '${access.type == 'group' ? l10n.groupLabel : l10n.userLabel} · ${_permissionLabel(l10n, access.permission)}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconAction(icon: 'delete', tooltip: l10n.removeShare, size: 14, color: AppColors.danger, onPressed: () => _remove(access)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(labelText: l10n.shareUserEmail, isDense: true),
                          onSubmitted: (_) => _addUser(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 105,
                        child: DropdownButtonFormField<String>(
                          initialValue: _userPermission,
                          decoration: const InputDecoration(isDense: true),
                          items: [
                            DropdownMenuItem(value: 'rw', child: Text(l10n.permissionReadWrite, style: const TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'r', child: Text(l10n.permissionReadOnly, style: const TextStyle(fontSize: 12))),
                          ],
                          onChanged: _busy ? null : (value) => setState(() => _userPermission = value ?? 'rw'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _busy ? null : _addUser, child: Text(l10n.addPerson)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_groups.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedGroupId,
                            decoration: InputDecoration(labelText: l10n.shareGroup, isDense: true),
                            items: [
                              for (final group in _groups)
                                DropdownMenuItem(value: group.id, child: Text(group.name, style: const TextStyle(fontSize: 12))),
                            ],
                            onChanged: _busy ? null : (value) => setState(() => _selectedGroupId = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 105,
                          child: DropdownButtonFormField<String>(
                            initialValue: _groupPermission,
                            decoration: const InputDecoration(isDense: true),
                            items: [
                              DropdownMenuItem(value: 'rw', child: Text(l10n.permissionReadWrite, style: const TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'r', child: Text(l10n.permissionReadOnly, style: const TextStyle(fontSize: 12))),
                            ],
                            onChanged: _busy ? null : (value) => setState(() => _groupPermission = value ?? 'rw'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _busy ? null : _addGroup, child: Text(l10n.addPerson)),
                      ],
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ],
                ],
              ),
      ),
    );
  }
}
