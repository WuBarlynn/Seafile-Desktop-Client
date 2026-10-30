import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class SdocCommentsPanel extends StatefulWidget {
  const SdocCommentsPanel({super.key, required this.repo, required this.entry, required this.onClose});

  final Repository repo;
  final Dirent entry;
  final VoidCallback onClose;

  @override
  State<SdocCommentsPanel> createState() => _SdocCommentsPanelState();
}

class _SdocCommentsPanelState extends State<SdocCommentsPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _comments = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppSession>().api!.seadocComments(widget.repo.id, widget.entry.path);
      if (!mounted) return;
      setState(() {
        _comments = (data['comments'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _send() async {
    final value = _input.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<AppSession>().api!.addSeadocComment(widget.repo.id, widget.entry.path, value);
      _input.clear();
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reply(Map<String, dynamic> comment) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final reply = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zh ? '回复评论' : 'Reply'),
        content: SizedBox(
          width: 360,
          child: TextField(controller: controller, autofocus: true, maxLines: 3, decoration: InputDecoration(labelText: l10n.zh ? '回复内容' : 'Reply')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.zh ? '发送' : 'Send')),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || reply.isEmpty) return;
    try {
      await context.read<AppSession>().api!.addSeadocCommentReply(widget.repo.id, widget.entry.path, (comment['id'] as num).toInt(), reply);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _resolve(Map<String, dynamic> comment) async {
    try {
      await context.read<AppSession>().api!.setSeadocCommentResolved(
        widget.repo.id,
        widget.entry.path,
        (comment['id'] as num).toInt(),
        !(comment['resolved'] == true),
      );
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      width: 330,
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                const WebIcon('comment', size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(l10n.zh ? '评论' : 'Comments', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconAction(icon: 'refresh', tooltip: l10n.refresh, size: 15, onPressed: _load),
                IconAction(icon: 'close', tooltip: l10n.close, size: 14, onPressed: widget.onClose),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(child: Text(l10n.zh ? '暂无评论' : 'No comments yet', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)))
                    : Scrollbar(
                        controller: _scroll,
                        child: ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) => const Divider(height: 20),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final replies = (comment['replies'] as List?)?.whereType<Map>().toList() ?? const [];
                            final resolved = comment['resolved'] == true;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('${comment['user_name'] ?? comment['user_email'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text(
                                      '${comment['created_at'] ?? ''}'.replaceFirst('T', ' ').split('+').first,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('${comment['comment'] ?? ''}', style: const TextStyle(fontSize: 13, height: 1.55)),
                                if ((comment['detail'] as String?)?.trim().isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text('${comment['detail']}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                                ],
                                for (final reply in replies)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12, top: 6),
                                    child: Text(
                                      '${reply['user_name'] ?? ''}: ${reply['reply'] ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _reply(comment),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 26)),
                                      child: Text(l10n.zh ? '回复' : 'Reply', style: const TextStyle(fontSize: 11.5)),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton(
                                      onPressed: () => _resolve(comment),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 26)),
                                      child: Text(
                                        resolved ? (l10n.zh ? '重新打开' : 'Reopen') : (l10n.zh ? '标记已解决' : 'Resolve'),
                                        style: TextStyle(fontSize: 11.5, color: resolved ? AppColors.primary : AppColors.textSecondary),
                                      ),
                                    ),
                                    if (resolved) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.check_circle, size: 13, color: AppColors.success),
                                    ],
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l10n.zh ? '写下评论…' : 'Write a comment…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 18, color: AppColors.primary),
                  tooltip: l10n.zh ? '发送' : 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
