import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'admin/admin_pages.dart';
import 'widgets.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key, this.onOpenWeb});

  final void Function(String path, String title)? onOpenWeb;

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _sysInfo = const {};
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _libraries = const [];
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _shareLinks = const [];
  List<Map<String, dynamic>> _uploadLinks = const [];
  List<Map<String, dynamic>> _wikis = const [];
  List<Map<String, dynamic>> _trashLibraries = const [];
  Map<String, dynamic> _systemLibrary = const {};
  int _libraryTab = 0;
  int _shareTab = 0;
  int _reloadTick = 0;
  final _userQuery = TextEditingController();
  final _libraryQuery = TextEditingController();
  final _groupQuery = TextEditingController();
  bool _userShowAdmins = false;
  bool _loadingUsers = false;
  bool _loadingLibraries = false;
  bool _loadingWikis = false;
  bool _loadingTrashLibraries = false;
  bool _loadingSystemLibrary = false;
  bool _loadingGroups = false;
  bool _loadingShareLinks = false;
  bool _loadingUploadLinks = false;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _userQuery.dispose();
    _libraryQuery.dispose();
    _groupQuery.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await context.read<AppSession>().api!.adminSysInfo();
      if (!mounted) return;
      setState(() {
        _sysInfo = info;
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

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final data = await context.read<AppSession>().api!.adminUsers(query: _userQuery.text.trim());
      if (!mounted) return;
      setState(() {
        _users = (data['data'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingUsers = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadLibraries() async {
    setState(() => _loadingLibraries = true);
    try {
      final data = await context.read<AppSession>().api!.adminLibraries(query: _libraryQuery.text.trim());
      if (!mounted) return;
      setState(() {
        _libraries = (data['repos'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingLibraries = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingLibraries = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadWikis() async {
    setState(() => _loadingWikis = true);
    try {
      final data = await context.read<AppSession>().api!.adminWikis();
      if (!mounted) return;
      setState(() {
        _wikis = (data['wikis'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingWikis = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingWikis = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadTrashLibraries() async {
    setState(() => _loadingTrashLibraries = true);
    try {
      final data = await context.read<AppSession>().api!.adminTrashLibraries();
      if (!mounted) return;
      setState(() {
        _trashLibraries = (data['repos'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingTrashLibraries = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingTrashLibraries = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadSystemLibrary() async {
    setState(() => _loadingSystemLibrary = true);
    try {
      final data = await context.read<AppSession>().api!.adminSystemLibrary();
      if (!mounted) return;
      setState(() {
        _systemLibrary = data;
        _loadingSystemLibrary = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSystemLibrary = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final data = await context.read<AppSession>().api!.adminGroups(name: _groupQuery.text.trim());
      if (!mounted) return;
      setState(() {
        _groups = (data['groups'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingGroups = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingGroups = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadShareLinks() async {
    setState(() => _loadingShareLinks = true);
    try {
      final data = await context.read<AppSession>().api!.adminShareLinks();
      if (!mounted) return;
      setState(() {
        _shareLinks = (data['share_link_list'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingShareLinks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingShareLinks = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _loadUploadLinks() async {
    setState(() => _loadingUploadLinks = true);
    try {
      final data = await context.read<AppSession>().api!.adminUploadLinks();
      if (!mounted) return;
      setState(() {
        _uploadLinks = (data['upload_link_list'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loadingUploadLinks = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingUploadLinks = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  void _loadLibraryTab() {
    switch (_libraryTab) {
      case 0:
        _loadLibraries();
      case 1:
        _loadWikis();
      case 2:
        _loadSystemLibrary();
      case 3:
        _loadTrashLibraries();
    }
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (tab == 4) _loadLibraryTab();
    if (tab == 5 && _users.isEmpty) _loadUsers();
    if (tab == 6 && _groups.isEmpty) _loadGroups();
    if (tab == 9) {
      if (_shareLinks.isEmpty) _loadShareLinks();
      if (_uploadLinks.isEmpty) _loadUploadLinks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('admin-logs', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 9),
              Text(l10n.systemSettings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => widget.onOpenWeb?.call('/sys/info/', l10n.systemSettings),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(l10n.zh ? '完整管理后台' : 'Full admin console', style: const TextStyle(fontSize: 12)),
              ),
              IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: () {
                _loadOverview();
                setState(() => _reloadTick++);
                if (_tab == 4) _loadLibraryTab();
                if (_tab == 5) _loadUsers();
                if (_tab == 6) _loadGroups();
                if (_tab == 9) {
                  _loadShareLinks();
                  _loadUploadLinks();
                }
              }),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 216,
                decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.border))),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(l10n.zh ? '系统管理' : 'Administration', style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
                    ),
                    _navItem(0, l10n.zh ? '信息' : 'Information', Icons.dashboard_outlined),
                    _navItem(1, l10n.zh ? '统计' : 'Statistics', Icons.insert_chart_outlined),
                    _navItem(2, l10n.zh ? '设备' : 'Devices', Icons.devices_outlined),
                    _navItem(3, l10n.zh ? '设置' : 'Settings', Icons.tune),
                    _navItem(4, l10n.zh ? '资料库' : 'Libraries', Icons.folder_outlined),
                    _navItem(5, l10n.zh ? '用户' : 'Users', Icons.people_outline),
                    _navItem(6, l10n.zh ? '群组' : 'Groups', Icons.groups_outlined),
                    _navItem(7, l10n.zh ? '组织架构' : 'Departments', Icons.account_tree_outlined),
                    _navItem(8, l10n.zh ? '通知' : 'Notifications', Icons.notifications_none),
                    _navItem(9, l10n.zh ? '链接' : 'Links', Icons.link),
                    _navItem(10, l10n.zh ? '日志' : 'Logs', Icons.history),
                    _navItem(11, l10n.zh ? '病毒扫描' : 'Virus scan', Icons.shield_outlined),
                    _navItem(12, l10n.zh ? '管理员日志' : 'Admin logs', Icons.admin_panel_settings_outlined),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F6F8),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  const SizedBox(height: 12),
                                  OutlinedButton(onPressed: _loadOverview, child: Text(l10n.retry)),
                                ],
                              ),
                            )
                          : switch (_tab) {
                              0 => _overview(l10n),
                              1 => AdminStatisticsPanel(reloadTick: _reloadTick),
                              2 => AdminDevicesPanel(reloadTick: _reloadTick),
                              3 => AdminSettingsPanel(reloadTick: _reloadTick),
                              4 => _librariesView(l10n),
                              5 => _usersView(l10n),
                              6 => _groupsView(l10n),
                              7 => AdminDepartmentsPanel(reloadTick: _reloadTick),
                              8 => AdminNotificationsPanel(reloadTick: _reloadTick),
                              9 => _shareLinksView(l10n),
                              10 => AdminLogsPanel(reloadTick: _reloadTick),
                              11 => AdminVirusPanel(reloadTick: _reloadTick),
                              _ => AdminAdminLogsPanel(reloadTick: _reloadTick),
                            },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navItem(int value, String label, IconData icon) {
    final active = _tab == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _selectTab(value),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: active ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
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
    );
  }

  Widget _overview(L10n l10n) {
    final stats = [
      (_sysInfo['users_count'] ?? 0, l10n.zh ? '用户总数' : 'Users', Icons.people_outline),
      (_sysInfo['active_users_count'] ?? 0, l10n.zh ? '活跃用户' : 'Active users', Icons.person_outline),
      (_sysInfo['repos_count'] ?? 0, l10n.zh ? '资料库' : 'Libraries', Icons.folder_outlined),
      (_sysInfo['total_files_count'] ?? 0, l10n.zh ? '文件' : 'Files', Icons.insert_drive_file_outlined),
      (_sysInfo['groups_count'] ?? 0, l10n.zh ? '群组' : 'Groups', Icons.groups_outlined),
      (formatBytes((_sysInfo['total_storage'] as num?)?.toInt() ?? 0), l10n.zh ? '存储占用' : 'Storage', Icons.storage_outlined),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 3.1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final stat in stats)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                            child: Icon(stat.$3, size: 20, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${stat.$1}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                              Text(stat.$2, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l10n.zh ? '许可信息' : 'License', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _uploadLicense,
                          icon: const Icon(Icons.upload_file_outlined, size: 15),
                          label: Text(l10n.zh ? '上传许可证' : 'Upload license', style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _row(l10n.zh ? '版本' : 'Edition', '${_sysInfo['is_pro'] == true ? 'Pro' : 'Community'}'),
                    _row(l10n.zh ? '许可用户数' : 'Licensed seats', '${_sysInfo['license_maxusers'] ?? '—'}'),
                    _row(l10n.zh ? '许可证到期' : 'License expiration', '${_sysInfo['license_expiration'] ?? '—'}'),
                    _row(l10n.zh ? '许可主体' : 'Licensed to', '${_sysInfo['license_to'] ?? '—'}'),
                    _row(l10n.zh ? '已连接设备' : 'Connected devices', '${_sysInfo['current_connected_devices_count'] ?? 0}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadLicense() async {
    final l10n = L10n.of(context);
    final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'license', extensions: ['lic', 'license', 'txt'])]);
    if (file == null) return;
    try {
      await context.read<AppSession>().api!.uploadAdminLicense(file.path);
      await _loadOverview();
      if (mounted) showToast(context, l10n.zh ? '许可证已更新' : 'License updated');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13, color: AppColors.text))),
        ],
      ),
    );
  }

  Widget _groupsView(L10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Row(
                children: [
                  Text(l10n.zh ? '群组' : 'Groups', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 240,
                    height: 32,
                    child: TextField(
                      controller: _groupQuery,
                      onSubmitted: (_) => _loadGroups(),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: l10n.zh ? '根据名称搜索群组' : 'Search groups by name',
                        prefixIcon: const Padding(padding: EdgeInsets.all(8), child: WebIcon('search', size: 14)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _loadGroups, child: Text(l10n.search, style: const TextStyle(fontSize: 12))),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _exportCsv('groups.csv', ['Name', 'Owner', 'Created'], [
                      for (final group in _groups)
                        [
                          '${group['name'] ?? ''}',
                          '${group['owner_name'] ?? group['owner'] ?? ''}',
                          '${group['created_at'] ?? ''}',
                        ],
                    ]),
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: Text(l10n.zh ? '导出 CSV' : 'Export CSV', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.group_add_outlined, size: 16),
                    label: Text(l10n.zh ? '新建群组' : 'New group', style: const TextStyle(fontSize: 12)),
                  ),
                  if (_loadingGroups) ...[
                    const SizedBox(width: 10),
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _table(
                headers: [l10n.name, l10n.zh ? '所有者' : 'Owner', l10n.zh ? '创建时间' : 'Created'],
                rows: [
                  for (final group in _groups)
                    [
                      '${group['name'] ?? ''}',
                      '${group['owner_name'] ?? group['owner'] ?? ''}',
                      '${group['created_at'] ?? '—'}'.replaceFirst('T', ' ').split('+').first,
                    ],
                ],
              ),
              if (_groups.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final group in _groups) ...[
                        OutlinedButton(
                          onPressed: () => _manageGroupMembers(group),
                          child: Text('${l10n.zh ? '成员' : 'Members'} ${group['name'] ?? ''}', style: const TextStyle(fontSize: 11.5)),
                        ),
                        OutlinedButton(
                          onPressed: () => _deleteGroup(group),
                          child: Text('${l10n.delete} ${group['name'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manageGroupMembers(Map<String, dynamic> group) async {
    final id = (group['id'] as num?)?.toInt();
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AdminMembersDialog(
        departmentId: id,
        departmentName: group['name']?.toString() ?? '',
        addressBook: false,
      ),
    );
    if (mounted) _loadGroups();
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final l10n = L10n.of(context);
    final id = (group['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除群组' : 'Delete group'),
        content: Text(l10n.zh ? '确定删除 ${group['name']}？' : 'Delete ${group['name']}?'),
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
      await context.read<AppSession>().api!.deleteAdminGroup(id);
      await _loadGroups();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _createGroup() async {
    final l10n = L10n.of(context);
    final name = TextEditingController();
    final owner = TextEditingController(text: context.read<AppSession>().username);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '新建群组' : 'New group'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: l10n.name)),
              const SizedBox(height: 12),
              TextField(controller: owner, decoration: InputDecoration(labelText: l10n.zh ? '所有者邮箱' : 'Owner email')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.create)),
        ],
      ),
    );
    final groupName = name.text.trim();
    final groupOwner = owner.text.trim();
    name.dispose();
    owner.dispose();
    if (result != true || groupName.isEmpty) return;
    try {
      await context.read<AppSession>().api!.createAdminGroup(groupName, groupOwner);
      await _loadGroups();
      if (mounted) showToast(context, l10n.zh ? '群组已创建' : 'Group created');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _shareLinksView(L10n l10n) {
    final shareRows = [
      for (final link in _shareLinks)
        [
          '${link['obj_name'] ?? ''}',
          '${link['creator_name'] ?? link['creator_email'] ?? ''}',
          '${link['view_cnt'] ?? 0}',
          '${(link['expire_date'] as String?)?.isNotEmpty == true ? link['expire_date'] : (l10n.zh ? '永久' : 'Never')}',
        ],
    ];
    final uploadRows = [
      for (final link in _uploadLinks)
        [
          '${link['obj_name'] ?? link['repo_name'] ?? ''}',
          '${link['creator_name'] ?? link['creator_email'] ?? ''}',
          '${link['view_cnt'] ?? link['upload_cnt'] ?? 0}',
          '${(link['expire_date'] as String?)?.isNotEmpty == true ? link['expire_date'] : (l10n.zh ? '永久' : 'Never')}',
        ],
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Row(
                children: [
                  Text(l10n.zh ? '链接' : 'Links', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_shareTab == 0 && _loadingShareLinks || _shareTab == 1 && _loadingUploadLinks)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final entry in [
                    (0, l10n.zh ? '分享链接' : 'Share links'),
                    (1, l10n.zh ? '上传链接' : 'Upload links'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() => _shareTab = entry.$1);
                          if (entry.$1 == 0 && _shareLinks.isEmpty) _loadShareLinks();
                          if (entry.$1 == 1 && _uploadLinks.isEmpty) _loadUploadLinks();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _shareTab == entry.$1 ? AppColors.primarySoft : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _shareTab == entry.$1 ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
                          ),
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _shareTab == entry.$1 ? AppColors.primaryDark : AppColors.textSecondary,
                              fontWeight: _shareTab == entry.$1 ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_shareTab == 0 && _loadingShareLinks || _shareTab == 1 && _loadingUploadLinks)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 14),
              _table(
                headers: [
                  l10n.name,
                  l10n.zh ? '创建者' : 'Creator',
                  _shareTab == 0 ? (l10n.zh ? '访问次数' : 'Views') : (l10n.zh ? '上传次数' : 'Uploads'),
                  l10n.zh ? '过期时间' : 'Expires',
                ],
                rows: _shareTab == 0 ? shareRows : uploadRows,
              ),
              if ((_shareTab == 0 ? _shareLinks : _uploadLinks).isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final link in (_shareTab == 0 ? _shareLinks : _uploadLinks))
                        OutlinedButton(
                          onPressed: () => _shareTab == 0
                              ? _deleteShareLink('${link['token'] ?? link['share_link'] ?? ''}')
                              : _deleteUploadLink('${link['token'] ?? link['link'] ?? ''}'),
                          child: Text(
                            '${l10n.delete} ${link['obj_name'] ?? link['repo_name'] ?? ''}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteShareLink(String token) async {
    if (token.isEmpty) return;
    try {
      await context.read<AppSession>().api!.deleteAdminShareLink(token);
      await _loadShareLinks();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteUploadLink(String token) async {
    if (token.isEmpty) return;
    try {
      await context.read<AppSession>().api!.deleteAdminUploadLink(token);
      await _loadUploadLinks();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  List<Map<String, dynamic>> get _visibleUsers =>
      _userShowAdmins ? _users.where((user) => user['is_staff'] == true).toList() : _users;

  Widget _usersView(L10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Row(
                children: [
                  for (final entry in [(false, l10n.zh ? '全部' : 'All'), (true, l10n.zh ? '管理' : 'Admins')])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _userShowAdmins = entry.$1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _userShowAdmins == entry.$1 ? AppColors.primarySoft : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _userShowAdmins == entry.$1 ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
                          ),
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _userShowAdmins == entry.$1 ? AppColors.primaryDark : AppColors.textSecondary,
                              fontWeight: _userShowAdmins == entry.$1 ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 260,
                    height: 34,
                    child: TextField(
                      controller: _userQuery,
                      onSubmitted: (_) => _loadUsers(),
                      decoration: InputDecoration(
                        hintText: l10n.zh ? '搜索用户邮箱或名称' : 'Search email or name',
                        prefixIcon: const Padding(padding: EdgeInsets.all(9), child: WebIcon('search', size: 15)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _loadUsers, child: Text(l10n.search)),
                  const Spacer(),
                  if (_loadingUsers) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _importUsers,
                    icon: const Icon(Icons.upload_file_outlined, size: 15),
                    label: Text(l10n.zh ? '导入用户' : 'Import users', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => _exportUsers(l10n),
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: Text(l10n.zh ? '导出 CSV' : 'Export CSV', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _createUser,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: Text(l10n.zh ? '新建用户' : 'New user', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _userTable(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importUsers() async {
    final l10n = L10n.of(context);
    final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'CSV', extensions: ['csv', 'txt'])]);
    if (file == null) return;
    try {
      await context.read<AppSession>().api!.importAdminUsers(file.path);
      await _loadUsers();
      if (mounted) showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _exportUsers(L10n l10n) async {
    await _exportCsv('users.csv', ['Email', 'Name', 'Role', 'Active', 'Quota used', 'Last login'], [
      for (final user in _visibleUsers)
        [
          '${user['email'] ?? ''}',
          '${user['name'] ?? ''}',
          user['is_staff'] == true ? 'Admin' : 'User',
          user['is_active'] == 1 || user['is_active'] == true ? 'Active' : 'Disabled',
          '${user['quota_usage'] ?? 0}',
          '${user['last_login'] ?? ''}',
        ],
    ]);
  }

  Future<void> _exportCsv(String name, List<String> headers, List<List<String>> rows) async {
    final l10n = L10n.of(context);
    final buffer = StringBuffer();
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    buffer.writeln(headers.map(cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(cell).join(','));
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return;
    await XFile.fromData(utf8.encode(buffer.toString()), mimeType: 'text/csv', name: name).saveTo(location.path);
    if (mounted) showToast(context, l10n.savedSuccessfully);
  }

  Widget _librariesView(L10n l10n) {
    final tabLabels = l10n.zh ? const ['全部', '知识库', '系统', '回收站'] : const ['All', 'Wikis', 'System', 'Trash'];
    final rows = switch (_libraryTab) {
      0 => _libraries,
      1 => _wikis,
      3 => _trashLibraries,
      _ => const <Map<String, dynamic>>[],
    };
    final loading = switch (_libraryTab) {
      0 => _loadingLibraries,
      1 => _loadingWikis,
      2 => _loadingSystemLibrary,
      _ => _loadingTrashLibraries,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.zh ? '资料库' : 'Libraries', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var index = 0; index < tabLabels.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() => _libraryTab = index);
                          _loadLibraryTab();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _libraryTab == index ? AppColors.primarySoft : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _libraryTab == index ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
                          ),
                          child: Text(
                            tabLabels[index],
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _libraryTab == index ? AppColors.primaryDark : AppColors.textSecondary,
                              fontWeight: _libraryTab == index ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_libraryTab == 0) ...[
                    SizedBox(
                      width: 240,
                      height: 32,
                      child: TextField(
                        controller: _libraryQuery,
                        onSubmitted: (_) => _loadLibraries(),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: l10n.zh ? '搜索名称或 ID' : 'Search name or ID',
                          prefixIcon: const Padding(padding: EdgeInsets.all(8), child: WebIcon('search', size: 14)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _createLibrary,
                      icon: const Icon(Icons.add, size: 15),
                      label: Text(l10n.zh ? '新建资料库' : 'New library', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (_libraryTab == 2)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_systemLibrary['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _row('ID', '${_systemLibrary['id'] ?? ''}'),
                      _row(l10n.zh ? '描述' : 'Description', '${_systemLibrary['description'] ?? ''}'),
                    ],
                  ),
                )
              else ...[
                _table(
                  headers: _libraryTab == 0
                      ? [l10n.name, l10n.zh ? '所有者' : 'Owner', l10n.fileSize, l10n.zh ? '文件数' : 'Files', l10n.modified]
                      : _libraryTab == 1
                          ? [l10n.name, l10n.zh ? '所有者' : 'Owner', l10n.fileSize, l10n.zh ? '文件数' : 'Files', l10n.modified]
                          : [l10n.name, l10n.zh ? '所有者' : 'Owner', l10n.fileSize, l10n.zh ? '删除时间' : 'Deleted'],
                  rows: [
                    for (final repo in rows)
                      [
                        '${repo['name'] ?? repo['repo_name'] ?? ''}',
                        '${repo['owner_name'] ?? repo['owner_email'] ?? repo['owner'] ?? ''}',
                        '${repo['size_formatted'] ?? formatBytes((repo['size'] as num?)?.toInt() ?? 0)}',
                        _libraryTab == 3
                            ? '${repo['delete_time'] ?? repo['deleted_at'] ?? '—'}'.replaceFirst('T', ' ').split('+').first
                            : '${repo['file_count'] ?? 0}',
                        if (_libraryTab != 3) '${repo['last_modified'] ?? '—'}'.replaceFirst('T', ' ').split('+').first,
                      ],
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final repo in rows) ...[
                          if (_libraryTab != 3)
                            OutlinedButton(
                              onPressed: () => _transferLibrary(repo),
                              child: Text('${l10n.zh ? '转让' : 'Transfer'} ${repo['name'] ?? repo['repo_name'] ?? ''}', style: const TextStyle(fontSize: 11.5)),
                            ),
                          OutlinedButton(
                            onPressed: () => _libraryTab == 3 ? _deleteTrashLibrary(repo) : _deleteLibrary(repo),
                            child: Text('${l10n.delete} ${repo['name'] ?? repo['repo_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLibrary() async {
    final l10n = L10n.of(context);
    final name = TextEditingController();
    final owner = TextEditingController(text: context.read<AppSession>().username);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '新建资料库' : 'New library'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: l10n.name)),
              const SizedBox(height: 12),
              TextField(controller: owner, decoration: InputDecoration(labelText: l10n.zh ? '所有者邮箱' : 'Owner email')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.create)),
        ],
      ),
    );
    final libraryName = name.text.trim();
    final ownerEmail = owner.text.trim();
    name.dispose();
    owner.dispose();
    if (result != true || libraryName.isEmpty) return;
    try {
      await context.read<AppSession>().api!.createAdminLibrary(libraryName, ownerEmail);
      await _loadLibraries();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteTrashLibrary(Map<String, dynamic> repo) async {
    final l10n = L10n.of(context);
    final id = '${repo['id'] ?? ''}';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '永久删除资料库' : 'Delete library permanently'),
        content: Text(l10n.zh ? '确定永久删除 ${repo['name']}？' : 'Permanently delete ${repo['name']}?'),
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
      await context.read<AppSession>().api!.deleteAdminTrashLibrary(id);
      await _loadTrashLibraries();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _transferLibrary(Map<String, dynamic> repo) async {
    final l10n = L10n.of(context);
    final id = '${repo['id'] ?? ''}';
    if (id.isEmpty) return;
    final owner = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '转让资料库' : 'Transfer library'),
        content: SizedBox(
          width: 380,
          child: TextField(controller: owner, autofocus: true, decoration: InputDecoration(labelText: l10n.zh ? '新所有者邮箱' : 'New owner email')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.zh ? '转让' : 'Transfer')),
        ],
      ),
    );
    final email = owner.text.trim();
    owner.dispose();
    if (result != true || email.isEmpty) return;
    try {
      await context.read<AppSession>().api!.transferAdminLibrary(id, email);
      await _loadLibraries();
      if (mounted) showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteLibrary(Map<String, dynamic> repo) async {
    final l10n = L10n.of(context);
    final id = '${repo['id'] ?? ''}';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除资料库' : 'Delete library'),
        content: Text(l10n.zh ? '确定删除 ${repo['name']}？此操作不可撤销。' : 'Delete ${repo['name']}? This cannot be undone.'),
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
      await context.read<AppSession>().api!.deleteAdminLibrary(id);
      await _loadLibraries();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _userTable(L10n l10n) {
    final headers = [l10n.zh ? '用户' : 'User', l10n.zh ? '状态' : 'Status', l10n.zh ? '用量' : 'Usage', l10n.zh ? '最后登录' : 'Last login', l10n.zh ? '操作' : 'Actions'];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 40,
            color: AppColors.tableHeader,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  Expanded(flex: i == 0 ? 3 : 2, child: Text(headers[i], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          ),
          for (var index = 0; index < _visibleUsers.length; index++)
            _userRow(_visibleUsers[index], index == _visibleUsers.length - 1, l10n),
        ],
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> user, bool last, L10n l10n) {
    final email = '${user['email'] ?? ''}';
    final active = user['is_active'] == 1;
    final self = email == context.read<AppSession>().username;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${user['name'] ?? ''}'.isEmpty ? email : '${user['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(active ? (l10n.zh ? '启用' : 'Active') : (l10n.zh ? '禁用' : 'Disabled'), style: TextStyle(fontSize: 12.5, color: active ? AppColors.success : AppColors.muted))),
          Expanded(flex: 2, child: Text(formatBytes((user['quota_usage'] as num?)?.toInt() ?? 0), style: const TextStyle(fontSize: 12.5))),
          Expanded(flex: 2, child: Text('${user['last_login'] ?? '—'}'.replaceFirst('T', ' ').split('+').first, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                tooltip: '',
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.zh ? '编辑用户' : 'Edit user', style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  PopupMenuItem(value: 'role', child: Text(user['is_staff'] == true ? (l10n.zh ? '取消管理员' : 'Remove admin') : (l10n.zh ? '设为管理员' : 'Make admin'), style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  PopupMenuItem(value: 'toggle', child: Text(active ? (l10n.zh ? '禁用账号' : 'Disable account') : (l10n.zh ? '启用账号' : 'Enable account'), style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  PopupMenuItem(value: 'password', child: Text(l10n.zh ? '重置密码' : 'Reset password', style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  if (!self) PopupMenuItem(value: 'delete', child: Text(l10n.zh ? '删除用户' : 'Delete user', style: const TextStyle(fontSize: 13, color: AppColors.danger))),
                ],
                onSelected: (value) {
                  if (value == 'edit') _editUser(user);
                  if (value == 'role') _toggleAdmin(user, user['is_staff'] != true);
                  if (value == 'toggle') _toggleUser(user, !active);
                  if (value == 'password') _resetUserPassword(user);
                  if (value == 'delete') _deleteUser(user);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: WebIcon('more-vertical', size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user, bool staff) async {
    final l10n = L10n.of(context);
    try {
      await context.read<AppSession>().api!.updateAdminUser('${user['email']}', {'is_staff': staff});
      await _loadUsers();
      if (mounted) showToast(context, staff ? (l10n.zh ? '已设为管理员' : 'Admin role granted') : (l10n.zh ? '已取消管理员' : 'Admin role removed'));
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final l10n = L10n.of(context);
    final name = TextEditingController(text: '${user['name'] ?? ''}');
    final quota = TextEditingController(text: ((user['quota_total'] as num?)?.toInt() ?? -2) > 0 ? '${((user['quota_total'] as num).toInt() / 1024 / 1024).round()}' : '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '编辑用户' : 'Edit user'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: l10n.zh ? '昵称' : 'Display name')),
              const SizedBox(height: 12),
              TextField(
                controller: quota,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.zh ? '空间配额 (MB，留空不限制)' : 'Quota (MB, empty for unlimited)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.save)),
        ],
      ),
    );
    final displayName = name.text.trim();
    final quotaText = quota.text.trim();
    name.dispose();
    quota.dispose();
    if (result != true) return;
    try {
      await context.read<AppSession>().api!.updateAdminUser('${user['email']}', {
        'name': displayName,
        'quota_total': quotaText.isEmpty ? -2 : (int.tryParse(quotaText) ?? 0) * 1024 * 1024,
      });
      await _loadUsers();
      if (mounted) showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _toggleUser(Map<String, dynamic> user, bool active) async {
    final l10n = L10n.of(context);
    try {
      await context.read<AppSession>().api!.updateAdminUser('${user['email']}', {'is_active': active});
      await _loadUsers();
      if (mounted) showToast(context, active ? (l10n.zh ? '账号已启用' : 'Account enabled') : (l10n.zh ? '账号已禁用' : 'Account disabled'));
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _resetUserPassword(Map<String, dynamic> user) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '重置密码' : 'Reset password'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.zh ? '新密码' : 'New password'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    try {
      await context.read<AppSession>().api!.resetAdminUserPassword('${user['email']}', password);
      if (mounted) showToast(context, l10n.zh ? '密码已重置' : 'Password reset');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除用户' : 'Delete user'),
        content: Text(l10n.zh ? '确定删除 ${user['email']}？此操作不可撤销。' : 'Delete ${user['email']}? This cannot be undone.'),
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
      await context.read<AppSession>().api!.deleteAdminUser('${user['email']}');
      await _loadUsers();
      if (mounted) showToast(context, l10n.zh ? '用户已删除' : 'User deleted');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _createUser() async {
    final l10n = L10n.of(context);
    final email = TextEditingController();
    final name = TextEditingController();
    final password = TextEditingController();
    var active = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.zh ? '新建用户' : 'New user'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: InputDecoration(labelText: l10n.zh ? '昵称' : 'Display name')),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: l10n.zh ? '初始密码' : 'Initial password')),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value == true),
                  title: Text(l10n.zh ? '启用账号' : 'Active account', style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.create)),
          ],
        ),
      ),
    );
    final values = {
      'email': email.text.trim(),
      'name': name.text.trim(),
      'password': password.text,
      'is_active': active,
      'role': 'default',
    };
    email.dispose();
    name.dispose();
    password.dispose();
    if (result != true || values['email'] == '') return;
    try {
      await context.read<AppSession>().api!.createAdminUser(values);
      await _loadUsers();
      if (mounted) showToast(context, l10n.zh ? '用户已创建' : 'User created');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _table({required List<String> headers, required List<List<String>> rows}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 40,
            color: AppColors.tableHeader,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final header in headers)
                  Expanded(flex: header == headers.first ? 3 : 2, child: Text(header, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          ),
          if (rows.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Text(
                L10n.of(context).zh ? '暂无数据' : 'No data',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
          for (var index = 0; index < rows.length; index++)
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: index == rows.length - 1 ? Colors.transparent : AppColors.border))),
              child: Row(
                children: [
                  for (var cell = 0; cell < headers.length; cell++)
                    Expanded(
                      flex: cell == 0 ? 3 : 2,
                      child: Text(
                        cell < rows[index].length ? rows[index][cell] : '',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.text, height: 1.45),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
