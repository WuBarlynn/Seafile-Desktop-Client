import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'file_actions.dart';
import 'widgets.dart';

class SdocEditor extends StatefulWidget {
  const SdocEditor({super.key, required this.repo, required this.entry});

  final Repository repo;
  final Dirent entry;

  @override
  State<SdocEditor> createState() => SdocEditorState();
}

class _SdocBlock {
  _SdocBlock(this.element);

  final Map<String, dynamic> element;
  TextEditingController? text;
  List<TextEditingController> children = const [];
  List<Map<String, dynamic>> childElements = const [];
  bool deleted = false;

  String get type => element['type'] as String? ?? 'paragraph';
}

class SdocEditorState extends State<SdocEditor> {
  final _scroll = ScrollController();
  final List<_SdocBlock> _blocks = [];
  Map<String, dynamic>? _document;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  int? _active;
  int _idSeed = 0;

  bool get isDirty => _dirty;
  bool get _readOnly => widget.entry.isReadOnly || widget.repo.isReadOnly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.text?.dispose();
      for (final controller in block.children) {
        controller.dispose();
      }
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final document = await context.read<AppSession>().api!.loadSdocDocument(widget.repo.id, widget.entry.path);
      if (!mounted) return;
      _document = document;
      _buildBlocks(document);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(context, error);
      });
    }
  }

  void _buildBlocks(Map<String, dynamic> document) {
    for (final block in _blocks) {
      block.text?.dispose();
      for (final controller in block.children) {
        controller.dispose();
      }
    }
    _blocks.clear();
    final elements = (document['elements'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
    for (final element in elements) {
      final block = _SdocBlock(element);
      final type = block.type;
      if (type == 'unordered_list' || type == 'ordered_list') {
        final children = (element['children'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
        block.childElements = children;
        block.children = [
          for (final child in children) TextEditingController(text: _textOf(child)),
        ];
        for (final controller in block.children) {
          controller.addListener(_markDirty);
        }
      } else if (type == 'callout') {
        final children = (element['children'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
        block.childElements = children;
        block.children = [
          for (final child in children) TextEditingController(text: _textOf(child)),
        ];
        for (final controller in block.children) {
          controller.addListener(_markDirty);
        }
      } else if (_isSimpleEditable(type)) {
        block.text = TextEditingController(text: _textOf(element));
        block.text!.addListener(_markDirty);
      }
      _blocks.add(block);
    }
    if (_blocks.isEmpty && !_readOnly) {
      _blocks.add(_SdocBlock(_paragraphElement('')));
      _bindBlock(_blocks.length - 1);
    }
    _active = _blocks.isEmpty ? null : 0;
  }

  void _bindBlock(int index) {
    final block = _blocks[index];
    if (block.text != null) {
      block.text!.addListener(_markDirty);
    }
  }

  bool _isSimpleEditable(String type) {
    return type == 'title' ||
        type == 'paragraph' ||
        type == 'quote' ||
        type == 'check_list_item' ||
        type == 'code_block' ||
        type.startsWith('header') ||
        type.startsWith('toggle_header');
  }

  String _textOf(dynamic node) {
    final buffer = StringBuffer();
    void visit(dynamic value) {
      if (value is Map) {
        final text = value['text'];
        if (text is String) buffer.write(text);
        final children = value['children'];
        if (children is List) {
          for (final child in children) {
            visit(child);
          }
        }
      } else if (value is List) {
        for (final child in value) {
          visit(child);
        }
      }
    }

    if (node is Map && node['type'] == 'code_block') {
      final lines = (node['children'] as List?) ?? const [];
      return lines.map((line) => _plainNode(line)).join('\n');
    }
    visit(node is Map ? node['children'] : node);
    return buffer.toString();
  }

  String _plainNode(dynamic node) {
    if (node is Map) {
      if (node['text'] is String) return node['text'] as String;
      final children = node['children'];
      if (children is List) return children.map(_plainNode).join();
    }
    return '';
  }

  Map<String, dynamic> _paragraphElement(String text) {
    final id = 'p-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    return {
      'id': id,
      'type': 'paragraph',
      'children': [
        {'id': '$id-t', 'text': text},
      ],
    };
  }

  String _textLeafId(Map<String, dynamic> element) {
    dynamic found;
    void visit(dynamic node) {
      if (found != null) return;
      if (node is Map) {
        if (node['text'] is String) {
          found = node['id'] as String?;
          return;
        }
        for (final child in (node['children'] as List?) ?? const []) {
          visit(child);
        }
      }
    }

    visit(element);
    return found as String? ?? '${element['id']}-t';
  }

  void _setNodeText(Map<String, dynamic> element, String value) {
    var replaced = false;
    void visit(dynamic node) {
      if (replaced || node is! Map) return;
      if (node['text'] is String) {
        node['text'] = value;
        replaced = true;
        return;
      }
      for (final child in (node['children'] as List?) ?? const []) {
        visit(child);
      }
    }

    visit(element);
    if (!replaced) {
      element['children'] = [
        {'id': _textLeafId(element), 'text': value},
      ];
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _setActive(int index) {
    if (_active != index) setState(() => _active = index);
  }

  Future<bool> save() async {
    if (_readOnly || _saving || !_dirty || _document == null) return true;
    final l10n = L10n.of(context);
    setState(() => _saving = true);
    try {
      final elements = <Map<String, dynamic>>[];
      for (final block in _blocks) {
        if (block.deleted) continue;
        final type = block.type;
        if (type == 'unordered_list' || type == 'ordered_list') {
          for (var i = 0; i < block.childElements.length; i++) {
            _setNodeText(block.childElements[i], block.children[i].text);
          }
          elements.add(block.element);
        } else if (type == 'callout') {
          for (var i = 0; i < block.childElements.length; i++) {
            _setNodeText(block.childElements[i], block.children[i].text);
          }
          elements.add(block.element);
        } else if (type == 'code_block') {
          final lines = (block.text?.text ?? '').split('\n');
          final existing = (block.element['children'] as List?)?.whereType<Map>().toList() ?? [];
          block.element['children'] = [
            for (var i = 0; i < lines.length; i++)
              {
                'id': i < existing.length ? (existing[i]['id'] as String? ?? '${block.element['id']}-$i') : '${block.element['id']}-$i',
                'type': 'code_line',
                'children': [
                  {'id': '${block.element['id']}-$i-t', 'text': lines[i]},
                ],
              },
          ];
          elements.add(block.element);
        } else if (_isSimpleEditable(type) && block.text != null) {
          _setNodeText(block.element, block.text!.text);
          elements.add(block.element);
        } else {
          elements.add(block.element);
        }
      }
      final version = _document!['version'];
      _document!['elements'] = elements;
      _document!['version'] = version is int ? version + 1 : 1;
      _document!['format_version'] = _document!['format_version'] ?? 4;
      await context.read<AppSession>().api!.saveSdocDocument(widget.repo.id, widget.entry.path, _document!);
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
    if (!_dirty) return true;
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

  void _changeType(String type) {
    final index = _active;
    if (index == null || index >= _blocks.length || _readOnly) return;
    final block = _blocks[index];
    final controller = block.text ?? (block.children.isNotEmpty ? block.children.first : null);
    final text = controller?.text ?? _textOf(block.element);
    final previous = block.type;
    final wasList = previous == 'unordered_list' || previous == 'ordered_list';
    final wasCode = previous == 'code_block';
    final wasCallout = previous == 'callout';

    if (type == 'unordered_list' || type == 'ordered_list') {
      if (wasList) {
        block.element['type'] = type;
      } else {
        final id = 'l-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
        final item = <String, dynamic>{
          'id': '$id-i',
          'type': 'list_item',
          'children': [_paragraphElement(text)..['id'] = '$id-p'],
        };
        block.element
          ..['type'] = type
          ..['children'] = [item];
        block.text?.dispose();
        block.text = null;
        for (final child in block.children) {
          child.dispose();
        }
        block.childElements = [item];
        block.children = [TextEditingController(text: text)..addListener(_markDirty)];
      }
    } else if (type == 'code_block') {
      if (!wasCode) {
        final lines = text.split('\n');
        block.element['children'] = [
          for (var i = 0; i < lines.length; i++)
            {
              'id': '${block.element['id']}-$i',
              'type': 'code_line',
              'children': [
                {'id': '${block.element['id']}-$i-t', 'text': lines[i]},
              ],
            },
        ];
        block.element['type'] = 'code_block';
        block.element['language'] = block.element['language'] ?? 'plaintext';
        block.text?.dispose();
        block.text = TextEditingController(text: text)..addListener(_markDirty);
        for (final child in block.children) {
          child.dispose();
        }
        block.children = const [];
        block.childElements = const [];
      }
    } else {
      if (wasList || wasCode || wasCallout) {
        for (final child in block.children) {
          child.dispose();
        }
        block.children = const [];
        block.childElements = const [];
        block.element['children'] = [
          {'id': _textLeafId(block.element), 'text': text},
        ];
        block.text?.dispose();
        block.text = TextEditingController(text: text)..addListener(_markDirty);
      }
      block.element['type'] = type;
      if (block.text == null) {
        block.text = TextEditingController(text: text)..addListener(_markDirty);
      }
    }
    setState(() => _dirty = true);
  }

  void _addBlock() {
    if (_readOnly) return;
    final block = _SdocBlock(_paragraphElement(''));
    _blocks.add(block);
    _bindBlock(_blocks.length - 1);
    setState(() {
      _active = _blocks.length - 1;
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _deleteBlock(int index) {
    if (_readOnly || _blocks.length <= 1) return;
    setState(() {
      _blocks[index].deleted = true;
      if (_active == index) _active = index > 0 ? index - 1 : 0;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    return Column(
      children: [
        _header(l10n, workspace),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _content(l10n)),
      ],
    );
  }

  Widget _header(L10n l10n, WorkspaceController workspace) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const WebIcon('sdoc', size: 22, color: AppColors.primary),
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
                const SizedBox(width: 14),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving || !_dirty || _readOnly ? null : save,
                  icon: _saving
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 15),
                  label: Text(l10n.save, style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(width: 4),
                if (workspace.repoId == widget.repo.id)
                  IconAction(icon: 'share', tooltip: l10n.share, size: 17, onPressed: () => shareEntry(context, workspace, widget.entry)),
                IconAction(icon: 'history', tooltip: l10n.history, size: 17, onPressed: () => showFileHistory(context, workspace, widget.entry)),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (!_readOnly)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  _ToolbarButton(icon: Icons.notes, tooltip: l10n.zh ? '正文' : 'Paragraph', onTap: () => _changeType('paragraph')),
                  _ToolbarButton(icon: Icons.title, tooltip: l10n.zh ? '一级标题' : 'Heading 1', onTap: () => _changeType('header1')),
                  _ToolbarButton(icon: Icons.text_fields, tooltip: l10n.zh ? '二级标题' : 'Heading 2', onTap: () => _changeType('header2')),
                  _ToolbarButton(icon: Icons.format_size, tooltip: l10n.zh ? '三级标题' : 'Heading 3', onTap: () => _changeType('header3')),
                  _toolDivider(),
                  _ToolbarButton(icon: Icons.format_list_bulleted, tooltip: l10n.zh ? '无序列表' : 'Bulleted list', onTap: () => _changeType('unordered_list')),
                  _ToolbarButton(icon: Icons.format_list_numbered, tooltip: l10n.zh ? '有序列表' : 'Numbered list', onTap: () => _changeType('ordered_list')),
                  _ToolbarButton(icon: Icons.checklist, tooltip: l10n.zh ? '任务列表' : 'Checklist', onTap: () => _changeType('check_list_item')),
                  _ToolbarButton(icon: Icons.format_quote, tooltip: l10n.zh ? '引用' : 'Quote', onTap: () => _changeType('quote')),
                  _ToolbarButton(icon: Icons.code, tooltip: l10n.zh ? '代码块' : 'Code block', onTap: () => _changeType('code_block')),
                  const Spacer(),
                  _ToolbarButton(icon: Icons.add, tooltip: l10n.zh ? '添加段落' : 'Add block', onTap: _addBlock),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolDivider() => Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 5), color: AppColors.border);

  Widget _content(L10n l10n) {
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
        child: Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(56, 40, 56, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < _blocks.length; index++)
                  if (!_blocks[index].deleted) _blockView(index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _blockView(int index) {
    final block = _blocks[index];
    final active = _active == index;
    final child = switch (block.type) {
      'title' => _textField(block, 28, FontWeight.w700, onTap: () => _setActive(index)),
      'header1' => _textField(block, 26, FontWeight.w700, onTap: () => _setActive(index)),
      'header2' => _textField(block, 22, FontWeight.w600, onTap: () => _setActive(index)),
      'header3' => _textField(block, 18, FontWeight.w600, onTap: () => _setActive(index)),
      'header4' || 'header5' || 'header6' => _textField(block, 16, FontWeight.w600, onTap: () => _setActive(index)),
      'code_block' => _codeView(block, index),
      'unordered_list' || 'ordered_list' => _listView(block, index),
      'check_list_item' => _checkView(block, index),
      'quote' => _quoteView(block, index),
      'callout' => _calloutView(block, index),
      'table' => _tableView(block),
      'image_block' => _mediaPlaceholder('图片', 'Image'),
      'video' => _mediaPlaceholder('视频', 'Video'),
      'embed_link' => _mediaPlaceholder('嵌入链接', 'Embedded link'),
      'formula' => _mediaPlaceholder('公式', 'Formula'),
      'toggle_header' => _toggleView(block),
      _ => _textField(block, 15, FontWeight.w400, onTap: () => _setActive(index)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child),
          if (!_readOnly && active)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconAction(
                icon: 'delete',
                tooltip: L10n.of(context).delete,
                size: 13,
                color: AppColors.danger,
                onPressed: () => _deleteBlock(index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textField(_SdocBlock block, double size, FontWeight weight, {required VoidCallback onTap}) {
    final controller = block.text;
    if (controller == null) return const SizedBox.shrink();
    return TextField(
      controller: controller,
      onTap: onTap,
      enabled: !_readOnly,
      maxLines: null,
      style: TextStyle(fontSize: size, fontWeight: weight, height: 1.5, color: AppColors.text),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        isDense: true,
      ),
    );
  }

  Widget _codeView(_SdocBlock block, int index) {
    return GestureDetector(
      onTap: () => _setActive(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
        child: TextField(
          controller: block.text,
          enabled: !_readOnly,
          maxLines: null,
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.6),
          decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ),
    );
  }

  Widget _listView(_SdocBlock block, int index) {
    return GestureDetector(
      onTap: () => _setActive(index),
      child: Column(
        children: [
          for (var i = 0; i < block.children.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        block.type == 'ordered_list' ? '${i + 1}.' : '•',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: block.children[i],
                      enabled: !_readOnly,
                      maxLines: null,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                      decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 3)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _checkView(_SdocBlock block, int index) {
    final checked = block.element['checked'] == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Checkbox(
            value: checked,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: _readOnly
                ? null
                : (value) {
                    setState(() {
                      block.element['checked'] = value == true;
                      _dirty = true;
                    });
                  },
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _textField(block, 15, FontWeight.w400, onTap: () => _setActive(index))),
      ],
    );
  }

  Widget _quoteView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 3))),
      child: _textField(block, 15, FontWeight.w400, onTap: () => _setActive(index)),
    );
  }

  Widget _calloutView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFEF7E0), borderRadius: BorderRadius.circular(5)),
      child: Column(
        children: [
          for (var i = 0; i < block.children.length; i++)
            TextField(
              controller: block.children[i],
              enabled: !_readOnly,
              maxLines: null,
              style: const TextStyle(fontSize: 14.5, height: 1.6),
              decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 3)),
            ),
        ],
      ),
    );
  }

  Widget _toggleView(_SdocBlock block) {
    final text = _textOf(block.element);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: [
          const WebIcon('arrow-down', size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.text))),
        ],
      ),
    );
  }

  Widget _tableView(_SdocBlock block) {
    final rows = (block.element['children'] as List?)?.whereType<Map>().toList() ?? const [];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final cell in ((row['children'] as List?) ?? const []).whereType<Map>())
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border))),
                        child: Text(
                          _plainNode(cell),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaPlaceholder(String zh, String en) {
    final label = L10n.of(context).zh ? zh : en;
    return Container(
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
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
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: _hovered ? AppColors.hover : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: Icon(widget.icon, size: 17, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
