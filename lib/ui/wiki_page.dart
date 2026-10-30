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

  List<MapEntry<String, List<WikiInfo>>> _sections(L10n l10n) {
    final mine = _wikis.where((wiki) => !wiki.legacy && wiki.type == 'mine').toList();
    final shared = _wikis.where((wiki) => !wiki.legacy && wiki.type == 'shared').toList();
    final legacy = _wikis.where((wiki) => wiki.legacy).toList();
    final groups = <String, List<WikiInfo>>{};
    for (final wiki in _wikis.where((wiki) => !wiki.legacy && wiki.type == 'group')) {
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
                                _WikiRow(wiki: wiki, onTap: () => _open(wiki)),
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
  const _WikiRow({required this.wiki, required this.onTap});

  final WikiInfo wiki;
  final VoidCallback onTap;

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
        child: Container(
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
              const WebIcon('open-in-new-tab', size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
