import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'widgets.dart';

class LibrarySettingsView extends StatefulWidget {
  const LibrarySettingsView({super.key});

  @override
  State<LibrarySettingsView> createState() => _LibrarySettingsViewState();
}

class _LibrarySettingsViewState extends State<LibrarySettingsView> {
  int _tab = 0;
  final _daysController = TextEditingController();
  bool _savingHistory = false;
  bool _busyMetadata = false;
  bool _busyAi = false;
  bool _busyTags = false;

  @override
  void initState() {
    super.initState();
    final workspace = context.read<WorkspaceController>();
    if (workspace.historyLimit != null) _daysController.text = '${workspace.historyLimit}';
    workspace.addListener(_onWorkspaceChanged);
  }

  void _onWorkspaceChanged() {
    if (!mounted) return;
    final workspace = context.read<WorkspaceController>();
    if (workspace.historyLimit != null && workspace.historyLimit! > 0 && _daysController.text.isEmpty) {
      _daysController.text = '${workspace.historyLimit}';
    }
  }

  @override
  void dispose() {
    context.read<WorkspaceController>().removeListener(_onWorkspaceChanged);
    _daysController.dispose();
    super.dispose();
  }

  bool get _metadataTabVisible {
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.repo;
    return repo != null && repo.isOwner && !repo.encrypted;
  }

