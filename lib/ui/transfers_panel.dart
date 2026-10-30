import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/transfer_manager.dart';
import 'widgets.dart';

class TransfersPanel extends StatefulWidget {
  const TransfersPanel({super.key});

  @override
  State<TransfersPanel> createState() => _TransfersPanelState();
}

class _TransfersPanelState extends State<TransfersPanel> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final manager = context.watch<TransferManager>();
    final tasks = manager.tasks;
    if (tasks.isEmpty) return const SizedBox.shrink();
    final active = tasks.where((task) => task.isActive).length;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 370,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(
                  children: [
                    const WebIcon('download', size: 15, color: AppColors.primary),
                    const SizedBox(width: 7),
                    Text(l10n.transfers, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    if (active > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        child: Text('$active', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                    ],
                    const Spacer(),
                    IconAction(
                      icon: 'delete',
                      tooltip: l10n.clearCompleted,
                      size: 13,
                      onPressed: manager.clearFinished,
                      padding: const EdgeInsets.all(4),
                    ),
                    IconAction(
                      icon: 'arrow-down',
                      tooltip: _collapsed ? l10n.expand : l10n.collapse,
                      size: 12,
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ),
            ),
            if (!_collapsed)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _TaskRow(task: tasks[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final active = task.isActive;
    final isUpload = task.direction == TransferDirection.upload;
    final statusText = switch (task.status) {
      TransferStatus.waiting => l10n.waiting,
      TransferStatus.running => isUpload ? l10n.uploading : l10n.downloading,
      TransferStatus.done => l10n.completed,
      TransferStatus.failed => l10n.failed,
      TransferStatus.cancelled => l10n.cancelled,
    };
    final error = task.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: task.status == TransferStatus.failed ? AppColors.danger.withValues(alpha: 0.08) : AppColors.hover,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: WebIcon(
              isUpload ? 'upload-files' : 'download',
              size: 14,
              color: task.status == TransferStatus.failed ? AppColors.danger : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(task.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                    ),
                    if (active)
                      IconAction(
                        icon: 'close',
                        tooltip: l10n.cancelTask,
                        size: 12,
                        onPressed: () => context.read<TransferManager>().cancel(task),
                        padding: const EdgeInsets.all(3),
                      ),
                  ],
                ),
                Text(
                  task.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                if (active)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: task.fraction,
                      minHeight: 3,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: task.status == TransferStatus.failed ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                    if (task.total > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${formatBytes(task.done)} / ${formatBytes(task.total)}',
                        style: const TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                    if (active && task.speed > 0) ...[
                      const SizedBox(width: 6),
                      Text(formatSpeed(task.speed), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    ],
                    const Spacer(),
                    if (task.status == TransferStatus.done)
                      const WebIcon('check-circle-filled', size: 12, color: AppColors.success),
                    if (task.status == TransferStatus.failed)
                      Tooltip(
                        message: error == null ? l10n.transferLoadFailed : friendlyError(context, error),
                        child: const WebIcon('exclamation-circle', size: 12, color: AppColors.danger),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
