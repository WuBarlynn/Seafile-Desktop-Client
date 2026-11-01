import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/models.dart';
import '../core/file_kind.dart';
import '../core/code_highlight.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'code_viewer.dart';
import 'csv_viewer.dart';
import 'file_actions.dart';
import 'inline_web_editor.dart';
import 'markdown_editor.dart';
import 'sdoc_editor.dart';
import 'web_handoff.dart';
import 'widgets.dart';

class FileStudio extends StatefulWidget {
  const FileStudio({super.key, required this.repo, required this.entry});

  final Repository repo;
  final Dirent entry;

  @override
  State<FileStudio> createState() => FileStudioState();
}

class FileStudioState extends State<FileStudio> {
  final _sdocKey = GlobalKey<SdocEditorState>();
  final _markdownKey = GlobalKey<MarkdownEditorState>();
  String? _markdownInitial;
  final _scroll = ScrollController();
  TextEditingController? _controller;
  File? _file;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String _original = '';
  int _lineCount = 1;
  bool _codeEditing = false;

  late final FileKind _kind = FileKind.of(widget.entry.name);

  bool get _readOnly => widget.entry.isReadOnly || widget.repo.isReadOnly;
  bool get isDirty {
    if (_kind == FileKind.sdoc) return _sdocKey.currentState?.isDirty ?? false;
    if (_kind == FileKind.markdown) return _markdownKey.currentState?.isDirty ?? _dirty;
    return _dirty;
  }

