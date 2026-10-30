import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, this.onOpenSystemSettings});

  final VoidCallback? onOpenSystemSettings;

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
  bool _uploadingAvatar = false;
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
      final profile = await api.userProfile();
      if (!mounted) return;
      final loadedName = (profile['name'] as String?) ?? '';
      final session = context.read<AppSession>();
      _name.text = loadedName.isNotEmpty ? loadedName : session.displayName;
      _contactEmail.text = (profile['contact_email'] as String?) ?? '';
      _telephone.text = (profile['telephone'] as String?) ?? '';
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
