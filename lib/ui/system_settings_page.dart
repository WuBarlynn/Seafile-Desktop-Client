import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
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
  Map<String, dynamic> _webSettings = const {};
  final _userQuery = TextEditingController();
  bool _loadingUsers = false;
  bool _loadingLibraries = false;
  bool _loadingSettings = false;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _userQuery.dispose();
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
      final data = await context.read<AppSession>().api!.adminLibraries();
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

  Future<void> _loadWebSettings() async {
    setState(() => _loadingSettings = true);
    try {
      final data = await context.read<AppSession>().api!.adminWebSettings();
      if (!mounted) return;
      setState(() {
        _webSettings = data;
        _loadingSettings = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSettings = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _saveWebSettings() async {
    final l10n = L10n.of(context);
    setState(() => _savingSettings = true);
    try {
      await context.read<AppSession>().api!.updateAdminWebSettings(_webSettings);
      if (mounted) {
        setState(() => _savingSettings = false);
        showToast(context, l10n.savedSuccessfully);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savingSettings = false);
        showToast(context, friendlyError(context, error), error: true);
      }
    }
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    if (tab == 1 && _users.isEmpty) _loadUsers();
    if (tab == 2 && _libraries.isEmpty) _loadLibraries();
    if (tab == 3 && _webSettings.isEmpty) _loadWebSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('admin-logs', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 9),
              Text(l10n.systemSettings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => widget.onOpenWeb?.call('/sysadmin/', l10n.systemSettings),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(l10n.zh ? '完整管理后台' : 'Full admin console', style: const TextStyle(fontSize: 12)),
              ),
              IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: () {
                _loadOverview();
                if (_tab == 1) _loadUsers();
                if (_tab == 2) _loadLibraries();
                if (_tab == 3) _loadWebSettings();
              }),
            ],
          ),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              _tabButton(0, l10n.zh ? '概览' : 'Overview', Icons.dashboard_outlined),
              _tabButton(1, l10n.zh ? '用户' : 'Users', Icons.people_outline),
              _tabButton(2, l10n.zh ? '资料库' : 'Libraries', Icons.folder_outlined),
              _tabButton(3, l10n.zh ? '系统设置' : 'Settings', Icons.tune),
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
                        1 => _usersView(l10n),
                        2 => _librariesView(l10n),
                        _ => _settingsView(l10n),
                      },
          ),
        ),
      ],
    );
  }

  Widget _tabButton(int value, String label, IconData icon) {
    final active = _tab == value;
    return InkWell(
      onTap: () => _selectTab(value),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2))),
        child: Row(
          children: [
            Icon(icon, size: 15, color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: active ? AppColors.primary : AppColors.textSecondary, fontWeight: active ? FontWeight.w500 : FontWeight.w400)),
          ],
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
                    Text(l10n.zh ? '许可信息' : 'License', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _usersView(L10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 320,
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
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: _loadUsers, child: Text(l10n.search)),
                  const Spacer(),
                  if (_loadingUsers) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _createUser,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: Text(l10n.zh ? '新建用户' : 'New user'),
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

  Widget _librariesView(L10n l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Row(
                children: [
                  Text(l10n.zh ? '所有资料库' : 'All libraries', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (_loadingLibraries) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 14),
              _table(
                headers: [l10n.name, l10n.zh ? '所有者' : 'Owner', l10n.fileSize, l10n.zh ? '文件数' : 'Files', l10n.modified],
                rows: [
                  for (final repo in _libraries)
                    [
                      '${repo['name'] ?? ''}',
                      '${repo['owner_name'] ?? repo['owner_email'] ?? ''}',
                      '${repo['size_formatted'] ?? formatBytes((repo['size'] as num?)?.toInt() ?? 0)}',
                      '${repo['file_count'] ?? 0}',
                      '${repo['last_modified'] ?? '—'}'.replaceFirst('T', ' ').split('+').first,
                    ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          for (var index = 0; index < _users.length; index++)
            _userRow(_users[index], index == _users.length - 1, l10n),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'toggle', child: Text(active ? (l10n.zh ? '禁用账号' : 'Disable account') : (l10n.zh ? '启用账号' : 'Enable account'), style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  PopupMenuItem(value: 'password', child: Text(l10n.zh ? '重置密码' : 'Reset password', style: const TextStyle(fontSize: 13, color: AppColors.text))),
                  if (!self) PopupMenuItem(value: 'delete', child: Text(l10n.zh ? '删除用户' : 'Delete user', style: const TextStyle(fontSize: 13, color: AppColors.danger))),
                ],
                onSelected: (value) {
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

  Widget _settingsView(L10n l10n) {
    if (_loadingSettings) return const Center(child: CircularProgressIndicator());
    const keys = [
      'ENABLE_SIGNUP',
      'ENABLE_ENCRYPTED_LIBRARY',
      'ENABLE_REPO_HISTORY_SETTING',
      'USER_STRONG_PASSWORD_REQUIRED',
      'ENABLE_TWO_FACTOR_AUTH',
      'ENABLE_SHARE_TO_ALL_GROUPS',
      'ENABLE_USER_CLEAN_TRASH',
      'SHARE_LINK_FORCE_USE_PASSWORD',
    ];
    const labels = {
      'ENABLE_SIGNUP': ('允许注册', 'Allow sign-up'),
      'ENABLE_ENCRYPTED_LIBRARY': ('启用加密资料库', 'Encrypted libraries'),
      'ENABLE_REPO_HISTORY_SETTING': ('允许设置资料库历史', 'Library history setting'),
      'USER_STRONG_PASSWORD_REQUIRED': ('强制强密码', 'Strong password required'),
      'ENABLE_TWO_FACTOR_AUTH': ('两步验证', 'Two-factor authentication'),
      'ENABLE_SHARE_TO_ALL_GROUPS': ('共享给所有群组', 'Share to all groups'),
      'ENABLE_USER_CLEAN_TRASH': ('用户可清空回收站', 'Users can clean trash'),
      'SHARE_LINK_FORCE_USE_PASSWORD': ('分享链接强制密码', 'Share links require password'),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.zh ? '系统设置' : 'System settings', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(l10n.zh ? '更改后立即对服务器上的所有用户生效。' : 'Changes apply to all users on the server.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                for (final key in keys)
                  if (_webSettings[key] is bool)
                    Container(
                      height: 46,
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.zh ? labels[key]!.$1 : labels[key]!.$2, style: const TextStyle(fontSize: 13))),
                          CompactSwitch(
                            value: _webSettings[key] == true,
                            onChanged: (value) => setState(() => _webSettings[key] = value),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: _loadWebSettings, child: Text(l10n.zh ? '重置' : 'Reset')),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _savingSettings ? null : _saveWebSettings,
                      icon: _savingSettings
                          ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(l10n.save),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.zh ? '其余高级设置（如邮件、存储、LDAP）仍保留在服务器配置中。' : 'Other advanced settings (email, storage, LDAP) remain in the server configuration.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