  @override
  void initState() {
    super.initState();
    if (_kind == FileKind.sdoc) {
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<File> _cacheFile() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'seafile-preview', widget.repo.id));
    await directory.create(recursive: true);
    final name = '${widget.entry.oid ?? widget.entry.mtime?.millisecondsSinceEpoch ?? 'file'}-${sanitizeFileName(widget.entry.name)}';
    return File(p.join(directory.path, name));
  }

  Future<void> _load() async {
    if (_kind != FileKind.text && _kind != FileKind.markdown && _kind != FileKind.image && _kind != FileKind.pdf) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await _cacheFile();
      if (!await file.exists() || await file.length() == 0) {
        final api = context.read<AppSession>().api!;
        final link = await api.fileDownloadLink(widget.repo.id, widget.entry.path);
        await api.downloadUrlToFile(link, file.path);
      }
      if (!mounted) return;
      if (_kind == FileKind.text || _kind == FileKind.markdown) {
        if (await file.length() > 20 * 1024 * 1024) {
          setState(() {
            _file = file;
            _loading = false;
            _error = L10n.of(context).fileTooLarge;
          });
          return;
        }
        final bytes = await file.readAsBytes();
        var text = utf8.decode(bytes, allowMalformed: true);
        if (text.startsWith('\uFEFF')) text = text.substring(1);
        _lineCount = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
        if (_kind == FileKind.markdown) {
          _markdownInitial = text;
        } else {
          _original = text;
          _controller = CodeEditingController(fileName: widget.entry.name, text: text);
          _controller!.addListener(_onChanged);
        }
      }
      setState(() {
        _file = file;
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

  void _onChanged() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.text;
    final dirty = value != _original;
    final lines = value.isEmpty ? 1 : '\n'.allMatches(value).length + 1;
    if (dirty != _dirty || lines != _lineCount) {
      setState(() {
        _dirty = dirty;
        _lineCount = lines;
      });
    }
  }

  Future<bool> save() async {
    if (_kind == FileKind.sdoc) return _sdocKey.currentState?.save() ?? true;
    if (_kind != FileKind.text && _kind != FileKind.markdown) return true;
    if (_readOnly || _saving || !_dirty) return true;
    final markdown = _kind == FileKind.markdown ? _markdownKey.currentState : null;
    if (_kind == FileKind.markdown && markdown == null) return true;
    if (_kind == FileKind.text && _controller == null) return true;
    final l10n = L10n.of(context);
    setState(() => _saving = true);
    try {
      final file = await _cacheFile();
      final content = markdown?.text ?? _controller!.text;
      await file.writeAsString(content, encoding: utf8, flush: true);
      await context.read<AppSession>().api!.uploadFile(
            repoId: widget.repo.id,
            dirPath: parentRepoPath(widget.entry.path),
            filePath: file.path,
            fileName: widget.entry.name,
            replace: true,
          );
      if (markdown != null) {
        markdown.markSaved();
      } else {
        _original = _controller!.text;
      }
      if (!mounted) return true;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      final workspace = context.read<WorkspaceController>();
      if (workspace.repoId == widget.repo.id) await workspace.refresh();
      if (mounted) showToast(context, l10n.savedSuccessfully);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, friendlyError(context, error), error: true);
      }
      return false;
    }
  }

  Future<bool> confirmClose() async {
    if (_kind == FileKind.sdoc) return _sdocKey.currentState?.confirmClose() ?? true;
    if (!isDirty) return true;
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
    if (action == 'cancel' || action == null) return false;
    if (action == 'discard') return true;
    return save();
  }

  void _download() => downloadEntries(context, context.read<WorkspaceController>(), [widget.entry]);

  void _openWeb() {
    final path = encodeRepoPath(widget.entry.path);
    openAuthenticatedWeb(context, '/lib/${widget.repo.id}/file$path', title: widget.entry.name);
  }

  @override
  Widget build(BuildContext context) {
    if (_kind == FileKind.sdoc) {
      return SdocEditor(key: _sdocKey, repo: widget.repo, entry: widget.entry);
    }
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    return Column(
      children: [
        _header(l10n, workspace),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _body(l10n)),
      ],
    );
  }

  Widget _header(L10n l10n, WorkspaceController workspace) {
    final editable = (_kind == FileKind.text || _kind == FileKind.markdown) && !_readOnly;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                FileTypeIcon(name: widget.entry.name, size: 22, permission: widget.entry.permission),
                const SizedBox(width: 9),
                Flexible(
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
                        const SizedBox(width: 7),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Spacer(),
                if (editable)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilledButton.icon(
                      onPressed: _saving || !isDirty ? null : save,
                      icon: _saving
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 15),
                      label: Text(l10n.save, style: const TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                IconAction(icon: 'download', tooltip: l10n.download, size: 17, onPressed: _download),
                if (workspace.repoId == widget.repo.id)
                  IconAction(icon: 'share', tooltip: l10n.share, size: 17, onPressed: () => shareEntry(context, workspace, widget.entry)),
                if (!widget.entry.isDir)
                  IconAction(icon: 'history', tooltip: l10n.history, size: 17, onPressed: () => showFileHistory(context, workspace, widget.entry)),
                IconAction(icon: 'link', tooltip: l10n.openInBrowser, size: 17, onPressed: _openWeb),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (editable && _kind == FileKind.text) _plainTools(),
        ],
      ),
    );
  }

  Widget _plainTools() {
    final l10n = L10n.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          if (!_readOnly)
            TextButton.icon(
              onPressed: () => setState(() => _codeEditing = !_codeEditing),
              icon: Icon(_codeEditing ? Icons.visibility_outlined : Icons.edit_outlined, size: 15),
              label: Text(_codeEditing ? (l10n.zh ? '预览' : 'Preview') : (l10n.zh ? '编辑' : 'Edit'), style: const TextStyle(fontSize: 12)),
            ),
          const Spacer(),
          Text(
            '${_readOnly ? l10n.readOnly : (_codeEditing ? 'Text' : 'Preview')} · ${_lineCount} ${l10n.zh ? '行' : 'lines'}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _body(L10n l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WebIcon('exclamation-circle', size: 38, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    switch (_kind) {
      case FileKind.image:
        return _imageView(l10n);
      case FileKind.pdf:
        return _pdfView();
      case FileKind.text:
      case FileKind.markdown:
        return _textView(l10n);
      case FileKind.officeDocument || FileKind.video || FileKind.audio || FileKind.other:
        return InlineWebEditor(repo: widget.repo, entry: widget.entry);
      default:
        return _unsupported(l10n);
    }
  }

  Future<String?> _pickMarkdownImage() async {
    if (_readOnly) return null;
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg']),
    ]);
    if (file == null || !mounted) return null;
    try {
      final api = context.read<AppSession>().api!;
      final dir = parentRepoPath(widget.entry.path);
      final extension = p.extension(file.path);
      final name = 'image-${DateTime.now().millisecondsSinceEpoch}$extension';
      await api.uploadFile(
        repoId: widget.repo.id,
        dirPath: dir,
        filePath: file.path,
        fileName: name,
      );
      final link = await api.fileDownloadLink(widget.repo.id, joinRepoPath(dir, name));
      return link.toString();
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
      return null;
    }
  }

  Widget _textView(L10n l10n) {
    if (_kind == FileKind.markdown) {
      final initial = _markdownInitial;
      if (initial == null) return const SizedBox.shrink();
      return MarkdownEditor(
        key: _markdownKey,
        initialText: initial,
        readOnly: _readOnly,
        onPickImage: _pickMarkdownImage,
        onChanged: (dirty) {
          if (dirty != _dirty) setState(() => _dirty = dirty);
        },
      );
    }
    final controller = _controller;
    final file = _file;
    if (controller == null || file == null) return const SizedBox.shrink();
    final isCsv = widget.entry.name.toLowerCase().endsWith('.csv');
    return Container(
      color: const Color(0xFFF4F5F7),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: _codeEditing && !_readOnly
                  ? CodeEditor(
                      controller: controller,
                      fileName: widget.entry.name,
                      onChanged: (_) => _onChanged(),
                    )
                  : isCsv
                      ? CsvTableView(text: controller.text)
                      : CodeViewer(text: controller.text, fileName: widget.entry.name, scrollController: _scroll),
            ),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: AppColors.tableHeader,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(isCsv ? 'CSV' : 'Text', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const Spacer(),
                  if (_dirty)
                    Text(
                      l10n.zh ? '未保存' : 'Unsaved',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    )
                  else
                    Text(
                      l10n.savedSuccessfully,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageView(L10n l10n) {
    final file = _file;
    if (file == null) return const SizedBox.shrink();
    final isSvg = widget.entry.name.toLowerCase().endsWith('.svg');
    return Container(
      color: const Color(0xFF1F1F1F),
      child: InteractiveViewer(
        minScale: 0.3,
        maxScale: 10,
        child: Center(
          child: isSvg
              ? SvgPicture.file(file, fit: BoxFit.contain)
              : Image.file(file, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const WebIcon('exclamation-circle', size: 40, color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _pdfView() {
    final file = _file;
    if (file == null) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFF2F3F5),
      child: PdfViewer.file(file.path, params: const PdfViewerParams(margin: 12)),
    );
  }

  Widget _unsupported(L10n l10n) {
    final label = switch (_kind) {
      FileKind.officeDocument => l10n.zh ? 'Office 文档编辑器' : 'Office editor',
      FileKind.video => l10n.zh ? '视频播放器' : 'Video player',
      FileKind.audio => l10n.zh ? '音频播放器' : 'Audio player',
      FileKind.archive => l10n.zh ? '压缩包' : 'Archive',
      _ => l10n.zh ? '网页编辑器' : 'Web editor',
    };
    return Container(
      color: const Color(0xFFF4F5F7),
      alignment: Alignment.center,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileTypeIcon(name: widget.entry.name, size: 64),
            const SizedBox(height: 18),
            Text(widget.entry.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l10n.zh ? '在应用内使用 $label 打开，不会离开当前标签页。' : 'Open with the $label inside the app without leaving this tab.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _openWeb,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(l10n.openInApp),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(l10n.download),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.hover,
            curve: AppMotion.curve,
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 17, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
