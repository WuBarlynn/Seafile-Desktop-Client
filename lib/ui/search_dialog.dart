import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'widgets.dart';

Future<SearchResult?> showGlobalSearchDialog(BuildContext context, WorkspaceController workspace) async {
  return showDialog<SearchResult>(
    context: context,
    builder: (context) => _SearchDialog(workspace: workspace),
  );
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.workspace});

  final WorkspaceController workspace;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;
  String? _notice;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _notice = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final results = await api.globalSearch(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on ApiException catch (error) {
      final repo = widget.workspace.repo;
      if (repo != null) {
        try {
          final local = await api.searchInRepo(repo.id, query);
          if (!mounted || requestId != _requestId) return;
          setState(() {
            _results = local
                .map((item) => SearchResult(
                      repoId: repo.id,
                      repoName: repo.name,
                      path: item.path,
                      name: item.name,
                      isDir: item.isDir,
                      size: item.size,
                      mtime: item.mtime,
                    ))
                .toList();
            _notice = L10n.of(context).searchInLibrary;
            _loading = false;
            _error = null;
          });
          return;
        } catch (_) {}
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.kind == ApiErrorKind.forbidden || error.status == 404
            ? L10n.of(context).searchFailed
            : error.friendly(L10n.of(context));
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  const WebIcon('search', size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      decoration: InputDecoration(
                        hintText: l10n.searchPlaceholder,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: _onChanged,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) _search(value.trim());
                      },
                    ),
                  ),
                  if (_loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.8)),
                  const SizedBox(width: 6),
                  IconAction(icon: 'close', tooltip: l10n.close, size: 15, onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const WebIcon('search', size: 40, color: AppColors.muted),
                              const SizedBox(height: 12),
                              Text(
                                _controller.text.isEmpty ? l10n.searchHint : l10n.searchNoResults,
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_notice != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Text(_notice!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                              ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final result = _results[index];
                                  return _SearchResultRow(
                                    result: result,
                                    onTap: () => Navigator.pop(context, result),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Text(
                    l10n.zh ? '搜索所有资料库中的文件' : 'Search all libraries',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const Spacer(),
                  if (_results.isNotEmpty)
                    Text(l10n.searchResults(_results.length), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatefulWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  State<_SearchResultRow> createState() => _SearchResultRowState();
}

class _SearchResultRowState extends State<_SearchResultRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        child: AnimatedContainer(
          duration: AppMotion.hover,
          curve: AppMotion.curve,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _hovered ? AppColors.hover : Colors.transparent,
          child: Row(
            children: [
              FileTypeIcon(name: result.name, isDir: result.isDir, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${result.repoName.isNotEmpty ? '${result.repoName} · ' : ''}${result.path}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const WebIcon('arrow-right', size: 12, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
