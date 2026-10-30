import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class ShareAdminPage extends StatefulWidget {
  const ShareAdminPage({super.key});

  @override
  State<ShareAdminPage> createState() => _ShareAdminPageState();
}

class _ShareAdminPageState extends State<ShareAdminPage> {
  List<ShareLink> _links = [];
  bool _loading = true;
  String? _error;

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
      final links = await api.shareLinks(perPage: 200);
      if (!mounted) return;
      setState(() {
        _links = links;
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

  Future<void> _copy(ShareLink link) async {
    final session = context.read<AppSession>();
    final l10n = L10n.of(context);
    await Clipboard.setData(ClipboardData(text: link.linkForServer(session.serverBase)));
    if (mounted) showToast(context, l10n.linkCopied);
  }

  Future<void> _delete(ShareLink link) async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteLink,
      message: l10n.deleteLinkConfirm,
      danger: true,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.deleteShareLink(link.token);
      if (!mounted) return;
      setState(() => _links = _links.where((item) => item.token != link.token).toList());
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final session = context.watch<AppSession>();
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('share-admin', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.shareAdmin, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: _load),
            ],
          ),
        ),
        Expanded(
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
                  : _links.isEmpty
                      ? EmptyState(title: l10n.shareAdminEmpty, message: l10n.shareAdminHint, icon: 'share-admin')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _links.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            final title = link.objName ?? baseName(link.path ?? '/');
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                                    alignment: Alignment.center,
                                    child: const WebIcon('links', size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: AppColors.text)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${link.repoName?.isNotEmpty == true ? '${link.repoName} · ' : ''}${link.path ?? '/'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 3),
                                        SelectableText(
                                          link.linkForServer(session.serverBase),
                                          maxLines: 1,
                                          style: const TextStyle(fontSize: 11, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        link.expireDate == null ? l10n.expireNever : formatDateTime(link.expireDate, withTime: false),
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                      ),
                                      if (link.hasPassword)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const WebIcon('lock', size: 10, color: AppColors.muted),
                                              const SizedBox(width: 3),
                                              Text(l10n.passwordProtected, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  IconAction(icon: 'copy', tooltip: l10n.copyLink, size: 15, onPressed: () => _copy(link)),
                                  IconAction(icon: 'delete', tooltip: l10n.deleteLink, size: 15, color: AppColors.danger, onPressed: () => _delete(link)),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
