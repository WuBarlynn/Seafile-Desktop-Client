import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'web_handoff.dart';
import 'widgets.dart';

class WikiPage extends StatefulWidget {
  const WikiPage({super.key, this.onOpenWeb});

  final void Function(String path, String title)? onOpenWeb;

  @override
  State<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends State<WikiPage> {
  List<WikiInfo> _wikis = [];
  final _query = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

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
      final wikis = await api.wikis();
      if (!mounted) return;
      setState(() {
        _wikis = wikis;
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

  Future<void> _open(WikiInfo wiki) async {
    final path = wiki.legacy
        ? '/published/${Uri.encodeComponent(wiki.slug ?? '')}'
        : '/wikis/${Uri.encodeComponent(wiki.id)}/';
    final open = widget.onOpenWeb;
    if (open != null) {
      open(path, wiki.name);
    } else {
      await openAuthenticatedWeb(context, path, title: wiki.name);
    }
  }

  Future<void> _createWiki() async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.zh ? '添加知识库' : 'New wiki',
      label: l10n.name,
      validator: (value) => value.trim().isEmpty ? l10n.name : null,
    );
    if (name == null || !mounted) return;
    try {
      final created = await context.read<AppSession>().api!.createWiki(name: name.trim());
      await _load();
      if (!mounted) return;
      final id = '${created['id'] ?? ''}';
      final path = id.isEmpty ? '/published/' : '/wikis/$id/';
      final open = widget.onOpenWeb;
      if (open != null) {
        open(path, name.trim());
      } else {
        await openAuthenticatedWeb(context, path, title: name.trim());
      }
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _renameWiki(WikiInfo wiki) async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.zh ? '重命名知识库' : 'Rename wiki',
      label: l10n.name,
      initialValue: wiki.name,
      validator: (value) => value.trim().isEmpty ? l10n.name : null,
    );
    if (name == null || !mounted) return;
    try {
      await context.read<AppSession>().api!.updateWiki2(wiki.id, name: name.trim(), icon: wiki.icon ?? 'book-bookmark-fill', color: wiki.color ?? '#FF8000');
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _deleteWiki(WikiInfo wiki) async {
    final l10n = L10n.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.zh ? '删除知识库' : 'Delete wiki',
      message: l10n.zh ? '确定删除 ${wiki.name}？' : 'Delete ${wiki.name}?',
      danger: true,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<AppSession>().api!.deleteWiki2(wiki.id);
      await _load();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  List<MapEntry<String, List<WikiInfo>>> _sections(L10n l10n) {
    final query = _query.text.trim().toLowerCase();
    final source = query.isEmpty ? _wikis : _wikis.where((wiki) => wiki.name.toLowerCase().contains(query)).toList();
    final mine = source.where((wiki) => !wiki.legacy && wiki.type == 'mine').toList();
    final shared = source.where((wiki) => !wiki.legacy && wiki.type == 'shared').toList();
    final legacy = source.where((wiki) => wiki.legacy).toList();
    final groups = <String, List<WikiInfo>>{};
    for (final wiki in source.where((wiki) => !wiki.legacy && wiki.type == 'group')) {
      groups.putIfAbsent(wiki.groupName?.isNotEmpty == true ? wiki.groupName! : l10n.groupLibraries, () => []).add(wiki);
    }
    final sections = <MapEntry<String, List<WikiInfo>>>[];
    if (mine.isNotEmpty) sections.add(MapEntry(l10n.myWikis, mine));
    if (shared.isNotEmpty) sections.add(MapEntry(l10n.sharedWikis, shared));
    for (final entry in groups.entries) {
      sections.add(MapEntry(entry.key, entry.value));
    }
    if (legacy.isNotEmpty) sections.add(MapEntry(l10n.legacyWikis, legacy));
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final sections = _sections(l10n);
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('wiki', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.wikis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const Spacer(),
              SizedBox(
                width: 220,
                height: 32,
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: l10n.zh ? '搜索知识库' : 'Search wikis',
                    prefixIcon: const Padding(padding: EdgeInsets.all(8), child: WebIcon('search', size: 14)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _createWiki,
                icon: const Icon(Icons.add, size: 15),
                label: Text(l10n.zh ? '添加知识库' : 'New wiki', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
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
                  : _wikis.isEmpty
                      ? EmptyState(title: l10n.noWikis, message: l10n.wikisHint, icon: 'wiki')
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                          children: [
                            for (final section in sections) ...[
                              Text(section.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 10),
                              for (final wiki in section.value)
                                _WikiRow(
                                  wiki: wiki,
                                  onTap: () => _open(wiki),
                                  onRename: wiki.legacy ? null : () => _renameWiki(wiki),
                                  onDelete: wiki.legacy ? null : () => _deleteWiki(wiki),
                                ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }
}

class _WikiRow extends StatefulWidget {
  const _WikiRow({required this.wiki, required this.onTap, this.onRename, this.onDelete});

  final WikiInfo wiki;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  State<_WikiRow> createState() => _WikiRowState();
}

class _WikiRowState extends State<_WikiRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final wiki = widget.wiki;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          height: 56,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hover : Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: const WebIcon('wiki', size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(wiki.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: AppColors.text)),
                        ),
                        if (wiki.isPublished) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                            child: Text(l10n.published, style: const TextStyle(fontSize: 10, color: AppColors.success)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (wiki.ownerNickname?.isNotEmpty == true) wiki.ownerNickname!,
                        if (wiki.updatedAt != null) '${l10n.updatedAt} ${formatRelative(wiki.updatedAt, zh: l10n.zh)}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (widget.onRename != null || widget.onDelete != null)
                PopupMenuButton<String>(
                  tooltip: '',
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                  itemBuilder: (context) => [
                    if (widget.onRename != null)
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.zh ? '重命名' : 'Rename', style: const TextStyle(fontSize: 13)),
                      ),
                    if (widget.onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.delete, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') widget.onRename?.call();
                    if (value == 'delete') widget.onDelete?.call();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: WebIcon('more-vertical', size: 15),
                  ),
                )
              else
                const WebIcon('open-in-new-tab', size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
