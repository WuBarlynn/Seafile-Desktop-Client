import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'repo_actions.dart';
import 'widgets.dart';

Future<bool> showDestinationPicker(
  BuildContext context,
  WorkspaceController workspace,
  List<Dirent> entries, {
  required bool move,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _DestinationPickerDialog(workspace: workspace, entries: entries, move: move),
  );
  return result ?? false;
}

class _DestinationPickerDialog extends StatefulWidget {
  const _DestinationPickerDialog({required this.workspace, required this.entries, required this.move});

  final WorkspaceController workspace;
  final List<Dirent> entries;
  final bool move;

  @override
  State<_DestinationPickerDialog> createState() => _DestinationPickerDialogState();
}

class _DestinationPickerDialogState extends State<_DestinationPickerDialog> {
  late String _repoId;
  String _path = '/';
  List<Dirent> _folders = [];
  bool _loading = false;
  bool _moving = false;
  String? _error;

  WorkspaceController get workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    _repoId = workspace.repoId!;
    _load('/');
  }

  Future<void> _load(String path) async {
    final session = context.read<AppSession>();
    final api = session.api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _path = path;
    });
    try {
      final entries = await api.listDir(_repoId, path);
      if (!mounted) return;
      setState(() {
        _folders = entries.where((entry) => entry.isDir).toList()
          ..sort((a, b) => compareNatural(a.name, b.name));
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.friendly(L10n.of(context)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectRepo(String? repoId) async {
    if (repoId == null || repoId == _repoId) return;
    final session = context.read<AppSession>();
    final repo = session.findRepo(repoId);
    if (repo == null) return;
    if (!await ensureRepoUnlocked(context, repo)) return;
    if (!mounted) return;
    setState(() => _repoId = repoId);
    await _load('/');
  }

  bool get _invalidDestination {
    if (_repoId != workspace.repoId) return false;
    for (final entry in widget.entries) {
      if (!entry.isDir) continue;
      if (_path == entry.path || _path.startsWith('${entry.path}/')) return true;
    }
    return false;
  }

  Future<void> _confirm() async {
    final l10n = L10n.of(context);
    if (_invalidDestination) {
      setState(() => _error = l10n.cannotMoveIntoItself);
      return;
    }
    setState(() {
      _moving = true;
      _error = null;
    });
    try {
      if (widget.move) {
        await workspace.moveEntries(widget.entries, _repoId, _path);
      } else {
        await workspace.copyEntries(widget.entries, _repoId, _path);
      }
      if (mounted) {
        Navigator.pop(context, true);
        showToast(context, widget.move ? l10n.moved : l10n.copied);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(context, error));
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    final repos = session.repositories.where((repo) => !repo.isReadOnly).toList();
    final currentRepo = repos.where((repo) => repo.id == _repoId).firstOrNull;
    if (currentRepo == null && repos.isNotEmpty) {
      _repoId = repos.first.id;
    }
    return AlertDialog(
      title: Text(widget.move ? l10n.move : l10n.copy),
      content: SizedBox(
        width: 600,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: repos.any((repo) => repo.id == _repoId) ? _repoId : null,
              decoration: InputDecoration(labelText: l10n.destinationLibrary),
              items: [
                for (final repo in repos)
                  DropdownMenuItem(
                    value: repo.id,
                    child: Row(
                      children: [
                        RepoTypeIcon(repo: repo, size: 18),
                        const SizedBox(width: 8),
                        Text(repo.name, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
              ],
              onChanged: _moving ? null : _selectRepo,
            ),
            const SizedBox(height: 14),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
                color: AppColors.tableHeader,
              ),
              child: Row(
                children: [
                  IconAction(
                    icon: 'arrow-left',
                    tooltip: l10n.upOneLevel,
                    size: 15,
                    onPressed: _path == '/' || _loading || _moving ? null : () => _load(parentRepoPath(_path)),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${currentRepo?.name ?? ''} $_path',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _folders.isEmpty
                        ? Center(child: Text(l10n.noSubfolders, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)))
                        : ListView.builder(
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];
                              return HoverBuilder(
                                builder: (context, hovered) => InkWell(
                                  onTap: _moving ? null : () => _load(folder.path),
                                  hoverColor: Colors.transparent,
                                  child: AnimatedContainer(
                                    duration: AppMotion.hover,
                                    curve: AppMotion.curve,
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    color: hovered ? AppColors.hover : Colors.transparent,
                                    child: Row(
                                      children: [
                                        const WebIcon('folder', size: 16, color: AppColors.textSecondary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            folder.name,
                                            style: const TextStyle(fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const WebIcon('arrow-right', size: 12, color: AppColors.muted),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(onPressed: _moving ? null : () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _moving || _loading || repos.isEmpty ? null : _confirm,
          child: _moving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.move ? l10n.moveHere : l10n.copyHere),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
