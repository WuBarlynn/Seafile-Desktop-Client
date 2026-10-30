import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

enum _MdType { paragraph, heading, quote, bullet, numbered, check, code }

class _MdBlock {
  _MdBlock({
    required this.type,
    this.headingLevel = 0,
    String text = '',
    this.checked = false,
    this.codeLanguage = '',
  })  : controller = TextEditingController(text: text),
        focus = FocusNode();

  _MdType type;
  int headingLevel;
  bool checked;
  String codeLanguage;
  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

/// A block editor for Markdown: headings, lists, quotes and code blocks are
/// rendered as content, while the Markdown source is regenerated on save.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.initialText,
    required this.readOnly,
    this.onChanged,
  });

  final String initialText;
  final bool readOnly;
  final ValueChanged<bool>? onChanged;

  @override
  State<MarkdownEditor> createState() => MarkdownEditorState();
}

class MarkdownEditorState extends State<MarkdownEditor> {
  final _scroll = ScrollController();
  final List<_MdBlock> _blocks = [];
  late String _original;
  int _active = 0;
  int? _editing;

  String get text => _serialize();
  bool get isDirty => text != _original;

  @override
  void initState() {
    super.initState();
    _original = widget.initialText.replaceAll('\r\n', '\n');
    _parse(_original);
    if (_blocks.isEmpty) {
      final block = _MdBlock(type: _MdType.paragraph);
      _listen(block);
      _blocks.add(block);
    }
    _original = _serialize();
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _listen(_MdBlock block) {
    block.controller.addListener(_onChange);
    block.focus.addListener(() {
      if (!mounted) return;
      final index = _blocks.indexOf(block);
      if (block.focus.hasFocus) {
        if (_active != index || _editing != index) {
          setState(() {
            _active = index;
            _editing = index;
          });
        }
      } else if (_editing == index) {
        setState(() => _editing = null);
      }
    });
  }

  void _onChange() {
    widget.onChanged?.call(isDirty);
  }

  void markSaved() {
    _original = _serialize();
    widget.onChanged?.call(false);
  }

  void _parse(String source) {
    final lines = source.split('\n');
    var inCode = false;
    var codeLanguage = '';
    final codeLines = <String>[];
    for (final line in lines) {
      final fence = RegExp(r'^\s*```(.*)$').firstMatch(line);
      if (inCode) {
        if (fence != null) {
          _add(_MdBlock(type: _MdType.code, text: codeLines.join('\n'), codeLanguage: codeLanguage));
          codeLines.clear();
          inCode = false;
        } else {
          codeLines.add(line);
        }
        continue;
      }
      if (fence != null) {
        inCode = true;
        codeLanguage = fence.group(1)?.trim() ?? '';
        continue;
      }
      if (line.trim().isEmpty) continue;
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        _add(_MdBlock(
          type: _MdType.heading,
          headingLevel: heading.group(1)!.length,
          text: heading.group(2)!,
        ));
        continue;
      }
      final check = RegExp(r'^\s*[-*+]\s+\[([ xX])\]\s+(.*)$').firstMatch(line);
      if (check != null) {
        _add(_MdBlock(type: _MdType.check, text: check.group(2)!, checked: check.group(1)!.toLowerCase() == 'x'));
        continue;
      }
      final quote = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        _add(_MdBlock(type: _MdType.quote, text: quote.group(1)!));
        continue;
      }
      final bullet = RegExp(r'^\s*[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        _add(_MdBlock(type: _MdType.bullet, text: bullet.group(1)!));
        continue;
      }
      final numbered = RegExp(r'^\s*\d+[.)]\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        _add(_MdBlock(type: _MdType.numbered, text: numbered.group(1)!));
        continue;
      }
      _add(_MdBlock(type: _MdType.paragraph, text: line));
    }
    if (inCode) {
      _add(_MdBlock(type: _MdType.code, text: codeLines.join('\n'), codeLanguage: codeLanguage));
    }
  }

  void _add(_MdBlock block) {
    _listen(block);
    _blocks.add(block);
  }

  String _serialize() {
    final buffer = StringBuffer();
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (i > 0) {
        final previous = _blocks[i - 1];
        buffer.write(_isList(previous.type) && _isList(block.type) ? '\n' : '\n\n');
      }
      final content = block.controller.text;
      switch (block.type) {
        case _MdType.heading:
          buffer.write('${'#' * block.headingLevel} $content');
        case _MdType.quote:
          buffer.write('> $content');
        case _MdType.bullet:
          buffer.write('- $content');
        case _MdType.numbered:
          buffer.write('1. $content');
        case _MdType.check:
          buffer.write('- [${block.checked ? 'x' : ' '}] $content');
        case _MdType.code:
          buffer.write('```${block.codeLanguage}\n$content\n```');
        case _MdType.paragraph:
          buffer.write(content);
      }
    }
    return buffer.toString();
  }

  bool _isList(_MdType type) => type == _MdType.bullet || type == _MdType.numbered || type == _MdType.check;

  void _setActive(int index) {
    if (_active != index) setState(() => _active = index);
  }

  void _changeType(_MdType type, {int level = 0}) {
    if (widget.readOnly) return;
    final index = _active.clamp(0, _blocks.length - 1);
    setState(() {
      _blocks[index].type = type;
      if (type == _MdType.heading) _blocks[index].headingLevel = level;
    });
    widget.onChanged?.call(isDirty);
  }

  void _addBlock() {
    if (widget.readOnly) return;
    final index = (_active + 1).clamp(0, _blocks.length);
    final block = _MdBlock(type: _MdType.paragraph);
    _listen(block);
    setState(() {
      _blocks.insert(index, block);
      _active = index;
      _editing = index;
    });
    widget.onChanged?.call(isDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      block.focus.requestFocus();
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      }
    });
  }

  void _deleteBlock() {
    if (widget.readOnly || _blocks.length <= 1) return;
    final index = _active.clamp(0, _blocks.length - 1);
    setState(() {
      _blocks.removeAt(index).dispose();
      _active = (index - 1).clamp(0, _blocks.length - 1);
    });
    widget.onChanged?.call(isDirty);
  }

  void _wrapSelection(String before, String after) {
    if (widget.readOnly || _blocks.isEmpty) return;
    final index = _active.clamp(0, _blocks.length - 1);
    setState(() => _editing = index);
    final controller = _blocks[index].controller;
    final selection = controller.selection;
    final value = controller.text;
    final start = selection.isValid ? selection.start : value.length;
    final end = selection.isValid ? selection.end : value.length;
    final selected = value.substring(start, end);
    controller.value = TextEditingValue(
      text: value.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(offset: start + before.length + selected.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      color: const Color(0xFFF4F5F7),
      child: Column(
        children: [
          if (!widget.readOnly)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  _button(Icons.notes, l10n.zh ? '正文' : 'Paragraph', () => _changeType(_MdType.paragraph)),
                  _button(Icons.title, l10n.zh ? '一级标题' : 'Heading 1', () => _changeType(_MdType.heading, level: 1)),
                  _button(Icons.text_fields, l10n.zh ? '二级标题' : 'Heading 2', () => _changeType(_MdType.heading, level: 2)),
                  _button(Icons.format_size, l10n.zh ? '三级标题' : 'Heading 3', () => _changeType(_MdType.heading, level: 3)),
                  _divider(),
                  _button(Icons.format_bold, l10n.zh ? '粗体' : 'Bold', () => _wrapSelection('**', '**')),
                  _button(Icons.format_italic, l10n.zh ? '斜体' : 'Italic', () => _wrapSelection('*', '*')),
                  _button(Icons.format_strikethrough, l10n.zh ? '删除线' : 'Strikethrough', () => _wrapSelection('~~', '~~')),
                  _button(Icons.code, l10n.zh ? '行内代码' : 'Inline code', () => _wrapSelection('`', '`')),
                  _button(Icons.link, l10n.zh ? '链接' : 'Link', () => _wrapSelection('[', '](https://)')),
                  _divider(),
                  _button(Icons.format_list_bulleted, l10n.zh ? '无序列表' : 'Bulleted list', () => _changeType(_MdType.bullet)),
                  _button(Icons.format_list_numbered, l10n.zh ? '有序列表' : 'Numbered list', () => _changeType(_MdType.numbered)),
                  _button(Icons.checklist, l10n.zh ? '任务列表' : 'Checklist', () => _changeType(_MdType.check)),
                  _button(Icons.format_quote, l10n.zh ? '引用' : 'Quote', () => _changeType(_MdType.quote)),
                  _button(Icons.data_object, l10n.zh ? '代码块' : 'Code block', () => _changeType(_MdType.code)),
                  const Spacer(),
                  _button(Icons.add, l10n.zh ? '添加段落' : 'Add block', _addBlock),
                ],
              ),
            ),
          Expanded(
            child: Padding(
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
                    padding: const EdgeInsets.fromLTRB(48, 36, 48, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < _blocks.length; index++) _blockView(index),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockView(int index) {
    final block = _blocks[index];
    final active = _active == index;
    final Widget content = switch (block.type) {
      _MdType.heading => _textField(block, index, _headingSize(block.headingLevel), FontWeight.w700),
      _MdType.quote => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 3))),
          child: _textField(block, index, 15, FontWeight.w400, color: AppColors.textSecondary),
        ),
      _MdType.bullet => _listRow(block, index, '•'),
      _MdType.numbered => _listRow(block, index, '1.'),
      _MdType.check => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: block.checked,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        setState(() => block.checked = value == true);
                        widget.onChanged?.call(isDirty);
                      },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: _textField(block, index, 15, FontWeight.w400)),
          ],
        ),
      _MdType.code => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
          child: _textField(block, index, 13, FontWeight.w400, monospace: true),
        ),
      _MdType.paragraph => _textField(block, index, 15, FontWeight.w400),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: content),
          if (!widget.readOnly && active)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: IconButton(
                onPressed: _deleteBlock,
                icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: L10n.of(context).delete,
              ),
            ),
        ],
      ),
    );
  }

  double _headingSize(int level) => switch (level) { 1 => 28, 2 => 23, 3 => 19, _ => 16 };

  Widget _listRow(_MdBlock block, int index, String marker) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 24, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(marker, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)))),
        Expanded(child: _textField(block, index, 15, FontWeight.w400)),
      ],
    );
  }

  Widget _textField(_MdBlock block, int index, double size, FontWeight weight, {bool monospace = false, Color? color}) {
    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: monospace ? 1.6 : 1.55,
      fontFamily: monospace ? 'Menlo' : null,
      color: color ?? AppColors.text,
    );
    if (!widget.readOnly && _editing != index) {
      return MouseRegion(
        cursor: SystemMouseCursors.text,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _active = index;
              _editing = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _richText(block.controller.text, style, monospace: monospace),
          ),
        ),
      );
    }
    return TextField(
      controller: block.controller,
      focusNode: block.focus,
      autofocus: _editing == index,
      enabled: !widget.readOnly,
      onTap: () => _setActive(index),
      maxLines: null,
      style: style,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 3),
      ),
    );
  }

  Widget _richText(String text, TextStyle base, {bool monospace = false}) {
    if (monospace) {
      return Text(text.isEmpty ? ' ' : text, style: base);
    }
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: base));
      }
      final token = match.group(0)!;
      TextStyle? style;
      String visible = token;
      if (token.startsWith('**') || token.startsWith('__')) {
        visible = token.substring(2, token.length - 2);
        style = base.copyWith(fontWeight: FontWeight.w700);
      } else if (token.startsWith('~~')) {
        visible = token.substring(2, token.length - 2);
        style = base.copyWith(decoration: TextDecoration.lineThrough);
      } else if (token.startsWith('`')) {
        visible = token.substring(1, token.length - 1);
        style = base.copyWith(fontFamily: 'Menlo', backgroundColor: const Color(0xFFF1F3F5), color: const Color(0xFFC7254E));
      } else if (token.startsWith('[')) {
        final close = token.indexOf(']');
        visible = token.substring(1, close);
        style = base.copyWith(color: const Color(0xFF2F6FEB), decoration: TextDecoration.underline);
      } else if (token.startsWith('*') || token.startsWith('_')) {
        visible = token.substring(1, token.length - 1);
        style = base.copyWith(fontStyle: FontStyle.italic);
      }
      spans.add(TextSpan(text: visible, style: style ?? base));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: ' ', style: base));
    return Text.rich(TextSpan(style: base, children: spans), style: base);
  }

  static final _inline = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|`[^`]+`|~~[^~]+~~|\*[^*\n]+\*|_[^_\n]+_|\[[^\]]+\]\([^)]+\))');

  Widget _button(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppColors.border);
}
