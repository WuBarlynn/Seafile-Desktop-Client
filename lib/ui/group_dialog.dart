import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

Future<void> showGroupDialog(BuildContext context, {required int groupId, required String groupName, VoidCallback? onChanged}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GroupDialog(groupId: groupId, groupName: groupName, onChanged: onChanged),
  );
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({required this.groupId, required this.groupName, this.onChanged});

  final int groupId;
  final String groupName;
  final VoidCallback? onChanged;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  int _tab = 0;
  bool _loading = true;
  Map<String, dynamic> _group = const {};
  List<Map<String, dynamic>> _libraries = const [];
  List<Map<String, dynamic>> _members = const [];
  final _email = TextEditingController();
  final _libraryName = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _libraryName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppSession>().api!;
      final results = await Future.wait([
        api.userGroup(widget.groupId),
        api.userGroupLibraries(widget.groupId),
        api.userGroupMembers(widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as Map<String, dynamic>;
        _libraries = results[1] as List<Map<String, dynamic>>;
        _members = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _addMember() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<AppSession>().api!.addUserGroupMember(widget.groupId, email);
      _email.clear();
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final email = '${member['email'] ?? ''}';
    if (email.isEmpty) return;
    try {
      await context.read<AppSession>().api!.removeUserGroupMember(widget.groupId, email);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _createLibrary() async {
    final name = _libraryName.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<AppSession>().api!.createUserGroupLibrary(widget.groupId, name);
      _libraryName.clear();
      await _load();
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteGroup() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除群组' : 'Delete group'),
        content: Text(l10n.zh ? '确定删除 ${widget.groupName}？' : 'Delete ${widget.groupName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<AppSession>().api!.deleteUserGroup(widget.groupId);
      widget.onChanged?.call();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return AlertDialog(
      title: Row(
        children: [
          Text(widget.groupName),
          const Spacer(),
          if (!_loading && '${_group['owner'] ?? ''}' == context.read<AppSession>().username)
            TextButton.icon(
              onPressed: _deleteGroup,
              icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
              label: Text(l10n.delete, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${zh ? '所有者' : 'Owner'}: ${_group['owner'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in [(0, zh ? '资料库' : 'Libraries'), (1, zh ? '成员' : 'Members')])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
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
                              child: Text(entry.$2, style: TextStyle(fontSize: 12.5, color: _tab == entry.$1 ? AppColors.primaryDark : AppColors.textSecondary)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _tab == 0 ? _librariesView(zh) : _membersView(zh)),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(zh ? '关闭' : 'Close')),
      ],
    );
  }

  Widget _librariesView(bool zh) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _libraryName,
                onSubmitted: (_) => _createLibrary(),
                decoration: InputDecoration(labelText: zh ? '新建群组资料库' : 'New group library', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _createLibrary, child: Text(zh ? '创建' : 'Create', style: const TextStyle(fontSize: 12))),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _libraries.isEmpty
              ? Center(child: Text(zh ? '暂无群组资料库' : 'No group libraries', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)))
              : ListView.separated(
                  itemCount: _libraries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final library = _libraries[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const WebIcon('libraries', size: 17, color: AppColors.textSecondary),
                      title: Text('${library['name'] ?? library['repo_name'] ?? ''}', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(formatBytes((library['size'] as num?)?.toInt() ?? 0), style: const TextStyle(fontSize: 11.5)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _membersView(bool zh) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _email,
                onSubmitted: (_) => _addMember(),
                decoration: InputDecoration(labelText: zh ? '成员邮箱' : 'Member email', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _addMember, child: Text(zh ? '添加' : 'Add', style: const TextStyle(fontSize: 12))),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _members.isEmpty
              ? Center(child: Text(zh ? '暂无成员' : 'No members', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)))
              : ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final email = '${member['email'] ?? ''}';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${member['name'] ?? email}', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(email, style: const TextStyle(fontSize: 11.5)),
                      trailing: IconButton(
                        onPressed: () => _removeMember(member),
                        icon: const Icon(Icons.person_remove_outlined, size: 16, color: AppColors.danger),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
