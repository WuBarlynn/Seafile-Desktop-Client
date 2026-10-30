import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/transfer_manager.dart';
import '../state/workspace.dart';
import 'destination_picker.dart';
import 'widgets.dart';

export 'history_dialog.dart' show showFileHistory;
export 'share_dialog.dart' show shareEntry;

Future<void> downloadEntries(BuildContext context, WorkspaceController workspace, List<Dirent> entries) async {
  final l10n = L10n.of(context);
  final repo = workspace.repo;
  final manager = context.read<TransferManager>();
  if (repo == null || entries.isEmpty) return;
  try {
    if (entries.length == 1) {
      final entry = entries.single;
      final location = await getSaveLocation(suggestedName: entry.isDir ? '${entry.name}.zip' : entry.name);
      if (location == null || !context.mounted) return;
      if (entry.isDir) {
        await manager.enqueueFolderDownload(repo, entry, location.path);
      } else {
        await manager.enqueueDownload(repo, entry, location.path);
      }
    } else {
      final directory = await getDirectoryPath(confirmButtonText: l10n.downloadSelected);
      if (directory == null || !context.mounted) return;
      final used = <String>{};
      for (final entry in entries) {
        final fileName = entry.isDir ? '${entry.name}.zip' : entry.name;
        final path = _uniquePath(directory, sanitizeFileName(fileName), used);
        if (entry.isDir) {
          await manager.enqueueFolderDownload(repo, entry, path);
        } else {
          await manager.enqueueDownload(repo, entry, path);
        }
      }
    }
    if (context.mounted) showToast(context, l10n.addedToDownloads);
  } catch (error) {
    if (context.mounted) showToast(context, friendlyError(context, error), error: true);
  }
}

String _uniquePath(String directory, String name, Set<String> used) {
  var candidate = p.join(directory, name);
  if (!used.contains(candidate)) {
    used.add(candidate);
    return candidate;
  }
  final extension = p.extension(name);
  final base = extension.isEmpty ? name : name.substring(0, name.length - extension.length);
  var index = 2;
  while (true) {
    candidate = p.join(directory, '$base ($index)$extension');
    if (!used.contains(candidate)) {
      used.add(candidate);
      return candidate;
    }
    index++;
  }
}

Future<void> renameEntry(BuildContext context, WorkspaceController workspace, Dirent entry) async {
  final l10n = L10n.of(context);
  final name = await showTextPrompt(
    context,
    title: l10n.rename,
    label: l10n.name,
    initialValue: entry.name,
    validator: (value) => value.trim().isEmpty ? l10n.name : null,
  );
  if (name == null || !context.mounted) return;
  try {
    await workspace.renameEntry(entry, name.trim());
    if (context.mounted) showToast(context, l10n.renamed);
  } catch (error) {
    if (context.mounted) showToast(context, friendlyError(context, error), error: true);
  }
}

Future<void> deleteEntries(BuildContext context, WorkspaceController workspace, List<Dirent> entries) async {
  final l10n = L10n.of(context);
  if (entries.isEmpty) return;
  final message = entries.length == 1
      ? (entries.single.isDir ? l10n.deleteFolderConfirm(entries.single.name) : l10n.deleteEntryConfirm(entries.single.name))
      : l10n.deleteEntriesConfirm(entries.length);
  final confirmed = await showConfirmDialog(
    context,
    title: entries.length == 1 ? l10n.delete : l10n.deleteSelected,
    message: message,
    danger: true,
    confirmLabel: l10n.delete,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await workspace.deleteEntries(entries);
    if (context.mounted) showToast(context, l10n.entriesDeleted);
  } catch (error) {
    if (context.mounted) showToast(context, friendlyError(context, error), error: true);
  }
}

Future<void> toggleStar(BuildContext context, WorkspaceController workspace, Dirent entry) async {
  try {
    await workspace.toggleStar(entry);
  } catch (error) {
    if (context.mounted) showToast(context, friendlyError(context, error), error: true);
  }
}

Future<void> moveEntries(BuildContext context, WorkspaceController workspace, List<Dirent> entries) async {
  if (entries.isEmpty) return;
  final l10n = L10n.of(context);
  final moved = await showDestinationPicker(context, workspace, entries, move: true);
  if (moved && context.mounted) showToast(context, l10n.moved);
}

Future<void> copyEntries(BuildContext context, WorkspaceController workspace, List<Dirent> entries) async {
  if (entries.isEmpty) return;
  final l10n = L10n.of(context);
  final copied = await showDestinationPicker(context, workspace, entries, move: false);
  if (copied && context.mounted) showToast(context, l10n.copied);
}

Future<void> showLibraryInfo(BuildContext context, WorkspaceController workspace) async {
  final repo = workspace.repo;
  if (repo == null) return;
  final l10n = L10n.of(context);
  Repository info = repo;
  try {
    final latest = await context.read<AppSession>().api!.repoInfoV21(repo.id);
    info = latest;
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const WebIcon('info', size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.libraryInfo)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(l10n.name, info.name),
            _infoRow(l10n.owner, info.ownerDisplay),
            _infoRow(l10n.size, formatBytes(info.size)),
            _infoRow(l10n.lastModified, formatDateTime(info.mtime)),
            _infoRow(l10n.type, info.encrypted ? l10n.encryptedLibrary : (l10n.zh ? '普通资料库' : 'Regular library')),
            _infoRow(l10n.path, info.id, selectable: true),
            _infoRow(l10n.permission, info.isReadOnly ? l10n.readOnly : (l10n.zh ? '可读写' : 'Read-write')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    ),
  );
}

Widget _infoRow(String label, String value, {bool selectable = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(
          child: selectable
              ? SelectableText(value, style: const TextStyle(fontSize: 12.5))
              : Text(value, style: const TextStyle(fontSize: 12.5)),
        ),
      ],
    ),
  );
}
