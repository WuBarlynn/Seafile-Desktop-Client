import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

Future<void> showDeletedLibrariesDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => const _DeletedLibrariesDialog(),
  );
}

class _DeletedLibrariesDialog extends StatefulWidget {
  const _DeletedLibrariesDialog();

  @override
  State<_DeletedLibrariesDialog> createState() => _DeletedLibrariesDialogState();
}

class _DeletedLibrariesDialogState extends State<_DeletedLibrariesDialog> {
  List<DeletedLibrary> _repos = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = await api.deletedLibraries();
      if (!mounted) return;
      setState(() {
        _repos = repos;
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

  Future<void> _restore(DeletedLibrary repo) async {
    final l10n = L10n.of(context);
    final session = context.read<AppSession>();
    setState(() => _busy.add(repo.id));
    try {
      await session.api!.restoreDeletedLibrary(repo.id);
      await session.refreshLibraries();
      if (!mounted) return;
      setState(() => _repos = _repos.where((item) => item.id != repo.id).toList());
      showToast(context, l10n.libraryRestored);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(repo.id));
    }
  }

  Future<void> _clean() async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.cleanAll,
      message: l10n.cleanDeletedConfirm,
      danger: true,
      confirmLabel: l10n.cleanAll,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.cleanDeletedLibraries();
      if (!mounted) return;
      setState(() => _repos = []);
      showToast(context, l10n.deletedLibrariesCleaned);
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const WebIcon('trash', size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.deletedLibraries),
          const Spacer(),
          IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 460,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  )
                : _repos.isEmpty
                    ? EmptyState(title: l10n.noDeletedLibraries, message: l10n.deletedLibrariesHint, icon: 'trash')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.deletedLibrariesHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _repos.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final repo = _repos[index];
                                final busy = _busy.contains(repo.id);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      const WebIcon('libraries', size: 20, color: AppColors.textSecondary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(repo.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 3),
                                            Text(
                                              [
                                                if (repo.deletedAt != null) formatDateTime(repo.deletedAt),
                                                if (repo.size > 0) formatBytes(repo.size),
                                              ].join(' · '),
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: busy ? null : () => _restore(repo),
                                        child: Text(l10n.restoreLibrary),
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
        if (_repos.isNotEmpty)
          TextButton(
            onPressed: _clean,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.cleanAll),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