  Future<void> _saveHistory(int value) async {
    if (_savingHistory) return;
    final l10n = L10n.of(context);
    setState(() => _savingHistory = true);
    try {
      await context.read<WorkspaceController>().setHistoryLimit(value);
      if (mounted) showToast(context, l10n.savedPreferences);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _savingHistory = false);
    }
  }

  Future<void> _toggleMetadata(bool value) async {
    final l10n = L10n.of(context);
    setState(() => _busyMetadata = true);
    try {
      await context.read<WorkspaceController>().setMetadataEnabled(value);
      if (mounted) showToast(context, l10n.savedPreferences);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busyMetadata = false);
    }
  }

  Future<void> _toggleAi(bool value) async {
    final l10n = L10n.of(context);
    setState(() => _busyAi = true);
    try {
      await context.read<WorkspaceController>().setSummaryEnabled(value);
      if (mounted) showToast(context, l10n.savedPreferences);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busyAi = false);
    }
  }

  Future<void> _toggleTags(bool value) async {
    final l10n = L10n.of(context);
    setState(() => _busyTags = true);
    try {
      await context.read<WorkspaceController>().setTagsEnabled(value);
      if (mounted) showToast(context, l10n.savedPreferences);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busyTags = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final status = workspace.metaStatus;
    final hasMetadataTab = _metadataTabVisible;
    final tab = hasMetadataTab ? _tab : 0;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                _tabButton(l10n.generalTab, 0, tab),
                if (hasMetadataTab) ...[
                  const SizedBox(width: 26),
                  _tabButton(workspace.isV14 ? l10n.metadataAiTab : l10n.metadataTab, 1, tab),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 26, 32, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: tab == 0 ? _buildGeneral(l10n, workspace) : _buildMetadata(l10n, workspace, status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, int active) {
    final selected = index == active;
    return HoverBuilder(
      builder: (context, hovered) => InkWell(
        onTap: () => setState(() => _tab = index),
        hoverColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          height: 40,
          alignment: Alignment.center,
          color: hovered ? AppColors.hover : Colors.transparent,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2)),
          ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? AppColors.primary : AppColors.text,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneral(L10n l10n, WorkspaceController workspace) {
    if (workspace.historyLimit == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final value = workspace.historyLimit!;
    final isCustom = value > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.historySetting, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _radioRow(-1, l10n.keepAllHistory, value),
        _radioRow(0, l10n.keepNoHistory, value),
        Row(
          children: [
            Radio<int>(
              value: 1,
              groupValue: isCustom ? 1 : value,
              onChanged: _savingHistory ? null : (_) => _saveHistory(int.tryParse(_daysController.text) ?? 30),
            ),
            Text(l10n.keepDaysHistory, style: const TextStyle(fontSize: 14)),
            SizedBox(
              width: 86,
              child: TextField(
                controller: _daysController,
                enabled: isCustom && !_savingHistory,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
                onSubmitted: (text) {
                  final days = int.tryParse(text);
                  if (days != null && days > 0) _saveHistory(days);
                },
              ),
            ),
            const SizedBox(width: 6),
            Text(l10n.days, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (isCustom) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: _savingHistory
                    ? null
                    : () {
                        final days = int.tryParse(_daysController.text);
                        if (days != null && days > 0) _saveHistory(days);
                      },
                child: Text(l10n.save),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _radioRow(int value, String label, int current) {
    return InkWell(
      onTap: _savingHistory ? null : () => _saveHistory(value),
      child: Row(
        children: [
          Radio<int>(
            value: value,
            groupValue: current > 0 ? -2 : current,
            onChanged: _savingHistory ? null : (_) => _saveHistory(value),
          ),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMetadata(L10n l10n, WorkspaceController workspace, MetadataStatus? status) {
    final enabled = status?.enabled ?? false;
    final tagsEnabled = status?.tagsEnabled ?? false;
    final summaryEnabled = status?.summaryEnabled ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingSection(
          title: l10n.enableMetadata,
          description: l10n.metadataEnabledHint,
          value: enabled,
          onChanged: _busyMetadata ? null : _toggleMetadata,
        ),
        if (enabled) ...[
          const SizedBox(height: 10),
          Text(l10n.globalHiddenProperties, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(l10n.globalHiddenHint, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showHiddenColumns(l10n, workspace, status),
            icon: const WebIcon('eye-slash', size: 14),
            label: Text(l10n.hideProperties),
          ),
          if (workspace.isV14) ...[
          const SizedBox(height: 26),
          _settingSection(
            title: l10n.enableAiSummary,
            description: l10n.aiEnabledHint,
            value: summaryEnabled,
            onChanged: _busyAi ? null : _toggleAi,
            extra: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => _showAiStatus(l10n, workspace),
                child: Text(l10n.viewStatus),
              ),
            ),
          ),
          ],
          const SizedBox(height: 26),
          _settingSection(
            title: l10n.enableTags,
            description: l10n.tagsEnabledHint,
            value: tagsEnabled,
            onChanged: _busyTags ? null : _toggleTags,
          ),
        ],
      ],
    );
  }

  Widget _settingSection({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? extra,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            CompactSwitch(value: value, onChanged: onChanged),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
        if (extra != null) ...[
          const SizedBox(height: 10),
          extra,
        ],
      ],
    );
  }

  Future<void> _showHiddenColumns(L10n l10n, WorkspaceController workspace, MetadataStatus? status) async {
    final repo = workspace.repo;
    if (repo == null) return;
    const columns = <String, String>{
      '_file_type': '文件类型',
      '_status': '状态',
      '_description': '描述',
      '_expire_time': '过期时间',
      '_tags': '标签',
      '_file_creator': '创建者',
      '_file_mtime': '修改时间',
      '_size': '大小',
    };
    final hidden = {...(status?.hiddenColumns ?? const <String>[])};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.globalHiddenProperties),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in columns.entries)
                  CheckboxListTile(
                    value: hidden.contains(item.key),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item.value, style: const TextStyle(fontSize: 13)),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          hidden.add(item.key);
                        } else {
                          hidden.remove(item.key);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, hidden.toList()), child: Text(l10n.save)),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await context.read<AppSession>().api!.setGlobalHiddenColumns(repo.id, result);
      await workspace.loadMetadata();
      if (mounted) showToast(context, l10n.savedPreferences);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _showAiStatus(L10n l10n, WorkspaceController workspace) async {
    final status = workspace.metaStatus;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.enableAiSummary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow(l10n.enableMetadata, status?.enabled == true),
            _statusRow(l10n.enableTags, status?.tagsEnabled == true),
            _statusRow(l10n.enableAiSummary, status?.summaryEnabled == true),
            _statusRow('AI', workspace.aiAvailable),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
      ),
    );
  }

  Widget _statusRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13))),
          WebIcon(value ? 'check-circle-filled' : 'exclamation-circle', size: 15, color: value ? AppColors.success : AppColors.muted),
        ],
      ),
    );
  }
}
