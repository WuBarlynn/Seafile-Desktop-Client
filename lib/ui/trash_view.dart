import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/workspace.dart';
import 'widgets.dart';

class TrashView extends StatelessWidget {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final selected = workspace.selectedTrashEntries;
    final items = workspace.trashItems;
    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('trash', size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(l10n.trash, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (workspace.trashLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                ),
              const Spacer(),
              if (selected.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await workspace.restoreTrashEntries(selected);
                      if (context.mounted) showToast(context, l10n.restoreDone);
                    } catch (error) {
                      if (context.mounted) showToast(context, friendlyError(context, error), error: true);
                    }
                  },
                  icon: const WebIcon('restore', size: 14),
                  label: Text(l10n.trashRestoreSelected),
                ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: workspace.clearTrashSelection,
                  child: Text(l10n.cancel),
                ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () async {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: l10n.emptyTrash,
                          message: l10n.emptyTrashConfirmShort,
                          danger: true,
                          confirmLabel: l10n.emptyTrashAction,
                        );
                        if (!confirmed || !context.mounted) return;
                        try {
                          await workspace.emptyTrash();
                          if (context.mounted) showToast(context, l10n.emptyTrashDone);
                        } catch (error) {
                          if (context.mounted) showToast(context, friendlyError(context, error), error: true);
                        }
                      },
                icon: const WebIcon('delete', size: 14),
                label: Text(l10n.trashEmptyAction),
              ),
            ],
          ),
        ),
        Expanded(
          child: workspace.trashError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(workspace.trashError!.friendly(l10n), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => workspace.loadTrash(reset: true), child: Text(l10n.retry)),
                    ],
                  ),
                )
              : workspace.trashLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? EmptyState(title: l10n.trashEmpty, message: l10n.trashHint, icon: 'trash')
                      : Column(
                          children: [
                            Container(
                              height: 40,
                              padding: const EdgeInsets.only(left: 8, right: 16),
                              decoration: const BoxDecoration(
                                color: AppColors.tableHeader,
                                border: Border(bottom: BorderSide(color: AppColors.border)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 36,
                                    child: Checkbox(
                                      value: items.every(workspace.isTrashSelected),
                                      tristate: true,
                                      onChanged: (value) => workspace.selectAllTrash(value ?? false),
                                    ),
                                  ),
                                  Expanded(child: Text(l10n.name, style: _headerStyle)),
                                  SizedBox(width: 200, child: Text(l10n.originalPath, style: _headerStyle)),
                                  SizedBox(width: 160, child: Text(l10n.deletedAt, style: _headerStyle)),
                                  SizedBox(width: 110, child: Text(l10n.size, style: _headerStyle)),
                                  const SizedBox(width: 90, child: Text('')),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final entry = items[index];
                                  return _TrashRow(
                                    entry: entry,
                                    selected: workspace.isTrashSelected(entry),
                                    onToggle: () => workspace.toggleTrashSelection(entry),
                                    onRestore: () async {
                                      try {
                                        await workspace.restoreTrashEntries([entry]);
                                        if (context.mounted) showToast(context, l10n.restoreDone);
                                      } catch (error) {
                                        if (context.mounted) showToast(context, friendlyError(context, error), error: true);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            if (workspace.trashHasMore)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: OutlinedButton(
                                  onPressed: workspace.trashLoading ? null : () => workspace.loadTrash(),
                                  child: Text(l10n.loadMore),
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);
}

class _TrashRow extends StatefulWidget {
  const _TrashRow({
    required this.entry,
    required this.selected,
    required this.onToggle,
    required this.onRestore,
  });

  final TrashEntry entry;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onRestore;

  @override
  State<_TrashRow> createState() => _TrashRowState();
}

class _TrashRowState extends State<_TrashRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entry = widget.entry;
    final path = entry.parentDir ?? parentRepoPath(entry.path ?? '/');
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 8, right: 16),
        decoration: BoxDecoration(
          color: widget.selected ? AppColors.selected : (_hovered ? const Color(0xFFF9F9F9) : Colors.white),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Checkbox(value: widget.selected, onChanged: (_) => widget.onToggle()),
            ),
            Expanded(
              child: Row(
                children: [
                  FileTypeIcon(name: entry.name, isDir: entry.isDir, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 200,
              child: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 160,
              child: Text(formatDateTime(entry.deletedAt), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 110,
              child: Text(entry.isDir ? '—' : formatBytes(entry.size), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 90,
              child: TextButton.icon(
                onPressed: widget.onRestore,
                icon: const WebIcon('restore', size: 13),
                label: Text(l10n.restore, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
