import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../core/file_kind.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'file_actions.dart';
import 'text_editor_page.dart';
import 'web_handoff.dart';
import 'widgets.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.repo, required this.entry});

  final Repository repo;
  final Dirent entry;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  File? _file;
  bool _loading = true;
  bool _downloading = false;
  double? _progress;
  String? _error;
  String? _text;
  bool _truncated = false;
  late final FileKind _kind = FileKind.of(widget.entry.name);

  @override
  void initState() {
    super.initState();
    if (_kind.isPreviewable) {
      _prepare();
    } else {
      _loading = false;
    }
  }

  Future<File> _cacheFile() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(p.join(temp.path, 'seafile-preview', widget.repo.id));
    await directory.create(recursive: true);
    final name = '${widget.entry.oid ?? widget.entry.mtime?.millisecondsSinceEpoch ?? 'file'}-${sanitizeFileName(widget.entry.name)}';
    return File(p.join(directory.path, name));
  }

  Future<void> _prepare() async {
    final l10n = L10n.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await _cacheFile();
      if (!await file.exists() || await file.length() == 0) {
        final link = await context.read<AppSession>().api!.fileDownloadLink(widget.repo.id, widget.entry.path);
        await context.read<AppSession>().api!.downloadUrlToFile(
          link,
          file.path,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = total > 0 ? done / total : null);
          },
        );
      }
      if (!mounted) return;
      if (_kind == FileKind.text || _kind == FileKind.markdown) {
        final length = await file.length();
        if (length > 20 * 1024 * 1024) {
          setState(() {
            _file = file;
            _error = l10n.fileTooLarge;
            _loading = false;
          });
          return;
        }
        final allBytes = await file.readAsBytes();
        _truncated = allBytes.length > 2 * 1024 * 1024;
        final bytes = _truncated ? allBytes.sublist(0, 2 * 1024 * 1024) : allBytes;
        _text = _decodeText(bytes);
      }
      setState(() {
        _file = file;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is Exception ? friendlyError(context, error) : error.toString();
      });
    }
  }

  String _decodeText(Uint8List bytes) {
    var content = utf8.decode(bytes, allowMalformed: true);
    if (content.startsWith('\uFEFF')) content = content.substring(1);
    return content;
  }

  Future<void> _download() async {
    final l10n = L10n.of(context);
    final location = await getSaveLocation(suggestedName: widget.entry.name);
    if (location == null || !mounted) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      final api = context.read<AppSession>().api!;
      final link = await api.fileDownloadLink(widget.repo.id, widget.entry.path);
      await api.downloadUrlToFile(
        link,
        location.path,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = total > 0 ? done / total : null);
        },
      );
      if (mounted) showToast(context, l10n.savedTo(location.path));
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final path = encodeRepoPath(widget.entry.path);
    await openAuthenticatedWeb(context, '/lib/${widget.repo.id}/file$path');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final canShare = workspace.repoId == widget.repo.id;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const WebIcon('arrow-left', size: 18),
                  tooltip: l10n.back,
                ),
                const SizedBox(width: 2),
                FileTypeIcon(name: widget.entry.name, size: 22),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if ((_kind == FileKind.text || _kind == FileKind.markdown) && !widget.repo.isReadOnly)
                  IconAction(
                    icon: 'edit',
                    tooltip: l10n.edit,
                    size: 18,
                    onPressed: () async {
                      final saved = await openTextEditor(context, widget.repo, widget.entry);
                      if (saved == true && mounted) {
                        final file = await _cacheFile();
                        if (await file.exists()) await file.delete();
                        await _prepare();
                      }
                    },
                  ),
                IconAction(icon: 'download', tooltip: l10n.download, size: 18, onPressed: _download),
                if (canShare)
                  IconAction(
                    icon: 'share',
                    tooltip: l10n.share,
                    size: 18,
                    onPressed: () => shareEntry(context, workspace, widget.entry),
                  ),
                if (!widget.entry.isDir)
                  IconAction(
                    icon: 'history',
                    tooltip: l10n.history,
                    size: 18,
                    onPressed: canShare ? () => showFileHistory(context, workspace, widget.entry) : null,
                  ),
                IconAction(icon: 'open-in-new-tab', tooltip: l10n.openInBrowser, size: 18, onPressed: _openInBrowser),
              ],
            ),
          ),
          if (_downloading)
            LinearProgressIndicator(value: _progress, minHeight: 2, backgroundColor: AppColors.primarySoft),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(L10n l10n) {
    if (_kind.isPreviewable && _loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(value: _progress, minHeight: 3, backgroundColor: AppColors.primarySoft),
            ),
            const SizedBox(height: 12),
            Text(l10n.preparingPreview, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_error != null && _kind.isPreviewable) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WebIcon('exclamation-circle', size: 38, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _prepare, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    switch (_kind) {
      case FileKind.image:
        return _buildImage();
      case FileKind.pdf:
        return _buildPdf();
      case FileKind.markdown:
        return _buildMarkdown(l10n);
      case FileKind.text:
        return _buildText(l10n);
      default:
        return _buildUnsupported(l10n);
    }
  }

  Widget _buildImage() {
    final file = _file;
    if (file == null) return const SizedBox.shrink();
    final isSvg = widget.entry.name.toLowerCase().endsWith('.svg');
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Center(
        child: InteractiveViewer(
          minScale: 0.4,
          maxScale: 8,
          child: isSvg
              ? SvgPicture.file(file, fit: BoxFit.contain)
              : Image.file(file, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const WebIcon('exclamation-circle', size: 40, color: Colors.white54)),
        ),
      ),
    );
  }

  Widget _buildPdf() {
    final file = _file;
    if (file == null) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFF2F3F5),
      child: PdfViewer.file(
        file.path,
        params: const PdfViewerParams(
          margin: 12,
        ),
      ),
    );
  }

  Widget _buildText(L10n l10n) {
    return Column(
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: const Color(0xFFFEFBDC),
            child: Text(l10n.textPreviewTruncated, style: const TextStyle(fontSize: 12)),
          ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                _text ?? '',
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12.5, height: 1.65),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdown(L10n l10n) {
    return Column(
      children: [
        if (_truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: const Color(0xFFFEFBDC),
            child: Text(l10n.textPreviewTruncated, style: const TextStyle(fontSize: 12)),
          ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: MarkdownBody(
                    data: _text ?? '',
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 14, height: 1.75),
                      h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                      h2: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                      h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      code: const TextStyle(fontFamily: 'Menlo', fontSize: 12.5, backgroundColor: AppColors.hover),
                      codeblockDecoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(4)),
                      blockquoteDecoration: BoxDecoration(border: const Border(left: BorderSide(color: AppColors.primary, width: 3))),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupported(L10n l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FileTypeIcon(name: widget.entry.name, size: 72),
          const SizedBox(height: 20),
          Text(l10n.previewUnsupported, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _downloading ? null : _download,
                icon: const WebIcon('download', size: 14, color: Colors.white),
                label: Text(l10n.download),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openInBrowser,
                icon: const WebIcon('open-in-new-tab', size: 14),
                label: Text(l10n.openInBrowser),
              ),
            ],
          ),
          if (_downloading) ...[
            const SizedBox(height: 18),
            SizedBox(width: 240, child: LinearProgressIndicator(value: _progress, minHeight: 3)),
          ],
        ],
      ),
    );
  }
}
