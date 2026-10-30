import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/workspace.dart';
import 'file_actions.dart';
import 'widgets.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({super.key, required this.workspace, required this.entry, required this.onClose, this.width = 330, this.onResize});

  final WorkspaceController workspace;
  final Dirent entry;
  final VoidCallback onClose;
  final double width;
  final ValueChanged<double>? onResize;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.repo;
    final record = workspace.recordFor(entry);
    final entryTags = workspace.tagsFor(entry);
    final metadata = _metadataRows(record, l10n);
    final content = Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Text(l10n.showDetails, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FileTypeIcon(name: entry.name, isDir: entry.isDir, size: 40, permission: entry.permission),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              entry.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              entry.path,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _actionButton(context, 'download', l10n.download, () => downloadEntries(context, workspace, [entry])),
                      const SizedBox(width: 6),
                      _actionButton(context, 'share', l10n.share, () => shareEntry(context, workspace, entry)),
                      if (!entry.isDir) ...[
                        const SizedBox(width: 6),
                        _actionButton(context, 'history', l10n.history, () => showFileHistory(context, workspace, entry)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (workspace.hasTags) ...[
                    Row(
                      children: [
                        Text(l10n.tags, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        IconAction(icon: 'plus-sign', tooltip: l10n.addTag, size: 14, onPressed: () => _showTagPicker(context)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (entryTags.isEmpty)
                      Text(l10n.noTagsHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in entryTags)
                            TagPill(
                              tag: tag,
                              onDeleted: () => workspace.assignTag(entry, tag, false),
                            ),
                          InkWell(
                            onTap: () => _showTagPicker(context),
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.borderStrong),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const WebIcon('plus-sign', size: 11),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                  ],
                  Text(l10n.fileInfo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  _infoRow(l10n.type, entry.isDir ? l10n.folder : (l10n.zh ? '文件' : 'File')),
                  _infoRow(l10n.fileSize, entry.isDir ? '—' : formatBytes(entry.size)),
                  _infoRow(l10n.modified, formatDateTime(entry.mtime)),
                  if (entry.modifierName != null) _infoRow(l10n.modifier, entry.modifierName!),
                  _infoRow(l10n.location, parentRepoPath(entry.path)),
                  _infoRow(l10n.fileId, entry.oid ?? '—', selectable: true),
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(l10n.metadata, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    for (final item in metadata) _infoRow(item.key, item.value),
                  ],
                  if (record?.aiSummary?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const WebIcon('ai', size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(l10n.aiSummary, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record!.aiSummary!.trim(),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.text, height: 1.6),
                      ),
                    ),
                  ],
                  if (repo != null && repo.encrypted) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const WebIcon('lock', size: 13, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(l10n.encryptedLibrary, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final handle = onResize == null
        ? null
        : SizedBox(width: 5, child: ResizeHandle(onDrag: onResize!));
    return Row(mainAxisSize: MainAxisSize.min, children: [if (handle != null) handle, content]);
  }

  Widget _actionButton(BuildContext context, String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: WebIcon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 30),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.5))
                : Text(value, style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.5)),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _metadataRows(MetadataRecord? record, L10n l10n) {
    if (record == null) return const [];
    final rows = <MapEntry<String, String>>[];
    final values = record.values;
    final description = values['_description'];
    if (description is String && description.trim().isNotEmpty) {
      rows.add(MapEntry(l10n.description, description.trim()));
    }
    final expiry = values['_expire_time'];
    if (expiry is String && expiry.isNotEmpty) {
      final date = DateTime.tryParse(expiry);
      rows.add(MapEntry(l10n.expiryTime, date == null ? expiry : formatDateTime(date)));
    }
    final status = values['_status'];
    if (status is String && status.isNotEmpty) {
      final text = switch (status) {
        '_in_progress' => l10n.zh ? '进行中' : 'In progress',
        '_in_review' => l10n.zh ? '待审核' : 'In review',
        '_done' => l10n.zh ? '已完成' : 'Done',
        '_outdated' => l10n.zh ? '已过期' : 'Outdated',
        _ => status,
      };
      rows.add(MapEntry(l10n.status, text));
    }
    return rows;
  }

  Future<void> _showTagPicker(BuildContext context) async {
    final l10n = L10n.of(context);
    final controller = context.read<WorkspaceController>();
    final assigned = controller.tagsFor(entry).map((tag) => tag.id).toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final tags = controller.tags;
            return AlertDialog(
              title: Text(l10n.tags),
              content: SizedBox(
                width: 320,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tag in tags)
                        CheckboxListTile(
                          value: assigned.contains(tag.id),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: _parseColor(tag.color), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Text(tag.name, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          onChanged: (value) async {
                            await controller.assignTag(entry, tag, value == true);
                            if (value == true) {
                              assigned.add(tag.id);
                            } else {
                              assigned.remove(tag.id);
                            }
                            setState(() {});
                          },
                        ),
                      if (tags.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(l10n.noTagsHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                TextButton(
                  onPressed: () async {
                    final created = await _showCreateTagDialog(context);
                    if (created != null) {
                      await controller.assignTag(entry, created, true);
                      assigned.add(created.id);
                      setState(() {});
                    }
                  },
                  child: Text(l10n.newTag),
                ),
                FilledButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.done)),
              ],
            );
          },
        );
      },
    );
  }

  Future<TagInfo?> _showCreateTagDialog(BuildContext context) async {
    final l10n = L10n.of(context);
    final controller = context.read<WorkspaceController>();
    final nameController = TextEditingController();
    const colors = ['#FF5C5C', '#FF8000', '#F5A623', '#5EBA00', '#2BCBBA', '#4B9BFF', '#A55EEA', '#868E96'];
    var color = colors[1];
    String? error;
    final result = await showDialog<TagInfo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.newTag),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.tagName, errorText: error),
                ),
                const SizedBox(height: 16),
                Text(l10n.color, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in colors)
                      InkWell(
                        onTap: () => setState(() => color = item),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _parseColor(item),
                            borderRadius: BorderRadius.circular(4),
                            border: color == item ? Border.all(color: AppColors.text, width: 2) : null,
                          ),
                          child: color == item ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setState(() => error = l10n.tagName);
                  return;
                }
                try {
                  final tag = await controller.createTag(name, color);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, tag);
                } catch (exception) {
                  setState(() => error = friendlyError(context, exception));
                }
              },
              child: Text(l10n.create),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    return result;
  }

  static Color _parseColor(String value) {
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    if (parsed == null) return AppColors.primary;
    return Color(0xFF000000 | parsed);
  }
}
