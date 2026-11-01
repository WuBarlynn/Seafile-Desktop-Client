import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'repo_actions.dart';
import 'widgets.dart';

class StarredPage extends StatefulWidget {
  const StarredPage({super.key, required this.onOpenLibrary, required this.onOpenFile});

  final void Function(Repository repo, String path) onOpenLibrary;
  final void Function(Repository repo, String path) onOpenFile;

  @override
  State<StarredPage> createState() => _StarredPageState();
}

class _StarredPageState extends State<StarredPage> {
  List<StarredItem> _items = [];
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
      final items = await api.starredItems();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _open(StarredItem item) async {
    final session = context.read<AppSession>();
    final repo = session.findRepo(item.repoId);
    if (repo == null) return;
    if (!await ensureRepoUnlocked(context, repo) || !mounted) return;
    if (item.isDir) {
      widget.onOpenLibrary(repo, item.path);
    } else {
      widget.onOpenFile(repo, item.path);
    }
  }

  Future<void> _unstar(StarredItem item) async {
    try {
      await context.read<AppSession>().api!.setStarred(repoId: item.repoId, path: item.path, starred: false);
      if (!mounted) return;
      setState(() => _items = _items.where((entry) => !(entry.repoId == item.repoId && entry.path == item.path)).toList());
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              const WebIcon('favorites', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.favorites, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                  : _items.isEmpty
                      ? EmptyState(title: l10n.starredEmpty, message: l10n.starredHint, icon: 'starred')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return HoverBuilder(
                              builder: (context, hovered) => InkWell(
                                onTap: () => _open(item),
                                hoverColor: Colors.transparent,
                                mouseCursor: SystemMouseCursors.click,
                                child: AnimatedContainer(
                                  duration: AppMotion.hover,
                                  curve: AppMotion.curve,
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  color: hovered ? AppColors.hover : Colors.transparent,
                                  child: Row(
                                    children: [
                                      FileTypeIcon(name: item.name, isDir: item.isDir, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.primary)),
                                            const SizedBox(height: 2),
                                            Text('${item.repoName} · ${item.path}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(formatRelative(item.mtime, zh: l10n.zh), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _unstar(item),
                                        icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.warning),
                                        tooltip: l10n.zh ? '取消星标' : 'Remove star',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
