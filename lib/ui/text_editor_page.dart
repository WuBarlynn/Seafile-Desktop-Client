import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/code_highlight.dart';
import '../core/file_kind.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'code_viewer.dart';
import 'widgets.dart';

Future<bool?> openTextEditor(BuildContext context, Repository repo, Dirent entry) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (context) => TextEditorPage(repo: repo, entry: entry)),
  );
}

class TextEditorPage extends StatefulWidget {
  const TextEditorPage({super.key, required this.repo, required this.entry});

  final Repository repo;
  final Dirent entry;

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final bool _isMarkdown = FileKind.of(widget.entry.name) == FileKind.markdown;
  bool _loading = true;
  bool _saving = false;
  bool _preview = false;
  bool _dirty = false;
  bool _saved = false;
  String? _error;
  int _lineCount = 1;
  String _original = '';

  @override
  void initState() {
    super.initState();
    _controller = _isMarkdown
        ? TextEditingController()
        : CodeEditingController(fileName: widget.entry.name);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<File> _tempFile() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'seafile-edit'));
    await dir.create(recursive: true);
    final safe = sanitizeFileName(widget.entry.name);
    return File(p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}-$safe'));
  }

  Future<void> _load() async {
    final api = context.read<AppSession>().api;
    if (api == null) return;
    try {
      final file = await _tempFile();
      final link = await api.fileDownloadLink(widget.repo.id, widget.entry.path);
      await api.downloadUrlToFile(link, file.path);
      final length = await file.length();
      if (length > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = L10n.of(context).fileTooLargeToEdit;
          });
        }
        return;
      }
      final bytes = await file.readAsBytes();
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      if (!mounted) return;
      _controller.text = text;
      _original = text;
      _controller.addListener(_syncCounts);
      _syncCounts();
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  void _syncCounts() {
    final value = _controller.text;
    final lines = value.isEmpty ? 1 : '\n'.allMatches(value).length + 1;
    final dirty = value != _original;
    if (lines != _lineCount || dirty != _dirty) {
      setState(() {
        _lineCount = lines;
        _dirty = dirty;
      });
    }
  }

  Future<bool> _save({bool popOnSuccess = false}) async {
    if (_saving) return false;
    final l10n = L10n.of(context);
    final api = context.read<AppSession>().api;
    if (api == null) return false;
    setState(() => _saving = true);
    try {
      final file = await _tempFile();
      await file.writeAsString(_controller.text, encoding: utf8, flush: true);
      await api.uploadFile(
        repoId: widget.repo.id,
        dirPath: parentRepoPath(widget.entry.path),
        filePath: file.path,
        fileName: widget.entry.name,
        replace: true,
      );
      try {
        await file.delete();
      } catch (_) {}
      if (!mounted) return true;
      setState(() {
        _saving = false;
        _dirty = false;
        _saved = true;
        _original = _controller.text;
      });
      final workspace = context.read<WorkspaceController>();
      if (workspace.repoId == widget.repo.id) {
        await workspace.refresh();
      }
      if (mounted) showToast(context, l10n.savedSuccessfully);
      if (popOnSuccess && mounted) Navigator.pop(context, true);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, friendlyError(context, error), error: true);
      }
      return false;
    }
  }

  Future<void> _handleBack() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.pop(context, _saved);
      return;
    }
    final l10n = L10n.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChanges),
        content: Text(l10n.editorHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: Text(l10n.keepEditing)),
          TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: Text(l10n.discardChanges, style: const TextStyle(color: AppColors.danger))),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: Text(l10n.save)),
        ],
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'discard') {
      Navigator.pop(context, _saved);
      return;
    }
    await _save(popOnSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () => _save(),
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _save(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                _buildHeader(context, l10n),
                if (_saving) const LinearProgressIndicator(minHeight: 2),
                Expanded(child: _buildBody(l10n)),
                _buildFooter(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, L10n l10n) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,
            icon: const WebIcon('arrow-left', size: 18),
            tooltip: l10n.back,
          ),
          FileTypeIcon(name: widget.entry.name, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if (_dirty) ...[
                  const SizedBox(width: 8),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
          if (_isMarkdown) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.editMode, style: const TextStyle(fontSize: 12))),
                ButtonSegment(value: true, label: Text(l10n.previewMode, style: const TextStyle(fontSize: 12))),
              ],
              selected: {_preview},
              onSelectionChanged: (selection) => setState(() => _preview = selection.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton.icon(
            onPressed: _loading || _error != null || _saving ? null : () => _save(),
            icon: _saving
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const WebIcon('save', size: 14, color: Colors.white),
            label: Text(l10n.save),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WebIcon('exclamation-circle', size: 38, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_preview) {
      return Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: MarkdownBody(
                data: _controller.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14, height: 1.75),
                  h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  h2: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                  h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  code: const TextStyle(fontFamily: 'Menlo', fontSize: 12.5, backgroundColor: AppColors.hover),
                  codeblockDecoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _isMarkdown
              ? Scrollbar(
                  controller: _scrollController,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.65),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(24, 18, 24, 24),
                    ),
                    onChanged: (_) => _syncCounts(),
                  ),
                )
              : CodeEditor(
                  controller: _controller,
                  fileName: widget.entry.name,
                  focusNode: _focusNode,
                  onChanged: (_) => _syncCounts(),
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.tableHeader,
          child: Text(
            '${l10n.linesCount(_lineCount)} · ${l10n.charsCount(_controller.text.length)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(L10n l10n) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Text(
            _isMarkdown ? 'Markdown' : 'Text',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const Spacer(),
          if (_saved && !_dirty)
            Row(
              children: [
                const WebIcon('check', size: 11, color: AppColors.success),
                const SizedBox(width: 4),
                Text(l10n.savedSuccessfully, style: const TextStyle(fontSize: 11, color: AppColors.success)),
              ],
            ),
        ],
      ),
    );
  }
}
