import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/json_utils.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, this.onOpenSystemSettings, this.onOpenWeb});

  final VoidCallback? onOpenSystemSettings;
  final void Function(String path, String title)? onOpenWeb;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _name = TextEditingController();
  final _contactEmail = TextEditingController();
  final _telephone = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _savingNotifications = false;
  bool _uploadingAvatar = false;
  int _fileInterval = 0;
  int _collabInterval = 0;
  String? _webdavSecret;
  List<Map<String, dynamic>> _devices = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _contactEmail.dispose();
    _telephone.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppSession>().api!;
      final core = await Future.wait([api.userProfile(), api.accountInfoRaw()]);
      String? webdavSecret;
      List<Map<String, dynamic>> devices = const [];
      try {
        webdavSecret = await api.webdavSecret();
      } catch (_) {}
      try {
        devices = await api.linkedDevices();
      } catch (_) {}
      if (!mounted) return;
      final profile = asMap(core[0]);
      final info = asMap(core[1]);
      final loadedName = (profile['name'] as String?) ?? '';
      final session = context.read<AppSession>();
      _name.text = loadedName.isNotEmpty ? loadedName : session.displayName;
      _contactEmail.text = (profile['contact_email'] as String?) ?? '';
      _telephone.text = (profile['telephone'] as String?) ?? '';
      _fileInterval = (info['file_updates_email_interval'] as num?)?.toInt() ?? 0;
      _collabInterval = (info['collaborate_email_interval'] as num?)?.toInt() ?? 0;
      _webdavSecret = webdavSecret;
      _devices = devices;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _saveProfile() async {
    final l10n = L10n.of(context);
    setState(() => _savingProfile = true);
    try {
      await context.read<AppSession>().api!.updateUserProfile({
        'name': _name.text.trim(),
        'contact_email': _contactEmail.text.trim(),
        'telephone': _telephone.text.trim(),
      });
      await context.read<AppSession>().refreshAccountInfo();
      if (mounted) {
        setState(() => _savingProfile = false);
        showToast(context, l10n.savedSuccessfully);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savingProfile = false);
        showToast(context, friendlyError(context, error), error: true);
      }
    }
  }

  Future<void> _changePassword() async {
    final l10n = L10n.of(context);
    if (_newPassword.text.length < 8) {
      showToast(context, l10n.zh ? '密码至少需要 8 个字符' : 'Password must be at least 8 characters', error: true);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      showToast(context, l10n.zh ? '两次输入的新密码不一致' : 'The new passwords do not match', error: true);
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await context.read<AppSession>().api!.resetPassword(oldPassword: _oldPassword.text, newPassword: _newPassword.text);
      _oldPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        setState(() => _savingPassword = false);
        showToast(context, l10n.zh ? '密码已更新' : 'Password updated');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _savingPassword = false);
        showToast(context, friendlyError(context, error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('settings', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 9),
              Text(l10n.accountSettings, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => widget.onOpenWeb?.call('/profile/', l10n.accountSettings),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(l10n.zh ? '更多账户选项' : 'More account options', style: const TextStyle(fontSize: 12)),
              ),
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
                            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _profileCard(session, l10n),
                                const SizedBox(height: 18),
                                _profileForm(l10n),
                                const SizedBox(height: 18),
                                _passwordCard(l10n),
                                const SizedBox(height: 18),
                                _webdavCard(session, l10n),
                                const SizedBox(height: 18),
                                _notificationCard(l10n),
                                const SizedBox(height: 18),
                                _devicesCard(l10n),
                                if (session.accountInfo?.isStaff == true) ...[
                                  const SizedBox(height: 18),
                                  _adminCard(l10n),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeAvatar() async {
    final l10n = L10n.of(context);
    final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'image', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'])]);
    if (file == null || !mounted) return;
    final session = context.read<AppSession>();
    final oldUrl = session.avatarUrl;
    setState(() => _uploadingAvatar = true);
    try {
      await session.api!.uploadAvatar(file.path);
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await NetworkImage(oldUrl).evict();
      }
      await session.refreshAccountInfo();
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        showToast(context, l10n.zh ? '头像已更新' : 'Avatar updated');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        showToast(context, friendlyError(context, error), error: true);
      }
    }
  }

  Widget _card({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _profileCard(AppSession session, L10n l10n) {
    final total = session.quotaTotal;
    final usage = session.quotaUsage ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AvatarCircle(
            name: session.displayName,
            size: 56,
            image: (session.avatarUrl?.isNotEmpty == true) ? NetworkImage(session.avatarUrl!) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(session.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _uploadingAvatar ? null : _changeAvatar,
                      icon: _uploadingAvatar
                          ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera_outlined, size: 15),
                      label: Text(l10n.zh ? '更换头像' : 'Change avatar', style: const TextStyle(fontSize: 11.5)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 26)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(session.emailLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Text(
                  total != null && total > 0
                      ? l10n.quotaUsage(formatBytes(usage), formatBytes(total))
                      : (l10n.zh ? '存储空间：不限' : 'Storage: unlimited'),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileForm(L10n l10n) {
    return _card(
      title: l10n.zh ? '个人资料' : 'Profile',
      subtitle: l10n.zh ? '这些信息会显示在共享、评论和活动记录中。' : 'This information appears in shares, comments and activity.',
      children: [
        Row(
          children: [
            Expanded(child: _field(_name, l10n.zh ? '昵称' : 'Display name')),
            const SizedBox(width: 14),
            Expanded(child: _field(_contactEmail, l10n.zh ? '联系邮箱' : 'Contact email')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _field(_telephone, l10n.zh ? '电话' : 'Telephone')),
            const SizedBox(width: 14),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _savingProfile ? null : _saveProfile,
            icon: _savingProfile
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(l10n.save, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _passwordCard(L10n l10n) {
    return _card(
      title: l10n.zh ? '修改密码' : 'Change password',
      subtitle: l10n.zh ? '修改后其他会话可能需要重新登录。' : 'Other sessions may need to sign in again after the change.',
      children: [
        Row(
          children: [
            Expanded(child: _field(_oldPassword, l10n.zh ? '当前密码' : 'Current password', obscure: true)),
            const SizedBox(width: 14),
            Expanded(child: _field(_newPassword, l10n.zh ? '新密码' : 'New password', obscure: true)),
            const SizedBox(width: 14),
            Expanded(child: _field(_confirmPassword, l10n.zh ? '确认新密码' : 'Confirm new password', obscure: true)),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _savingPassword ? null : _changePassword,
            icon: _savingPassword
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_outline, size: 16),
            label: Text(l10n.zh ? '更新密码' : 'Update password', style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _webdavCard(AppSession session, L10n l10n) {
    return _card(
      title: l10n.zh ? 'WebDAV 访问' : 'WebDAV access',
      subtitle: l10n.zh ? '使用 WebDAV 客户端访问资料库。' : 'Access your libraries with a WebDAV client.',
      children: [
        _infoLine('WebDAV URL', '${session.serverBase}/seafdav/'),
        const SizedBox(height: 8),
        _infoLine(l10n.zh ? 'WebDAV 用户' : 'WebDAV user', session.emailLabel),
        const SizedBox(height: 8),
        _infoLine(l10n.zh ? 'WebDAV 密码' : 'WebDAV password', (_webdavSecret?.isNotEmpty ?? false) ? (l10n.zh ? '已设置' : 'Set') : (l10n.zh ? '未设置' : 'Not set')),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _setWebdavSecret,
            icon: const Icon(Icons.key_outlined, size: 16),
            label: Text((_webdavSecret?.isNotEmpty ?? false) ? (l10n.zh ? '更新密码' : 'Update password') : (l10n.zh ? '设置密码' : 'Set password'), style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _infoLine(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Future<void> _setWebdavSecret() async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '设置 WebDAV 密码' : 'Set WebDAV password'),
        content: SizedBox(
          width: 360,
          child: TextField(controller: controller, autofocus: true, obscureText: true, decoration: InputDecoration(labelText: l10n.zh ? '新密码' : 'New password')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (secret == null || secret.isEmpty) return;
    try {
      await context.read<AppSession>().api!.updateWebdavSecret(secret);
      if (!mounted) return;
      setState(() => _webdavSecret = secret);
      showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _notificationCard(L10n l10n) {
    return _card(
      title: l10n.zh ? '邮件通知' : 'Email notifications',
      subtitle: l10n.zh ? '选择文件改动和协作通知的发送频率。' : 'Choose how often file-change and collaboration emails are sent.',
      children: [
        Text(l10n.zh ? '文件改动通知' : 'File update notifications', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              (0, l10n.zh ? '不发送' : 'Never'),
              (3600, l10n.zh ? '每小时' : 'Hourly'),
              (14400, l10n.zh ? '每4小时' : 'Every 4 hours'),
              (86400, l10n.zh ? '每天' : 'Daily'),
              (604800, l10n.zh ? '每周' : 'Weekly'),
            ])
              ChoiceChip(
                label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                selected: _fileInterval == entry.$1,
                onSelected: _savingNotifications ? null : (_) => _saveNotificationIntervals(file: entry.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(l10n.zh ? '协作通知' : 'Collaboration notifications', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in [(0, l10n.zh ? '不发送' : 'Never'), (3600, l10n.zh ? '每小时' : 'Hourly')])
              ChoiceChip(
                label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                selected: _collabInterval == entry.$1,
                onSelected: _savingNotifications ? null : (_) => _saveNotificationIntervals(collab: entry.$1),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveNotificationIntervals({int? file, int? collab}) async {
    final l10n = L10n.of(context);
    final previousFile = _fileInterval;
    final previousCollab = _collabInterval;
    setState(() {
      _fileInterval = file ?? _fileInterval;
      _collabInterval = collab ?? _collabInterval;
      _savingNotifications = true;
    });
    try {
      await context.read<AppSession>().api!.updateEmailNotificationIntervals(fileUpdates: _fileInterval, collaboration: _collabInterval);
      if (!mounted) return;
      setState(() => _savingNotifications = false);
      showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fileInterval = previousFile;
        _collabInterval = previousCollab;
        _savingNotifications = false;
      });
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _devicesCard(L10n l10n) {
    return _card(
      title: l10n.zh ? '已连接的设备' : 'Linked devices',
      subtitle: _devices.isEmpty ? (l10n.zh ? '当前没有连接任何客户端。' : 'No clients are connected.') : null,
      children: [
        for (final device in _devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.devices_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${device['device_name'] ?? device['name'] ?? device['platform'] ?? ''}', style: const TextStyle(fontSize: 13)),
                      Text(
                        '${device['platform'] ?? ''} · ${device['last_accessed'] ?? device['last_access'] ?? ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _unlinkDevice(device),
                  child: Text(l10n.zh ? '断开' : 'Unlink', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _unlinkDevice(Map<String, dynamic> device) async {
    final l10n = L10n.of(context);
    final platform = '${device['platform'] ?? ''}';
    final id = '${device['device_id'] ?? device['id'] ?? ''}';
    if (platform.isEmpty || id.isEmpty) return;
    try {
      await context.read<AppSession>().api!.unlinkDevice(platform, id);
      if (!mounted) return;
      setState(() => _devices = _devices.where((item) => '${item['device_id'] ?? item['id'] ?? ''}' != id).toList());
      showToast(context, l10n.zh ? '设备已断开' : 'Device unlinked');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Widget _adminCard(L10n l10n) {
    return _card(
      title: l10n.zh ? '管理员' : 'Administrator',
      subtitle: l10n.zh ? '当前账号拥有系统管理员权限。' : 'This account has system administrator rights.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.onOpenSystemSettings,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 17),
            label: Text(l10n.systemSettings),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(labelText: label),
    );
  }
}
