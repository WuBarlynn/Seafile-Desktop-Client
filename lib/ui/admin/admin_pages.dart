import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/json_utils.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/session.dart';
import '../widgets.dart';

class AdminPanelHeader extends StatelessWidget {
  const AdminPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.tabs = const [],
    this.activeTab = 0,
    this.onTab,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<String> tabs;
  final int activeTab;
  final ValueChanged<int>? onTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
              const Spacer(),
              ...actions,
            ],
          ),
        ),
        if (tabs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => onTab?.call(index),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: index == activeTab ? AppColors.primarySoft : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: index == activeTab ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border),
                        ),
                        child: Text(
                          tabs[index],
                          style: TextStyle(
                            fontSize: 12.5,
                            color: index == activeTab ? AppColors.primaryDark : AppColors.textSecondary,
                            fontWeight: index == activeTab ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidth = 170,
    this.firstColumnWidth = 230,
    this.emptyLabel = 'No data',
  });

  final List<String> headers;
  final List<List<String>> rows;
  final double columnWidth;
  final double firstColumnWidth;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Text(emptyLabel, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                color: AppColors.tableHeader,
                child: Row(
                  children: [
                    for (var index = 0; index < headers.length; index++)
                      Container(
                        width: index == 0 ? firstColumnWidth : columnWidth,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Text(headers[index], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              for (var row = 0; row < rows.length; row++)
                Container(
                  height: 44,
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    children: [
                      for (var index = 0; index < headers.length; index++)
                        Container(
                          width: index == 0 ? firstColumnWidth : columnWidth,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index < rows[row].length ? rows[row][index] : '',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget adminError(BuildContext context, String message, VoidCallback retry) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: Text(L10n.of(context).retry)),
      ],
    ),
  );
}

Widget adminLoading() => const Center(child: CircularProgressIndicator());

String adminDateLabel(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  final h = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$minute';
}

bool adminTruthy(dynamic value) => value == true || value == 1 || value == '1' || value == 'true';

String adminMapText(Map<String, dynamic> data, List<String> keys) {  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is bool) return value ? 'Yes' : 'No';
    final text = value.toString();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

class AdminStatisticsPanel extends StatefulWidget {
  const AdminStatisticsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminStatisticsPanel> createState() => _AdminStatisticsPanelState();
}

class _AdminStatisticsPanelState extends State<AdminStatisticsPanel> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now());
  List<Map<String, dynamic>> _fileOps = const [];
  List<Map<String, dynamic>> _storage = const [];
  List<Map<String, dynamic>> _activeUsers = const [];
  List<Map<String, dynamic>> _traffic = const [];
  List<Map<String, dynamic>> _ai = const [];
  List<Map<String, dynamic>> _metrics = const [];
  final _month = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
  bool _downloadingReport = false;

  @override
  void dispose() {
    _month.dispose();
    super.dispose();
  }

  String get _start => '${_range.start.year.toString().padLeft(4, '0')}-${_range.start.month.toString().padLeft(2, '0')}-${_range.start.day.toString().padLeft(2, '0')} 00:00:00';
  String get _end => '${_range.end.year.toString().padLeft(4, '0')}-${_range.end.month.toString().padLeft(2, '0')}-${_range.end.day.toString().padLeft(2, '0')} 00:00:00';
  String get _today => '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminStatisticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AppSession>().api!;
    try {
      final results = await Future.wait([
        api.adminStatisticsFileOperations(start: _start, end: _end),
        api.adminStatisticsStorage(start: _start, end: _end),
        api.adminStatisticsActiveUsers(start: _start, end: _end),
        api.adminStatisticsTraffic(start: _start, end: _end),
        api.adminStatisticsAi(date: _today),
        api.adminStatisticsMetrics(),
      ]);
      if (!mounted) return;
      setState(() {
        _fileOps = results[0] as List<Map<String, dynamic>>;
        _storage = results[1] as List<Map<String, dynamic>>;
        _activeUsers = results[2] as List<Map<String, dynamic>>;
        _traffic = results[3] as List<Map<String, dynamic>>;
        _ai = asMap(results[4])['results'] is List
            ? (asMap(results[4])['results'] as List).whereType<Map>().map((item) => item.cast<String, dynamic>()).toList()
            : const [];
        _metrics = (asMap(results[5])['metrics'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
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

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (range == null || !mounted) return;
    setState(() => _range = range);
    _load();
  }

  void _quick(int days) {
    setState(() => _range = DateTimeRange(start: DateTime.now().subtract(Duration(days: days - 1)), end: DateTime.now()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    final tabs = zh
        ? const ['文件', '已用空间', '用户', '流量', 'AI 使用量', '统计报表', '指标']
        : const ['Files', 'Storage', 'Users', 'Traffic', 'AI usage', 'Reports', 'Metrics'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '统计' : 'Statistics',
          tabs: tabs,
          activeTab: _tab,
          onTab: (index) => setState(() => _tab = index),
          actions: [
            TextButton(onPressed: () => _quick(7), child: Text(zh ? '7天' : '7 days')),
            TextButton(onPressed: () => _quick(30), child: Text(zh ? '30天' : '30 days')),
            TextButton(onPressed: () => _quick(365), child: Text(zh ? '1年' : '1 year')),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined, size: 14),
              label: Text('${_start.substring(0, 10)} ~ ${_end.substring(0, 10)}', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
          ],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: switch (_tab) {
                        0 => _fileStats(zh),
                        1 => _storageStats(zh),
                        2 => _userStats(zh),
                        3 => _trafficStats(zh),
                        4 => _aiStats(zh),
                        5 => _reportsStats(zh),
                        _ => _metricsStats(zh),
                      },
                    ),
        ),
      ],
    );
  }

  Widget _fileStats(bool zh) {
    final totals = {'added': 0, 'visited': 0, 'modified': 0, 'deleted': 0};
    for (final item in _fileOps) {
      for (final key in totals.keys) {
        totals[key] = (totals[key] ?? 0) + ((item[key] as num?)?.toInt() ?? 0);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              _summaryCard(zh ? '新增' : 'Added', totals['added']!, AppColors.success),
              const SizedBox(width: 12),
              _summaryCard(zh ? '访问' : 'Visited', totals['visited']!, AppColors.primary),
              const SizedBox(width: 12),
              _summaryCard(zh ? '修改' : 'Modified', totals['modified']!, const Color(0xFF5B8FF9)),
              const SizedBox(width: 12),
              _summaryCard(zh ? '删除' : 'Deleted', totals['deleted']!, AppColors.danger),
            ],
          ),
        ),
        AdminTable(
          headers: [zh ? '日期' : 'Date', zh ? '新增' : 'Added', zh ? '访问' : 'Visited', zh ? '修改' : 'Modified', zh ? '删除' : 'Deleted'],
          rows: [
            for (final item in _fileOps)
              [
                (item['datetime']?.toString() ?? '').substring(0, (item['datetime']?.toString() ?? '').length.clamp(0, 10)),
                '${item['added'] ?? 0}',
                '${item['visited'] ?? 0}',
                '${item['modified'] ?? 0}',
                '${item['deleted'] ?? 0}',
              ],
          ],
          emptyLabel: zh ? '暂无统计数据' : 'No statistics',
        ),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(width: 4, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageStats(bool zh) {
    final max = _storage.fold<double>(0, (value, item) => [value, (item['total_storage'] as num?)?.toDouble() ?? 0].reduce((a, b) => a > b ? a : b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zh ? '已用空间' : 'Used storage', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                for (final item in _storage)
                  _barRow(
                    item['datetime']?.toString().substring(0, 10) ?? '',
                    formatBytes((item['total_storage'] as num?)?.toInt() ?? 0),
                    max == 0 ? 0 : ((item['total_storage'] as num?)?.toDouble() ?? 0) / max,
                  ),
              ],
            ),
          ),
        ),
        AdminTable(
          headers: [zh ? '日期' : 'Date', zh ? '总空间' : 'Total storage'],
          rows: [for (final item in _storage) [item['datetime']?.toString().substring(0, 10) ?? '', formatBytes((item['total_storage'] as num?)?.toInt() ?? 0)]],
          emptyLabel: zh ? '暂无统计数据' : 'No statistics',
        ),
      ],
    );
  }

  Widget _userStats(bool zh) {
    return AdminTable(
      headers: [zh ? '日期' : 'Date', zh ? '活跃用户' : 'Active users'],
      rows: [for (final item in _activeUsers) [item['datetime']?.toString().substring(0, 10) ?? '', '${item['count'] ?? 0}']],
      emptyLabel: zh ? '暂无统计数据' : 'No statistics',
    );
  }

  Widget _trafficStats(bool zh) {
    return AdminTable(
      headers: zh
          ? const ['日期', '网页上传', '网页下载', '同步上传', '同步下载', '链接上传', '链接下载']
          : const ['Date', 'Web upload', 'Web download', 'Sync upload', 'Sync download', 'Link upload', 'Link download'],
      rows: [
        for (final item in _traffic)
          [
            item['datetime']?.toString().substring(0, 10) ?? '',
            formatBytes((item['web-file-upload'] as num?)?.toInt() ?? 0),
            formatBytes((item['web-file-download'] as num?)?.toInt() ?? 0),
            formatBytes((item['sync-file-upload'] as num?)?.toInt() ?? 0),
            formatBytes((item['sync-file-download'] as num?)?.toInt() ?? 0),
            formatBytes((item['link-file-upload'] as num?)?.toInt() ?? 0),
            formatBytes((item['link-file-download'] as num?)?.toInt() ?? 0),
          ],
      ],
      columnWidth: 130,
      emptyLabel: zh ? '暂无统计数据' : 'No statistics',
    );
  }

  Widget _aiStats(bool zh) {
    return AdminTable(
      headers: zh ? const ['资料库', '请求数', 'Token 数'] : const ['Library', 'Requests', 'Tokens'],
      rows: [
        for (final item in _ai)
          [
            adminMapText(item, ['repo_name', 'name', 'repo_id']),
            '${item['count'] ?? item['requests'] ?? 0}',
            '${item['token_count'] ?? item['tokens'] ?? 0}',
          ],
      ],
      emptyLabel: zh ? '暂无 AI 使用数据' : 'No AI usage',
    );
  }

  Widget _reportsStats(bool zh) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _reportCard(
            zh ? '用户月流量' : 'User monthly traffic',
            zh ? '生成指定月份的用户流量统计报表。' : 'Generate a monthly traffic report for all users.',
            month: true,
            onDownload: () => _downloadReport('user-traffic'),
          ),
          const SizedBox(height: 12),
          _reportCard(
            zh ? '用户存储空间' : 'User storage',
            zh ? '生成当前所有用户的存储空间统计报表。' : 'Generate a storage report for all users.',
            month: false,
            onDownload: () => _downloadReport('user-storage'),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(String title, String subtitle, {required bool month, required VoidCallback onDownload}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          if (month) ...[
            SizedBox(
              width: 130,
              child: TextField(
                controller: _month,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(hintText: 'YYYY-MM', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton.icon(
            onPressed: _downloadingReport ? null : onDownload,
            icon: _downloadingReport
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined, size: 16),
            label: Text(L10n.of(context).zh ? '生成统计报表' : 'Generate report', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(String kind) async {
    setState(() => _downloadingReport = true);
    try {
      final month = _month.text.trim().replaceAll('-', '');
      final bytes = await context.read<AppSession>().api!.adminStatisticsReport(kind: kind, month: month.isEmpty ? null : month);
      final name = kind == 'user-traffic' ? 'user-traffic-${month.isEmpty ? 'all' : month}.xlsx' : 'user-storage.xlsx';
      final location = await getSaveLocation(suggestedName: name);
      if (location == null) return;
      await XFile.fromData(bytes, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: name).saveTo(location.path);
      if (mounted) showToast(context, L10n.of(context).savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _downloadingReport = false);
    }
  }

  Widget _metricsStats(bool zh) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (final metric in _metrics)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${metric['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('${metric['help'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Text(
                    (metric['data_points'] is List && (metric['data_points'] as List).isNotEmpty)
                        ? '${((metric['data_points'] as List).first as Map)['value'] ?? ''}'
                        : '',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _barRow(String label, String value, double fraction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

class AdminDevicesPanel extends StatefulWidget {
  const AdminDevicesPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminDevicesPanel> createState() => _AdminDevicesPanelState();
}

class _AdminDevicesPanelState extends State<AdminDevicesPanel> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = const [];
  List<Map<String, dynamic>> _errors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminDevicesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppSession>().api!;
      if (_tab == 2) {
        final data = await api.adminDeviceErrors();
        _errors = (data['device_errors'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
      } else {
        final data = await api.adminDevices(platform: _tab == 0 ? 'desktop' : 'mobile');
        _devices = (data['devices'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _unlink(Map<String, dynamic> device) async {
    final id = adminMapText(device, ['id', 'device_id']);
    if (id.isEmpty) return;
    try {
      await context.read<AppSession>().api!.unlinkAdminDevice(id);
      await _load();
      if (mounted) showToast(context, L10n.of(context).zh ? '设备已断开' : 'Device unlinked');
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '设备' : 'Devices',
          tabs: zh ? const ['桌面客户端', '移动客户端', '错误'] : const ['Desktop', 'Mobile', 'Errors'],
          activeTab: _tab,
          onTab: (index) {
            setState(() => _tab = index);
            _load();
          },
          actions: [IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load)],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_tab == 2)
                            AdminTable(
                              headers: zh ? const ['用户', '设备', '错误', '时间'] : const ['User', 'Device', 'Error', 'Time'],
                              rows: [
                                for (final item in _errors)
                                  [
                                    adminMapText(item, ['email', 'user_email', 'user_name']),
                                    adminMapText(item, ['device_name', 'device', 'name']),
                                    adminMapText(item, ['error', 'error_msg', 'message']),
                                    adminDateLabel(adminMapText(item, ['time', 'created_at', 'last_accessed'])),
                                  ],
                              ],
                              emptyLabel: zh ? '没有设备错误' : 'No device errors',
                            )
                          else ...[
                            AdminTable(
                              headers: zh ? const ['设备', '用户', '版本', '最后访问', 'IP', '操作'] : const ['Device', 'User', 'Version', 'Last access', 'IP', 'Action'],
                              rows: [
                                for (final item in _devices)
                                  [
                                    adminMapText(item, ['name', 'device_name', 'id']),
                                    adminMapText(item, ['user_email', 'email', 'user_name']),
                                    adminMapText(item, ['version', 'client_version', 'device_version']),
                                    adminDateLabel(adminMapText(item, ['last_accessed', 'last_access', 'time'])),
                                    adminMapText(item, ['ip', 'last_ip']),
                                    zh ? '断开' : 'Unlink',
                                  ],
                              ],
                              emptyLabel: zh ? '没有连接的客户端' : 'No connected clients',
                            ),
                            if (_devices.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    for (final item in _devices)
                                      OutlinedButton(
                                        onPressed: () => _unlink(item),
                                        child: Text(adminMapText(item, ['name', 'device_name', 'id']), style: const TextStyle(fontSize: 11)),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class AdminDepartmentsPanel extends StatefulWidget {
  const AdminDepartmentsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminDepartmentsPanel> createState() => _AdminDepartmentsPanelState();
}

class _AdminDepartmentsPanelState extends State<AdminDepartmentsPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _departments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminDepartmentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppSession>().api!.adminDepartments();
      if (!mounted) return;
      setState(() {
        _departments = data;
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

  Future<void> _create({int? parentId}) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentId == null ? (l10n.zh ? '新建顶级部门' : 'New top department') : (l10n.zh ? '新建子部门' : 'New sub-department')),
        content: SizedBox(
          width: 360,
          child: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: l10n.zh ? '部门名称' : 'Department name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.create)),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await context.read<AppSession>().api!.createAdminDepartment(name, parentId: parentId);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _rename(Map<String, dynamic> department) async {
    final l10n = L10n.of(context);
    final id = (department['id'] as num?)?.toInt();
    if (id == null) return;
    final controller = TextEditingController(text: department['name']?.toString() ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '重命名部门' : 'Rename department'),
        content: SizedBox(width: 360, child: TextField(controller: controller, autofocus: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await context.read<AppSession>().api!.renameAdminDepartment(id, name);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _editQuota(Map<String, dynamic> department) async {
    final l10n = L10n.of(context);
    final id = (department['id'] as num?)?.toInt();
    if (id == null) return;
    final quota = (department['quota'] as num?)?.toInt() ?? -2;
    final controller = TextEditingController(text: quota > 0 ? '$quota' : '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '设置部门配额' : 'Department quota'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.zh ? '配额 (MB，留空不限制)' : 'Quota (MB, empty for unlimited)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await context.read<AppSession>().api!.updateAdminDepartmentQuota(id, result.isEmpty ? -2 : int.tryParse(result) ?? -2);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _manageLibraries(Map<String, dynamic> department) async {
    final id = (department['id'] as num?)?.toInt();
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AdminGroupLibrariesDialog(groupId: id, groupName: department['name']?.toString() ?? ''),
    );
    if (mounted) _load();
  }

  Future<void> _manageMembers(Map<String, dynamic> department) async {
    final id = (department['id'] as num?)?.toInt();
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AdminMembersDialog(
        departmentId: id,
        departmentName: department['name']?.toString() ?? '',
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> department) async {    final l10n = L10n.of(context);
    final id = (department['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除部门' : 'Delete department'),
        content: Text(l10n.zh ? '确定删除 ${department['name']} 及其子部门？' : 'Delete ${department['name']} and its sub-departments?'),
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
      await context.read<AppSession>().api!.deleteAdminDepartment(id);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  int _depth(Map<String, dynamic> department) {
    final depth = (department['admin_depth'] as num?)?.toInt();
    if (depth != null) return depth;
    var value = 0;
    var current = department;
    while (value < 12) {
      final parentId = current['parent_group_id'] ?? current['parent_id'];
      if (parentId == null || (parentId is num && parentId == 0)) break;
      final parent = _departments.where((item) => item['id'] == parentId).firstOrNull;
      if (parent == null) break;
      value += 1;
      current = parent;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '组织架构' : 'Departments',
          actions: [
            FilledButton.icon(
              onPressed: () => _create(),
              icon: const Icon(Icons.add, size: 15),
              label: Text(zh ? '新建部门' : 'New department', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
          ],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : _departments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(zh ? '尚未启用部门功能' : 'Departments are not enabled', style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 6),
                              Text(zh ? '创建第一个部门即可启用组织架构。' : 'Create the first department to enable it.', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => _create(),
                                icon: const Icon(Icons.add, size: 15),
                                label: Text(zh ? '开启部门功能' : 'Enable departments'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          children: [
                            for (final department in _departments)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.only(left: 14, right: 8),
                                height: 46,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                                child: Row(
                                  children: [
                                    SizedBox(width: _depth(department) * 22.0),
                                    const Icon(Icons.account_tree_outlined, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(department['name']?.toString() ?? '', style: const TextStyle(fontSize: 13))),
                                    Text(
                                      department['owner']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(onPressed: () => _create(parentId: (department['id'] as num?)?.toInt()), child: Text(zh ? '子部门' : 'Sub', style: const TextStyle(fontSize: 12))),
                                    TextButton(onPressed: () => _manageLibraries(department), child: Text(zh ? '资料库' : 'Libraries', style: const TextStyle(fontSize: 12))),
                                    TextButton(onPressed: () => _manageMembers(department), child: Text(zh ? '成员' : 'Members', style: const TextStyle(fontSize: 12))),
                                    TextButton(onPressed: () => _editQuota(department), child: Text(zh ? '配额' : 'Quota', style: const TextStyle(fontSize: 12))),
                                    TextButton(onPressed: () => _rename(department), child: Text(zh ? '重命名' : 'Rename', style: const TextStyle(fontSize: 12))),
                                    IconButton(
                                      onPressed: () => _delete(department),
                                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                      tooltip: l10n.delete,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class AdminUserDetailDialog extends StatefulWidget {
  const AdminUserDetailDialog({super.key, required this.email});

  final String email;

  @override
  State<AdminUserDetailDialog> createState() => _AdminUserDetailDialogState();
}

class _AdminUserDetailDialogState extends State<AdminUserDetailDialog> {
  bool _loading = true;
  Map<String, dynamic> _user = const {};
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _links = const [];
  List<Map<String, dynamic>> _uploads = const [];
  List<Map<String, dynamic>> _libraries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api!;
    try {
      final results = await Future.wait([
        api.adminUser(widget.email),
        api.adminUserGroups(widget.email),
        api.adminUserShareLinks(widget.email),
        api.adminUserUploadLinks(widget.email),
        api.adminLibraries(query: widget.email),
      ]);
      if (!mounted) return;
      final libraries = (asMap(results[4])['repos'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const <Map<String, dynamic>>[];
      setState(() {
        _user = asMap(results[0]);
        _groups = results[1] as List<Map<String, dynamic>>;
        _links = results[2] as List<Map<String, dynamic>>;
        _uploads = results[3] as List<Map<String, dynamic>>;
        _libraries = libraries.where((item) => item['owner_email'] == widget.email || item['owner'] == widget.email).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return AlertDialog(
      title: Text(zh ? '用户详情' : 'User details'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row(zh ? '用户 ID' : 'User ID', widget.email),
                    _row(l10n.name, '${_user['name'] ?? ''}'),
                    _row(zh ? '角色' : 'Role', adminTruthy(_user['is_staff']) ? (zh ? '管理员' : 'Admin') : (zh ? '普通用户' : 'User')),
                    _row(zh ? '状态' : 'Status', adminTruthy(_user['is_active']) ? (zh ? '启用' : 'Active') : (zh ? '禁用' : 'Disabled')),
                    _row(zh ? '已用空间 / 容量' : 'Usage / quota', '${formatBytes((_user['quota_usage'] as num?)?.toInt() ?? 0)} / ${(_user['quota_total'] as num?)?.toInt() == -2 ? (zh ? '不限' : 'Unlimited') : formatBytes((_user['quota_total'] as num?)?.toInt() ?? 0)}'),
                    _row(zh ? '创建时间' : 'Created', adminDateLabel(_user['create_time']?.toString())),
                    _row(zh ? '最后登录' : 'Last login', adminDateLabel(_user['last_login']?.toString())),
                    const SizedBox(height: 10),
                    _section(zh ? '拥有的资料库' : 'Owned libraries', _libraries.map((item) => '${item['name'] ?? ''} · ${item['size_formatted'] ?? ''}').toList()),
                    _section(zh ? '群组' : 'Groups', _groups.map((item) => '${item['name'] ?? ''} (${item['role'] ?? ''})').toList()),
                    _section(zh ? '分享链接' : 'Share links', _links.map((item) => '${item['obj_name'] ?? ''} · ${item['view_cnt'] ?? 0} ${zh ? '次访问' : 'views'}').toList()),
                    _section(zh ? '上传链接' : 'Upload links', _uploads.map((item) => '${item['obj_name'] ?? item['repo_name'] ?? ''}').toList()),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(zh ? '关闭' : 'Close')),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          for (final item in items) Text(item, style: const TextStyle(fontSize: 12.5, height: 1.6)),
        ],
      ),
    );
  }
}

class AdminMembersDialog extends StatefulWidget {
  const AdminMembersDialog({required this.departmentId, required this.departmentName, this.addressBook = true});

  final int departmentId;
  final String departmentName;
  final bool addressBook;

  @override
  State<AdminMembersDialog> createState() => _AdminMembersDialogState();
}

class _AdminMembersDialogState extends State<AdminMembersDialog> {
  final _email = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _members = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppSession>().api!;
      final data = widget.addressBook ? await api.adminDepartment(widget.departmentId) : await api.adminGroupMembers(widget.departmentId);
      if (!mounted) return;
      setState(() {
        _members = asMapList(data['members']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _add() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<AppSession>().api!.addAdminDepartmentMember(widget.departmentId, email, isAdmin: _isAdmin);
      _email.clear();
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final email = adminMapText(member, ['email']);
    if (email.isEmpty) return;
    try {
      await context.read<AppSession>().api!.removeAdminDepartmentMember(widget.departmentId, email);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return AlertDialog(
      title: Text('${zh ? '部门成员' : 'Department members'} · ${widget.departmentName}'),
      content: SizedBox(
        width: 560,
        height: 380,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _email,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(labelText: zh ? '成员邮箱' : 'Member email', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                Checkbox(
                  value: _isAdmin,
                  onChanged: (value) => setState(() => _isAdmin = value == true),
                ),
                Text(zh ? '管理员' : 'Admin', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _add,
                  child: Text(zh ? '添加' : 'Add', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                      ? Center(child: Text(zh ? '暂无成员' : 'No members', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)))
                      : ListView.separated(
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final email = adminMapText(member, ['email']);
                            final name = adminMapText(member, ['name']);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(name.isEmpty ? email : name, style: const TextStyle(fontSize: 13)),
                              subtitle: email.isEmpty || name.isEmpty ? null : Text(email, style: const TextStyle(fontSize: 11.5)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (adminTruthy(member['is_admin']))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(4)),
                                      child: Text(zh ? '部门管理员' : 'Dept admin', style: const TextStyle(fontSize: 10.5, color: AppColors.primaryDark)),
                                    ),
                                  IconButton(
                                    onPressed: () => _remove(member),
                                    icon: const Icon(Icons.person_remove_outlined, size: 16, color: AppColors.danger),
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(zh ? '关闭' : 'Close')),
      ],
    );
  }
}

class AdminGroupLibrariesDialog extends StatefulWidget {
  const AdminGroupLibrariesDialog({super.key, required this.groupId, required this.groupName});

  final int groupId;
  final String groupName;

  @override
  State<AdminGroupLibrariesDialog> createState() => _AdminGroupLibrariesDialogState();
}

class _AdminGroupLibrariesDialogState extends State<AdminGroupLibrariesDialog> {
  final _name = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _libraries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppSession>().api!.adminGroupLibraries(widget.groupId);
      if (!mounted) return;
      setState(() {
        _libraries = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<AppSession>().api!.addAdminGroupLibrary(widget.groupId, name);
      _name.clear();
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> library) async {
    final id = adminMapText(library, ['id', 'repo_id']);
    if (id.isEmpty) return;
    try {
      await context.read<AppSession>().api!.removeAdminGroupLibrary(widget.groupId, id);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return AlertDialog(
      title: Text('${zh ? '群组资料库' : 'Group libraries'} · ${widget.groupName}'),
      content: SizedBox(
        width: 560,
        height: 380,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(labelText: zh ? '资料库名称' : 'Library name', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(onPressed: _saving ? null : _add, child: Text(zh ? '新建并添加' : 'Create and add', style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _libraries.isEmpty
                      ? Center(child: Text(zh ? '暂无群组资料库' : 'No group libraries', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)))
                      : ListView.separated(
                          itemCount: _libraries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final library = _libraries[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(adminMapText(library, ['name', 'repo_name']), style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${adminMapText(library, ['owner_name', 'owner_email'])} · ${formatBytes((library['size'] as num?)?.toInt() ?? 0)}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: IconButton(
                                onPressed: () => _remove(library),
                                icon: const Icon(Icons.remove_circle_outline, size: 17, color: AppColors.danger),
                                tooltip: l10n.delete,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(zh ? '关闭' : 'Close')),
      ],
    );
  }
}

class AdminNotificationsPanel extends StatefulWidget {
  const AdminNotificationsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminNotificationsPanel> createState() => _AdminNotificationsPanelState();
}

class _AdminNotificationsPanelState extends State<AdminNotificationsPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminNotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppSession>().api!.adminNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
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

  Future<void> _add() async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '添加新通知' : 'New notification'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
            decoration: InputDecoration(hintText: l10n.zh ? '输入要展示给所有用户的通知内容' : 'Message shown to all users'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.zh ? '提交' : 'Submit')),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty) return;
    try {
      await context.read<AppSession>().api!.addAdminNotification(message);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _setCurrent(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await context.read<AppSession>().api!.setAdminNotificationCurrent(id);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await context.read<AppSession>().api!.deleteAdminNotification(id);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '通知' : 'Notifications',
          actions: [
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 15),
              label: Text(zh ? '添加新通知' : 'Add notification', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
          ],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : _notifications.isEmpty
                      ? Center(child: Text(zh ? '没有通知' : 'No notifications', style: const TextStyle(fontSize: 13, color: AppColors.muted)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          children: [
                            for (final item in _notifications)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['msg']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
                                          const SizedBox(height: 5),
                                          Text(adminDateLabel(item['timestamp']?.toString() ?? item['created_at']?.toString()), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                        ],
                                      ),
                                    ),
                                    if (adminTruthy(item['is_current']))
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(4)),
                                        child: Text(zh ? '当前展示' : 'Current', style: const TextStyle(fontSize: 10.5, color: AppColors.primaryDark)),
                                      )
                                    else
                                      TextButton(onPressed: () => _setCurrent(item), child: Text(zh ? '设为当前' : 'Set current', style: const TextStyle(fontSize: 12))),
                                    IconButton(
                                      onPressed: () => _delete(item),
                                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                      tooltip: l10n.delete,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class AdminLogsPanel extends StatefulWidget {
  const AdminLogsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminLogsPanel> createState() => _AdminLogsPanelState();
}

class _AdminLogsPanelState extends State<AdminLogsPanel> {
  static const _types = ['login', 'file-access', 'file-update', 'share-permission', 'repo-transfer', 'group-member'];
  int _tab = 0;
  bool _loading = true;
  String? _error;
  DateTimeRange _range = DateTimeRange(start: DateTime.now().subtract(const Duration(days: 29)), end: DateTime.now());
  List<Map<String, dynamic>> _rows = const [];
  bool _exporting = false;

  String get _start => '${_range.start.year.toString().padLeft(4, '0')}-${_range.start.month.toString().padLeft(2, '0')}-${_range.start.day.toString().padLeft(2, '0')}';
  String get _end => '${_range.end.year.toString().padLeft(4, '0')}-${_range.end.month.toString().padLeft(2, '0')}-${_range.end.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminLogsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  List<Map<String, dynamic>> _listFrom(Map<String, dynamic> data) {
    for (final key in ['login_log_list', 'file_access_log_list', 'file_update_log_list', 'share_permission_log_list', 'repo_transfer_log_list', 'group_invite_log_list']) {
      final value = data[key];
      if (value is List) return value.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
    }
    for (final value in data.values) {
      if (value is List) return value.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppSession>().api!.adminLogsByType(type: _types[_tab], start: _start, end: _end);
      if (!mounted) return;
      setState(() {
        _rows = _listFrom(data);
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

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (range == null || !mounted) return;
    setState(() => _range = range);
    _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final api = context.read<AppSession>().api!;
      final data = await api.adminLogsByType(type: _types[_tab], start: _start, end: _end, page: 1, perPage: 5000);
      final rows = _listFrom(data);
      final columns = _columns(L10n.of(context).zh);
      final buffer = StringBuffer();
      buffer.writeln(columns.$1.map(_csvCell).join(','));
      final source = <List<String>>[];
      if (_types[_tab] == 'login') {
        for (final item in rows) {
          source.add([
            adminMapText(item, ['name', 'email']),
            adminMapText(item, ['login_ip', 'ip']),
            adminTruthy(item['log_success']) || adminTruthy(item['login_success']) ? 'Success' : 'Failed',
            adminDateLabel(adminMapText(item, ['login_time', 'time'])),
          ]);
        }
      } else {
        source.addAll(columns.$2);
      }
      for (final row in source) {
        buffer.writeln(row.map(_csvCell).join(','));
      }
      final location = await getSaveLocation(suggestedName: '${_types[_tab]}-logs-$_start.csv');
      if (location == null) return;
      await XFile.fromData(
        utf8.encode(buffer.toString()),
        mimeType: 'text/csv',
        name: '${_types[_tab]}-logs-$_start.csv',
      ).saveTo(location.path);
      if (mounted) showToast(context, L10n.of(context).savedSuccessfully);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  (List<String>, List<List<String>>) _columns(bool zh) {
    switch (_types[_tab]) {
      case 'login':
        return (
          zh ? const ['名称', 'IP', '状态', '时间'] : const ['Name', 'IP', 'Status', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['name', 'email']),
                adminMapText(item, ['login_ip', 'ip']),
                adminTruthy(item['log_success']) || adminTruthy(item['login_success']) ? (zh ? '成功' : 'Success') : (zh ? '失败' : 'Failed'),
                adminDateLabel(adminMapText(item, ['login_time', 'time'])),
              ],
          ],
        );
      case 'file-update':
        return (
          zh ? const ['用户', '资料库', '文件', '操作', '时间'] : const ['User', 'Library', 'File', 'Operation', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['email', 'name', 'user']),
                adminMapText(item, ['repo_name', 'repo_id']),
                adminMapText(item, ['file_name', 'file_path', 'path']),
                adminMapText(item, ['op_type', 'operation', 'type']),
                adminDateLabel(adminMapText(item, ['time', 'op_time', 'created_at'])),
              ],
          ],
        );
      case 'file-access':
        return (
          zh ? const ['用户', 'IP', '方式', '设备', '资料库', '文件', '时间'] : const ['User', 'IP', 'Type', 'Device', 'Library', 'File', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['email', 'name', 'user']),
                adminMapText(item, ['ip']),
                adminMapText(item, ['event_type']),
                adminMapText(item, ['device']),
                adminMapText(item, ['repo_name', 'repo_id']),
                adminMapText(item, ['file_path', 'file_name', 'path']),
                adminDateLabel(adminMapText(item, ['time', 'created_at'])),
              ],
          ],
        );
      case 'share-permission':
        return (
          zh ? const ['操作者', '资料库', '文件', '共享给', '权限', '时间'] : const ['Operator', 'Library', 'File', 'Shared to', 'Permission', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['email', 'name', 'operator']),
                adminMapText(item, ['repo_name', 'repo_id']),
                adminMapText(item, ['path', 'file_path']),
                adminMapText(item, ['share_to', 'to_email', 'group_name']),
                adminMapText(item, ['permission', 'perm']),
                adminDateLabel(adminMapText(item, ['time', 'created_at'])),
              ],
          ],
        );
      case 'repo-transfer':
        return (
          zh ? const ['资料库', '原拥有者', '新拥有者', '时间'] : const ['Library', 'From', 'To', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['repo_name', 'repo_id']),
                adminMapText(item, ['from_email', 'old_owner']),
                adminMapText(item, ['to_email', 'new_owner']),
                adminDateLabel(adminMapText(item, ['time', 'created_at'])),
              ],
          ],
        );
      default:
        return (
          zh ? const ['群组', '成员', '操作', '操作者', '时间'] : const ['Group', 'Member', 'Action', 'Operator', 'Time'],
          [
            for (final item in _rows)
              [
                adminMapText(item, ['group_name', 'group']),
                adminMapText(item, ['member', 'email', 'user']),
                adminMapText(item, ['operation', 'action']),
                adminMapText(item, ['operator', 'operator_email']),
                adminDateLabel(adminMapText(item, ['time', 'created_at'])),
              ],
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    final tabs = zh ? const ['登录', '文件访问', '文件更新', '权限', '资料库转让', '群组成员'] : const ['Login', 'File access', 'File update', 'Permission', 'Library transfer', 'Group member'];
    final columns = _columns(zh);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '日志' : 'Logs',
          tabs: tabs,
          activeTab: _tab,
          onTab: (index) {
            setState(() => _tab = index);
            _load();
          },
          actions: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined, size: 14),
              label: Text('$_start ~ $_end', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined, size: 15),
              label: Text(zh ? '导出 CSV' : 'Export CSV', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
          ],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: AdminTable(headers: columns.$1, rows: columns.$2, emptyLabel: zh ? '暂无日志' : 'No logs'),
                      ),
                    ),
        ),
      ],
    );
  }
}

class AdminVirusPanel extends StatefulWidget {
  const AdminVirusPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminVirusPanel> createState() => _AdminVirusPanelState();
}

class _AdminVirusPanelState extends State<AdminVirusPanel> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminVirusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppSession>().api!.adminVirusFiles(handled: _tab == 1 ? false : null);
      if (!mounted) return;
      setState(() {
        _files = (data['virus_file_list'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
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

  Future<void> _ignore(Map<String, dynamic> file, bool ignore) async {
    final id = (file['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await context.read<AppSession>().api!.ignoreAdminVirusFile(id, ignore);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final l10n = L10n.of(context);
    final id = (file['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '删除受感染文件' : 'Delete infected file'),
        content: Text(l10n.zh ? '确定从资料库中删除该文件？' : 'Delete this file from the library?'),
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
      await context.read<AppSession>().api!.deleteAdminVirusFiles([id]);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '病毒扫描' : 'Virus scan',
          tabs: zh ? const ['全部', '未处理'] : const ['All', 'Unhandled'],
          activeTab: _tab,
          onTab: (index) {
            setState(() => _tab = index);
            _load();
          },
          actions: [IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load)],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          AdminTable(
                            headers: zh ? const ['资料库', '拥有者', '受感染文件', '签名', '状态', '操作'] : const ['Library', 'Owner', 'Infected file', 'Signature', 'Status', 'Action'],
                            rows: [
                              for (final file in _files)
                                [
                                  adminMapText(file, ['repo_name', 'repo_id']),
                                  adminMapText(file, ['owner', 'owner_email', 'user']),
                                  adminMapText(file, ['file_path', 'path', 'file_name']),
                                  adminMapText(file, ['virus_name', 'signature']),
                                  adminTruthy(file['ignore']) || adminTruthy(file['handled']) ? (zh ? '已处理' : 'Handled') : (zh ? '未处理' : 'Unhandled'),
                                  zh ? '忽略 / 删除' : 'Ignore / Delete',
                                ],
                            ],
                            columnWidth: 180,
                            emptyLabel: zh ? '没有扫描到病毒文件' : 'No infected files',
                          ),
                          if (_files.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final file in _files)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          adminMapText(file, ['file_name', 'file_path']),
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton(
                                          onPressed: () => _ignore(file, file['ignore'] != true),
                                          child: Text(adminTruthy(file['ignore']) ? (zh ? '解除忽略' : 'Unignore') : (zh ? '忽略' : 'Ignore'), style: const TextStyle(fontSize: 11.5)),
                                        ),
                                        TextButton(onPressed: () => _delete(file), child: Text(zh ? '删除' : 'Delete', style: const TextStyle(fontSize: 11.5, color: AppColors.danger))),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class AdminAdminLogsPanel extends StatefulWidget {
  const AdminAdminLogsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminAdminLogsPanel> createState() => _AdminAdminLogsPanelState();
}

class _AdminAdminLogsPanelState extends State<AdminAdminLogsPanel> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminAdminLogsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppSession>().api!;
      final data = _tab == 0 ? await api.adminLogs() : await api.adminAdminLoginLogs();
      final list = _tab == 0 ? data['data'] : data['data'];
      if (!mounted) return;
      setState(() {
        _rows = (list as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
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

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '管理员日志' : 'Admin logs',
          tabs: zh ? const ['操作', '登录'] : const ['Operation', 'Login'],
          activeTab: _tab,
          onTab: (index) {
            setState(() => _tab = index);
            _load();
          },
          actions: [IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load)],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _tab == 0
                            ? AdminTable(
                                headers: zh ? const ['管理员', '操作', '详情', '时间'] : const ['Admin', 'Operation', 'Detail', 'Time'],
                                rows: [
                                  for (final item in _rows)
                                    [
                                      adminMapText(item, ['email', 'admin', 'name']),
                                      adminMapText(item, ['operation', 'op_type', 'action']),
                                      adminMapText(item, ['detail', 'extra', 'description']),
                                      adminDateLabel(adminMapText(item, ['time', 'created_at'])),
                                    ],
                                ],
                                emptyLabel: zh ? '暂无日志' : 'No logs',
                              )
                            : AdminTable(
                                headers: zh ? const ['名称', 'IP', '状态', '时间'] : const ['Name', 'IP', 'Status', 'Time'],
                                rows: [
                                  for (final item in _rows)
                                    [
                                      adminMapText(item, ['name', 'email']),
                                      adminMapText(item, ['login_ip', 'ip']),
                                      adminTruthy(item['login_success']) || adminTruthy(item['log_success']) ? (zh ? '成功' : 'Success') : (zh ? '失败' : 'Failed'),
                                      adminDateLabel(adminMapText(item, ['login_time', 'time'])),
                                    ],
                                ],
                                emptyLabel: zh ? '暂无日志' : 'No logs',
                              ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class AdminSettingsPanel extends StatefulWidget {
  const AdminSettingsPanel({super.key, this.reloadTick = 0});

  final int reloadTick;

  @override
  State<AdminSettingsPanel> createState() => _AdminSettingsPanelState();
}

class _AdminSettingsPanelState extends State<AdminSettingsPanel> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _values = {};
  final _controllers = <String, TextEditingController>{};

  static const _textKeys = [
    'SITE_TITLE',
    'SITE_NAME',
    'LOGIN_REMEMBER_DAYS',
    'LOGIN_ATTEMPT_LIMIT',
    'REPO_PASSWORD_MIN_LENGTH',
    'SHARE_LINK_PASSWORD_MIN_LENGTH',
    'SHARE_LINK_PASSWORD_STRENGTH_LEVEL',
    'SHARE_LINK_TOKEN_LENGTH',
    'TEXT_PREVIEW_EXT',
    'CUSTOM_CSS',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick) _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppSession>().api!.adminWebSettings();
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      for (final key in _textKeys) {
        if (data[key] != null) _controllers[key] = TextEditingController(text: '${data[key]}');
      }
      setState(() {
        _values = data;
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

  Future<void> _save() async {
    final l10n = L10n.of(context);
    setState(() => _saving = true);
    try {
      final values = Map<String, dynamic>.from(_values);
      for (final entry in _controllers.entries) {
        final original = _values[entry.key];
        if (original is int) {
          values[entry.key] = int.tryParse(entry.value.text.trim()) ?? original;
        } else {
          values[entry.key] = entry.value.text;
        }
      }
      await context.read<AppSession>().api!.updateAdminWebSettings(values);
      if (!mounted) return;
      setState(() {
        _values = values;
        _saving = false;
      });
      showToast(context, l10n.savedSuccessfully);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _upload(String kind) async {
    final l10n = L10n.of(context);
    final file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'ico', 'gif', 'webp'])]);
    if (file == null) return;
    try {
      await context.read<AppSession>().api!.uploadAdminBrandAsset(kind, file.path);
      if (!mounted) return;
      showToast(context, l10n.savedSuccessfully);
      _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final zh = l10n.zh;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPanelHeader(
          title: zh ? '设置' : 'Settings',
          subtitle: zh ? '修改后立即生效' : 'Changes apply immediately',
          actions: [
            OutlinedButton(onPressed: _loading ? null : _load, child: Text(zh ? '重置' : 'Reset')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _loading || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(l10n.save, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
          ],
        ),
        Expanded(
          child: _loading
              ? adminLoading()
              : _error != null
                  ? adminError(context, _error!, _load)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(zh ? '品牌定制' : 'Branding', [
                            _textField('SITE_TITLE', zh ? '网站标题' : 'Site title', zh ? '显示在浏览器标签中' : 'Shown in the browser tab'),
                            _textField('SITE_NAME', zh ? '网站名称' : 'Site name', zh ? '发送邮件时显示的名称' : 'Shown in emails'),
                            _brandRow(zh ? '标志' : 'Logo', 'logo', '256 x 64'),
                            _brandRow(zh ? '网站图标' : 'Favicon', 'favicon', '32 x 32'),
                            _brandRow(zh ? '登录背景图' : 'Login background', 'background', '2400 x 1600'),
                            _toggle('ENABLE_BRANDING_CSS', zh ? '开启品牌 CSS' : 'Enable branding CSS', zh ? '使用定制的 CSS' : 'Use custom CSS'),
                            _longField('CUSTOM_CSS', zh ? '定制的 CSS' : 'Custom CSS', zh ? '输入自定义 CSS' : 'Custom CSS'),
                          ]),
                          _section(zh ? '用户' : 'Users', [
                            _toggle('ENABLE_SIGNUP', zh ? '允许新注册' : 'Allow sign-up', zh ? '允许用户注册新账号' : 'Allow new users to sign up'),
                            _toggle('ACTIVATE_AFTER_REGISTRATION', zh ? '注册后激活' : 'Activate after registration', zh ? '注册后立即激活账号' : 'Activate accounts immediately'),
                            _toggle('REGISTRATION_SEND_MAIL', zh ? '发送激活邮件' : 'Send activation email', zh ? '注册后发送激活邮件' : 'Send an activation email'),
                            _textField('LOGIN_REMEMBER_DAYS', zh ? '保持登录' : 'Remember login', zh ? '保持登录状态的天数' : 'Days to remember login'),
                            _textField('LOGIN_ATTEMPT_LIMIT', zh ? '登录尝试次数限制' : 'Login attempt limit', zh ? '失败几次后显示验证码' : 'Show captcha after failed attempts'),
                            _toggle('FREEZE_USER_ON_LOGIN_FAILED', zh ? '冻结失败登录的用户' : 'Freeze failed logins', zh ? '超过限制时冻结账号' : 'Freeze account after too many failures'),
                            _toggle('FORCE_PASSWORD_CHANGE', zh ? '强制更改密码' : 'Force password change', zh ? '首次登录必须修改密码' : 'Require password change on first login'),
                          ]),
                          _section(zh ? '群组' : 'Groups', [
                            _toggle('ENABLE_SHARE_TO_ALL_GROUPS', zh ? '开启所有群组共享' : 'Share to all groups', zh ? '允许共享给系统内任意群组' : 'Allow sharing with any group'),
                          ]),
                          _section(zh ? '密码' : 'Passwords', [
                            _toggle('USER_STRONG_PASSWORD_REQUIRED', zh ? '强密码' : 'Strong password', zh ? '注册或改密时强制使用强密码' : 'Require strong passwords'),
                            _toggle('ENABLE_TWO_FACTOR_AUTH', zh ? '开启两步验证' : 'Two-factor authentication', zh ? '允许用户启用两步验证' : 'Allow two-factor authentication'),
                          ]),
                          _section(zh ? '资料库' : 'Libraries', [
                            _toggle('ENABLE_REPO_HISTORY_SETTING', zh ? '资料库历史' : 'Library history', zh ? '允许用户更改历史设置' : 'Allow users to change history settings'),
                            _toggle('ENABLE_ENCRYPTED_LIBRARY', zh ? '加密资料库' : 'Encrypted libraries', zh ? '允许创建加密资料库' : 'Allow creating encrypted libraries'),
                            _textField('REPO_PASSWORD_MIN_LENGTH', zh ? '资料库密码最小长度' : 'Library password minimum', zh ? '加密资料库的最小密码长度' : 'Minimum encrypted library password length'),
                            _toggle('SHARE_LINK_FORCE_USE_PASSWORD', zh ? '分享/上传链接强制密码' : 'Require link password', zh ? '生成链接时强制使用密码' : 'Force passwords for links'),
                            _textField('SHARE_LINK_PASSWORD_MIN_LENGTH', zh ? '链接密码最小长度' : 'Link password minimum', zh ? '链接密码的最少字符数' : 'Minimum link password length'),
                            _textField('SHARE_LINK_PASSWORD_STRENGTH_LEVEL', zh ? '链接密码强度级别' : 'Link password strength', zh ? '密码强度 1-4' : 'Password strength 1-4'),
                            _textField('SHARE_LINK_TOKEN_LENGTH', zh ? '链接随机长度' : 'Link token length', zh ? '分享链接的随机字符串长度' : 'Share link token length'),
                            _toggle('ENABLE_USER_CLEAN_TRASH', zh ? '开启用户清理回收站' : 'Users can clean trash', zh ? '允许用户清空回收站' : 'Allow users to clean trash'),
                          ]),
                          _section(zh ? '在线预览' : 'Online preview', [
                            _longField('TEXT_PREVIEW_EXT', zh ? '文本文件扩展名' : 'Text file extensions', zh ? '用逗号分隔' : 'Comma separated'),
                          ]),
                          _section(zh ? '同步' : 'Sync', [
                            _toggle('DISABLE_SYNC_WITH_ANY_FOLDER', zh ? '禁用与任何目录同步' : 'Disable sync with any folder', zh ? '阻止桌面客户端同步任意目录' : 'Prevent syncing arbitrary folders'),
                          ]),
                          _section(zh ? '使用条款' : 'Terms and conditions', [
                            _toggle('ENABLE_TERMS_AND_CONDITIONS', zh ? '开启条款和条件' : 'Enable terms', zh ? '用户必须接受条款' : 'Users must accept terms'),
                          ]),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _toggle(String key, String title, String subtitle) {
    if (_values[key] is! bool) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          CompactSwitch(value: _values[key] == true, onChanged: (value) => setState(() => _values[key] = value)),
        ],
      ),
    );
  }

  Widget _textField(String key, String label, String hint) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 210, child: Text(label, style: const TextStyle(fontSize: 13))),
          SizedBox(
            width: 220,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _longField(String key, String label, String hint) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)),
          ),
        ],
      ),
    );
  }

  Widget _brandRow(String label, String kind, String size) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 210, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(size, style: const TextStyle(fontSize: 11.5, color: AppColors.muted))),
          OutlinedButton(onPressed: () => _upload(kind), child: Text(L10n.of(context).zh ? '修改' : 'Change', style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
