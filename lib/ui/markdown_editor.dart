import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  Timer? _historyTimer;
  String _lastSnapshot = '';
  late String _original;
  int _active = 0;
  int? _editing;

  String get text => _serialize();
  bool get isDirty => text != _original;
  bool get canUndo => _undoStack.isNotEmpty || _serialize() != _lastSnapshot;
  bool get canRedo => _redoStack.isNotEmpty && _serialize() == _lastSnapshot;

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
    _lastSnapshot = _original;
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
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
    if (widget.readOnly) return;
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 600), _commitTextHistory);
  }

  void _commitTextHistory() {
    if (!mounted) return;
    final current = _serialize();
    if (current == _lastSnapshot) return;
    _undoStack.add(_lastSnapshot);
    _trimHistory();
    _redoStack.clear();
    _lastSnapshot = current;
    setState(() {});
  }

  void _pushUndo() {
    _historyTimer?.cancel();
    final current = _serialize();
    if (_undoStack.isEmpty || _undoStack.last != current) _undoStack.add(current);
    _trimHistory();
    _redoStack.clear();
  }

  void _settleHistory() {
    _historyTimer?.cancel();
    _lastSnapshot = _serialize();
  }

  void _trimHistory() {
    if (_undoStack.length > 100) _undoStack.removeRange(0, _undoStack.length - 100);
  }

  void _undo() {
    _historyTimer?.cancel();
    final current = _serialize();
    String target;
    if (current != _lastSnapshot) {
      target = _lastSnapshot;
      _redoStack.add(current);
      _lastSnapshot = target;
    } else {
      if (_undoStack.isEmpty) return;
      target = _undoStack.removeLast();
      _redoStack.add(current);
    }
    _restoreSnapshot(target);
  }

  void _redo() {
    _historyTimer?.cancel();
    final current = _serialize();
    if (current != _lastSnapshot) {
      _undoStack.add(_lastSnapshot);
      _trimHistory();
      _redoStack.clear();
      _lastSnapshot = current;
      setState(() {});
      return;
    }
    if (_redoStack.isEmpty) return;
    _undoStack.add(current);
    final target = _redoStack.removeLast();
    _lastSnapshot = target;
    _restoreSnapshot(target);
  }

  void _restoreSnapshot(String source) {
    for (final block in _blocks) {
      block.dispose();
    }
    _blocks.clear();
    _parse(source);
    if (_blocks.isEmpty) {
      final block = _MdBlock(type: _MdType.paragraph);
      _listen(block);
      _blocks.add(block);
    }
    _active = 0;
    _editing = null;
    _lastSnapshot = _serialize();
    setState(() {});
    widget.onChanged?.call(isDirty);
  }

  void markSaved() {
    _historyTimer?.cancel();
    _original = _serialize();
    _lastSnapshot = _original;
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
    } else if (source.endsWith('\n')) {
      _add(_MdBlock(type: _MdType.paragraph));
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
    _pushUndo();
    setState(() {
      _blocks[index].type = type;
      if (type == _MdType.heading) _blocks[index].headingLevel = level;
    });
    _settleHistory();
    widget.onChanged?.call(isDirty);
  }

  void _focusBlock(_MdBlock block, int offset) {
    final index = _blocks.indexOf(block);
    if (index < 0) return;
    setState(() {
      _active = index;
      _editing = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      block.focus.requestFocus();
      block.controller.selection = TextSelection.collapsed(
        offset: offset.clamp(0, block.controller.text.length),
      );
    });
  }

  KeyEventResult _onKey(_MdBlock block, int index, KeyEvent event) {
    if (widget.readOnly) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final value = block.controller.value;
    if (value.composing.isValid) return KeyEventResult.ignored;
    final selection = value.selection;
    if (!selection.isValid) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final text = value.text;
    final command = HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (command && key == LogicalKeyboardKey.keyZ) {
      if (shift) {
        _redo();
      } else {
        _undo();
      }
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyB) {
      _wrapBlock(block, '**', '**');
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyI) {
      _wrapBlock(block, '*', '*');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      if (block.type == _MdType.code) return KeyEventResult.ignored;
      _splitBlock(block, index);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      if (!selection.isCollapsed || selection.start != 0) return KeyEventResult.ignored;
      if (text.isEmpty) {
        if (_blocks.length <= 1) return KeyEventResult.handled;
        _pushUndo();
        setState(() {
          _blocks.removeAt(index).dispose();
          _active = (index - 1).clamp(0, _blocks.length - 1);
          _editing = _active;
        });
        _settleHistory();
        widget.onChanged?.call(isDirty);
        _focusBlock(_blocks[_active], _blocks[_active].controller.text.length);
        return KeyEventResult.handled;
      }
      if (index == 0) return KeyEventResult.ignored;
      _pushUndo();
      final previous = _blocks[index - 1];
      final offset = previous.controller.text.length;
      final separator = previous.type == _MdType.code || block.type == _MdType.code ? '\n' : '';
      previous.controller.text = '${previous.controller.text}$separator$text';
      setState(() {
        _blocks.removeAt(index).dispose();
        _active = index - 1;
        _editing = index - 1;
      });
      _settleHistory();
      widget.onChanged?.call(isDirty);
      _focusBlock(previous, offset);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete) {
      if (!selection.isCollapsed || selection.start != text.length) return KeyEventResult.ignored;
      if (index >= _blocks.length - 1) return KeyEventResult.ignored;
      _pushUndo();
      final next = _blocks[index + 1];
      final offset = text.length;
      final separator = block.type == _MdType.code || next.type == _MdType.code ? '\n' : '';
      block.controller.text = '$text$separator${next.controller.text}';
      setState(() {
        _blocks.removeAt(index + 1).dispose();
        _active = index;
        _editing = index;
      });
      _settleHistory();
      widget.onChanged?.call(isDirty);
      _focusBlock(block, offset);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp && selection.isCollapsed && selection.start == 0 && index > 0) {
      final previous = _blocks[index - 1];
      _focusBlock(previous, previous.controller.text.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && selection.isCollapsed && selection.start == text.length && index < _blocks.length - 1) {
      _focusBlock(_blocks[index + 1], 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _splitBlock(_MdBlock block, int index) {
    final value = block.controller.value;
    final text = value.text;
    final caret = value.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    final exitsBlock = before.isEmpty && after.isEmpty && (block.type == _MdType.bullet || block.type == _MdType.numbered || block.type == _MdType.check || block.type == _MdType.quote);
    _pushUndo();
    if (exitsBlock) {
      setState(() {
        block.type = _MdType.paragraph;
        block.checked = false;
      });
      _settleHistory();
      widget.onChanged?.call(isDirty);
      return;
    }
    block.controller.text = before;
    final newType = switch (block.type) {
      _MdType.bullet => _MdType.bullet,
      _MdType.numbered => _MdType.numbered,
      _MdType.check => _MdType.check,
      _MdType.quote => _MdType.quote,
      _ => _MdType.paragraph,
    };
    final newBlock = _MdBlock(type: newType, text: after);
    _listen(newBlock);
    setState(() {
      _blocks.insert(index + 1, newBlock);
      _active = index + 1;
      _editing = index + 1;
    });
    _settleHistory();
    widget.onChanged?.call(isDirty);
    _focusBlock(newBlock, 0);
  }

  void _wrapSelection(String before, String after) {
    if (widget.readOnly || _blocks.isEmpty) return;
    _wrapBlock(_blocks[_active.clamp(0, _blocks.length - 1)], before, after);
  }

  void _wrapBlock(_MdBlock block, String before, String after) {
    if (widget.readOnly) return;
    final index = _blocks.indexOf(block);
    if (index < 0) return;
    _pushUndo();
    setState(() => _editing = index);
    final controller = block.controller;
    final selection = controller.selection;
    final value = controller.text;
    final start = selection.isValid ? selection.start : value.length;
    final end = selection.isValid ? selection.end : value.length;
    final selected = value.substring(start, end);
    controller.value = TextEditingValue(
      text: value.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(offset: start + before.length + selected.length),
    );
    _settleHistory();
    widget.onChanged?.call(isDirty);
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
                  _button(Icons.undo, l10n.zh ? '撤销' : 'Undo', canUndo ? _undo : null),
                  _button(Icons.redo, l10n.zh ? '重做' : 'Redo', canRedo ? _redo : null),
                  _divider(),
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
                        _pushUndo();
                        setState(() => block.checked = value == true);
                        _settleHistory();
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
      child: content,
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
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => _onKey(block, index, event),
      child: TextField(
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

  Widget _button(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: onTap == null ? AppColors.borderStrong : AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 4), color: AppColors.border);
}
