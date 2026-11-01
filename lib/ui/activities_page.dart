import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'repo_actions.dart';
import 'widgets.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key, required this.onOpenLibrary, required this.onOpenFile});

  final void Function(Repository repo, String path) onOpenLibrary;
  final void Function(Repository repo, String path) onOpenFile;

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final List<ActivityEvent> _events = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _mine = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _events.clear();
      _loading = true;
      _error = null;
      setState(() {});
    } else {
      _loadingMore = true;
      setState(() {});
    }
    try {
      final events = await api.activities(page: _page, opUser: _mine ? context.read<AppSession>().username : null);
      if (!mounted) return;
      setState(() {
        _events.addAll(events);
        _hasMore = events.length >= 25;
        _page++;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = friendlyError(context, error);
      });
    }
  }

  Future<void> _open(ActivityEvent event) async {
    final session = context.read<AppSession>();
    final repo = session.findRepo(event.repoId);
    if (repo == null) return;
    if (!await ensureRepoUnlocked(context, repo) || !mounted) return;
    if (event.isDir) {
      widget.onOpenLibrary(repo, event.path);
    } else {
      widget.onOpenFile(repo, event.path);
    }
  }

  String _actionText(L10n l10n, ActivityEvent event) {
    final verb = switch (event.opType) {
      'create' => l10n.activityCreate,
      'edit' || 'modify' => l10n.activityEdit,
      'delete' => l10n.activityDelete,
      'recover' || 'restore' => l10n.activityRecover,
      'rename' => l10n.activityRename,
      'move' => l10n.activityMove,
      'copy' => l10n.activityCopy,
      _ => l10n.activityOther,
    };
    final count = event.count > 1 ? (l10n.zh ? '等 ${event.count} 个文件' : ' and ${event.count - 1} more') : '';
    return '$verb ${event.name}$count';
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
              const WebIcon('activities', size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(l10n.activities, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 18),
              for (final entry in [(false, l10n.zh ? '所有活动' : 'All activities'), (true, l10n.zh ? '我的活动' : 'My activities')])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      if (_mine == entry.$1) return;
                      setState(() => _mine = entry.$1);
                      _load(reset: true);
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mine == entry.$1 ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        entry.$2,
                        style: TextStyle(fontSize: 12.5, color: _mine == entry.$1 ? AppColors.primaryDark : AppColors.textSecondary, fontWeight: _mine == entry.$1 ? FontWeight.w500 : FontWeight.w400),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              IconAction(icon: 'refresh', tooltip: l10n.refresh, onPressed: () => _load(reset: true)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: () => _load(reset: true), child: Text(l10n.retry)),
                        ],
                      ),
                    )
                  : _events.isEmpty
                      ? EmptyState(title: l10n.activitiesEmpty, message: l10n.activitiesHint, icon: 'activities')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _events.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _events.length) {
                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Center(
                                  child: _loadingMore
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : OutlinedButton(onPressed: () => _load(), child: Text(l10n.loadMore)),
                                ),
                              );
                            }
                            final event = _events[index];
                            return HoverBuilder(
                              builder: (context, hovered) => InkWell(
                                onTap: () => _open(event),
                                hoverColor: Colors.transparent,
                                mouseCursor: SystemMouseCursors.click,
                                child: AnimatedContainer(
                                  duration: AppMotion.hover,
                                  curve: AppMotion.curve,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                  color: hovered ? AppColors.hover : Colors.transparent,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AvatarCircle(name: event.authorName ?? session_name(context), size: 32),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(text: '${event.authorName ?? ''} ', style: const TextStyle(fontWeight: FontWeight.w500)),
                                                  TextSpan(text: _actionText(l10n, event)),
                                                  TextSpan(text: ' · ${event.repoName}', style: const TextStyle(color: AppColors.textSecondary)),
                                                ],
                                              ),
                                              style: const TextStyle(fontSize: 13.5, height: 1.5),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${event.repoName} · ${event.path}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(formatRelative(event.time, zh: l10n.zh), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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

  String session_name(BuildContext context) => context.read<AppSession>().displayName;
}
