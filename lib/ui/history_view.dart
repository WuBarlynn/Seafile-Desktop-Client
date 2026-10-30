import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/workspace.dart';
import 'widgets.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final repo = workspace.repo;
    final commits = workspace.commits;
    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('history', size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(l10n.history, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (workspace.historyLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                ),
              const Spacer(),
              if (repo != null && repo.isOwner)
                Text(
                  l10n.zh ? '资料库历史记录' : 'Library history',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: workspace.historyError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(workspace.historyError!.friendly(l10n), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: () => workspace.loadHistory(reset: true), child: Text(l10n.retry)),
                    ],
                  ),
                )
              : workspace.historyLoading && commits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : commits.isEmpty
                      ? EmptyState(title: l10n.noHistory, message: l10n.historyLoadFailed, icon: 'history')
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: commits.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final commit = commits[index];
                                  return _CommitRow(
                                    commit: commit,
                                    canRevert: repo?.isOwner == true && index != 0,
                                    onRevert: () async {
                                      final confirmed = await showConfirmDialog(
                                        context,
                                        title: l10n.revert,
                                        message: l10n.revertRepoConfirm,
                                        danger: true,
                                        confirmLabel: l10n.revert,
                                      );
                                      if (!confirmed || !context.mounted) return;
                                      try {
                                        await workspace.revertToCommit(commit);
                                        if (context.mounted) showToast(context, l10n.reverted);
                                      } catch (error) {
                                        if (context.mounted) showToast(context, friendlyError(context, error), error: true);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            if (workspace.historyHasMore)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: OutlinedButton(
                                  onPressed: workspace.historyLoading ? null : () => workspace.loadHistory(),
                                  child: Text(l10n.loadMore),
                                ),
                              ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow({required this.commit, required this.canRevert, required this.onRevert});

  final RepoCommit commit;
  final bool canRevert;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.center,
            child: const WebIcon('history', size: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (commit.description?.isNotEmpty == true) ? commit.description! : l10n.unknownError,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (commit.authorName?.isNotEmpty == true) commit.authorName!,
                    formatDateTime(commit.time),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (canRevert)
            TextButton(
              onPressed: onRevert,
              child: Text(l10n.revert, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
