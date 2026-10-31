import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/workspace.dart';
import 'file_actions.dart';
import 'sdoc_comments_panel.dart';
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
  FocusNode? textFocus;
  List<TextEditingController> children = const [];
  List<FocusNode> childFocus = const [];
  List<Map<String, dynamic>> childElements = const [];
  TextEditingController? toggleTitle;
  FocusNode? toggleTitleFocus;
  List<TextEditingController> toggleChildren = const [];
  List<FocusNode> toggleChildFocus = const [];
  List<Map<String, dynamic>> toggleChildElements = const [];
  bool toggleCollapsed = false;
  bool deleted = false;

  String get type => element['type'] as String? ?? 'paragraph';
}

enum _SdocFieldKind { simple, code, listItem, calloutChild, toggleTitle, toggleChild }

class _SdocField {
  const _SdocField({
    required this.block,
    required this.blockIndex,
    required this.kind,
    required this.controller,
    required this.focus,
    this.item = 0,
  });

  final _SdocBlock block;
  final int blockIndex;
  final _SdocFieldKind kind;
  final TextEditingController controller;
  final FocusNode focus;
  final int item;
}

class SdocEditorState extends State<SdocEditor> {
  final _scroll = ScrollController();
  final List<_SdocBlock> _blocks = [];
  final Map<String, TextEditingController> _tableControllers = {};
  final Map<String, Future<Uint8List>> _imageCache = {};
  final Set<String> _openingVideos = {};
  bool _commentsOpen = false;
  final Map<TextEditingController, String> _lastTexts = {};
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
      _disposeBlock(block);
    }
    for (final controller in _tableControllers.values) {
      controller.dispose();
    }
    _lastTexts.clear();
    _scroll.dispose();
    super.dispose();
  }

  void _disposeBlock(_SdocBlock block) {
    final text = block.text;
    if (text != null) {
      _lastTexts.remove(text);
      text.dispose();
    }
    for (final controller in block.children) {
      _lastTexts.remove(controller);
      controller.dispose();
    }
    block.toggleTitle?.dispose();
    for (final controller in block.toggleChildren) {
      _lastTexts.remove(controller);
      controller.dispose();
    }
    block.textFocus?.dispose();
    for (final focus in block.childFocus) {
      focus.dispose();
    }
    block.toggleTitleFocus?.dispose();
    for (final focus in block.toggleChildFocus) {
      focus.dispose();
    }
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
      _disposeBlock(block);
    }
    _blocks.clear();
    for (final controller in _tableControllers.values) {
      controller.dispose();
    }
    _tableControllers.clear();
    _lastTexts.clear();
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
        block.childFocus = [for (final _ in children) FocusNode()];
        for (final controller in block.children) {
          _watch(controller);
        }
      } else if (type == 'callout') {
        final children = (element['children'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
        block.childElements = children;
        block.children = [
          for (final child in children) TextEditingController(text: _textOf(child)),
        ];
        block.childFocus = [for (final _ in children) FocusNode()];
        for (final controller in block.children) {
          _watch(controller);
        }
      } else if (type == 'toggle_header') {
        final children = (element['children'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
        final titleElement = children.isNotEmpty ? children.first : null;
        final contentElement = children.length > 1 ? children[1] : null;
        block.toggleCollapsed = element['collapsed'] == true;
        block.toggleTitle = TextEditingController(text: titleElement == null ? '' : _textOf(titleElement));
        block.toggleTitleFocus = FocusNode();
        _watch(block.toggleTitle!);
        final contentChildren = (contentElement?['children'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? [];
        block.toggleChildElements = contentChildren;
        block.toggleChildren = [
          for (final child in contentChildren) TextEditingController(text: _textOf(child)),
        ];
        block.toggleChildFocus = [for (final _ in contentChildren) FocusNode()];
        for (final controller in block.toggleChildren) {
          _watch(controller);
        }
      } else if (_isSimpleEditable(type)) {
        block.text = TextEditingController(text: _textOf(element));
        block.textFocus = FocusNode();
        _watch(block.text!);
      }
      _blocks.add(block);
    }
    if (_blocks.isEmpty && !_readOnly) {
      _blocks.add(_newParagraphBlock(''));
    }
    _active = _blocks.isEmpty ? null : 0;
  }

  _SdocBlock _newParagraphBlock(String text) {
    final block = _SdocBlock(_paragraphElement(text));
    block.text = TextEditingController(text: text);
    block.textFocus = FocusNode();
    _watch(block.text!);
    return block;
  }

  bool _isSimpleEditable(String type) {
    return type == 'title' ||
        type == 'paragraph' ||
        type == 'quote' ||
        type == 'check_list_item' ||
        type == 'code_block' ||
        type.startsWith('header');
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

  void _watch(TextEditingController controller) {
    _lastTexts[controller] = controller.text;
    controller.addListener(() {
      if (_lastTexts[controller] == controller.text) return;
      _lastTexts[controller] = controller.text;
      _markDirty();
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _setActive(int index) {
    if (_active != index) setState(() => _active = index);
  }

  List<_SdocField> _fields() {
    final fields = <_SdocField>[];
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (block.deleted) continue;
      final type = block.type;
      if (type == 'unordered_list' || type == 'ordered_list') {
        for (var j = 0; j < block.children.length && j < block.childFocus.length; j++) {
          fields.add(_SdocField(block: block, blockIndex: i, kind: _SdocFieldKind.listItem, controller: block.children[j], focus: block.childFocus[j], item: j));
        }
      } else if (type == 'callout') {
        for (var j = 0; j < block.children.length && j < block.childFocus.length; j++) {
          fields.add(_SdocField(block: block, blockIndex: i, kind: _SdocFieldKind.calloutChild, controller: block.children[j], focus: block.childFocus[j], item: j));
        }
      } else if (type == 'toggle_header') {
        if (block.toggleTitle != null && block.toggleTitleFocus != null) {
          fields.add(_SdocField(block: block, blockIndex: i, kind: _SdocFieldKind.toggleTitle, controller: block.toggleTitle!, focus: block.toggleTitleFocus!));
        }
        if (!block.toggleCollapsed) {
          for (var j = 0; j < block.toggleChildren.length && j < block.toggleChildFocus.length; j++) {
            fields.add(_SdocField(block: block, blockIndex: i, kind: _SdocFieldKind.toggleChild, controller: block.toggleChildren[j], focus: block.toggleChildFocus[j], item: j));
          }
        }
      } else if (_isSimpleEditable(type) && block.text != null && block.textFocus != null) {
        fields.add(_SdocField(
          block: block,
          blockIndex: i,
          kind: type == 'code_block' ? _SdocFieldKind.code : _SdocFieldKind.simple,
          controller: block.text!,
          focus: block.textFocus!,
        ));
      }
    }
    return fields;
  }

  int _fieldPosition(List<_SdocField> fields, _SdocField field) {
    for (var i = 0; i < fields.length; i++) {
      if (identical(fields[i].focus, field.focus) && identical(fields[i].controller, field.controller)) return i;
    }
    return -1;
  }

  _SdocField? _previousField(_SdocField field) {
    final fields = _fields();
    final position = _fieldPosition(fields, field);
    if (position <= 0) return null;
    final previous = fields[position - 1];
    if (previous.blockIndex != field.blockIndex && previous.blockIndex != field.blockIndex - 1) return null;
    return previous;
  }

  _SdocField? _nextField(_SdocField field) {
    final fields = _fields();
    final position = _fieldPosition(fields, field);
    if (position < 0 || position >= fields.length - 1) return null;
    final next = fields[position + 1];
    if (next.blockIndex != field.blockIndex && next.blockIndex != field.blockIndex + 1) return null;
    return next;
  }

  _SdocField? _firstFieldOfBlock(_SdocBlock block, int index) {
    final type = block.type;
    if (_isSimpleEditable(type) && block.text != null && block.textFocus != null) {
      return _SdocField(block: block, blockIndex: index, kind: type == 'code_block' ? _SdocFieldKind.code : _SdocFieldKind.simple, controller: block.text!, focus: block.textFocus!);
    }
    if ((type == 'unordered_list' || type == 'ordered_list' || type == 'callout') && block.children.isNotEmpty && block.childFocus.isNotEmpty) {
      return _SdocField(block: block, blockIndex: index, kind: type == 'callout' ? _SdocFieldKind.calloutChild : _SdocFieldKind.listItem, controller: block.children.first, focus: block.childFocus.first);
    }
    if (type == 'toggle_header' && block.toggleTitle != null && block.toggleTitleFocus != null) {
      return _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.toggleTitle, controller: block.toggleTitle!, focus: block.toggleTitleFocus!);
    }
    return null;
  }

  void _focusField(_SdocField field, int offset) {
    setState(() => _active = field.blockIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      field.focus.requestFocus();
      field.controller.selection = TextSelection.collapsed(offset: offset.clamp(0, field.controller.text.length));
    });
  }

  void _focusBlock(_SdocBlock block, int index, int offset) {
    final field = _firstFieldOfBlock(block, index);
    if (field != null) _focusField(field, offset);
  }

  KeyEventResult _onKey(_SdocField field, KeyEvent event) {
    if (_readOnly) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final value = field.controller.value;
    if (value.composing.isValid) return KeyEventResult.ignored;
    final selection = value.selection;
    if (!selection.isValid) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final text = value.text;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      if (field.kind == _SdocFieldKind.code) return KeyEventResult.ignored;
      _handleEnter(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (!selection.isCollapsed || selection.start != 0) return KeyEventResult.ignored;
      if (field.kind == _SdocFieldKind.toggleTitle) return KeyEventResult.ignored;
      _handleBackspace(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      if (!selection.isCollapsed || selection.start != text.length) return KeyEventResult.ignored;
      _handleDelete(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && selection.isCollapsed && selection.start == 0) {
      final previous = _previousField(field);
      if (previous != null) {
        _focusField(previous, previous.controller.text.length);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown && selection.isCollapsed && selection.start == text.length) {
      final next = _nextField(field);
      if (next != null) {
        _focusField(next, 0);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleEnter(_SdocField field) {
    switch (field.kind) {
      case _SdocFieldKind.simple:
        _splitSimple(field);
      case _SdocFieldKind.listItem:
        _splitListItem(field);
      case _SdocFieldKind.calloutChild:
        _splitCalloutChild(field);
      case _SdocFieldKind.toggleTitle:
        _splitToggleTitle(field);
      case _SdocFieldKind.toggleChild:
        _splitToggleChild(field);
      case _SdocFieldKind.code:
        break;
    }
  }

  void _handleBackspace(_SdocField field) {
    final controller = field.controller;
    if (controller.text.isEmpty) {
      final fields = _fields();
      if (fields.length <= 1) {
        final block = field.block;
        if (field.kind == _SdocFieldKind.simple && block.type != 'paragraph' && block.type != 'title') {
          setState(() {
            block.element['type'] = 'paragraph';
            _dirty = true;
          });
        }
        return;
      }
      final previous = _previousField(field);
      final next = _nextField(field);
      setState(() {
        _removeField(field);
        _dirty = true;
      });
      final target = previous ?? next;
      if (target != null) {
        _focusField(target, previous != null ? target.controller.text.length : 0);
      }
      return;
    }
    final previous = _previousField(field);
    if (previous == null) return;
    final offset = previous.controller.text.length;
    final newline = previous.kind == _SdocFieldKind.code || field.kind == _SdocFieldKind.code;
    previous.controller.text = '${previous.controller.text}${newline && previous.controller.text.isNotEmpty ? '\n' : ''}${controller.text}';
    setState(() {
      _removeField(field);
      _dirty = true;
    });
    _focusField(previous, offset);
  }

  void _handleDelete(_SdocField field) {
    final next = _nextField(field);
    if (next == null || next.kind == _SdocFieldKind.toggleTitle) return;
    final offset = field.controller.text.length;
    final newline = next.kind == _SdocFieldKind.code || field.kind == _SdocFieldKind.code;
    field.controller.text = '${field.controller.text}${newline && field.controller.text.isNotEmpty ? '\n' : ''}${next.controller.text}';
    setState(() {
      _removeField(next);
      _dirty = true;
    });
    _focusField(field, offset);
  }

  void _splitSimple(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    final index = field.blockIndex;
    if (before.isEmpty && after.isEmpty) {
      if (block.type == 'quote' || block.type == 'check_list_item') {
        setState(() {
          block.element['type'] = 'paragraph';
          _dirty = true;
        });
        return;
      }
      _insertParagraphAfter(index, '');
      return;
    }
    controller.text = before;
    final newType = switch (block.type) {
      'quote' => 'quote',
      'check_list_item' => 'check_list_item',
      _ => 'paragraph',
    };
    final newBlock = _newTextBlock(newType, after);
    setState(() {
      _blocks.insert(index + 1, newBlock);
      _active = index + 1;
      _dirty = true;
    });
    _focusBlock(newBlock, index + 1, 0);
  }

  _SdocBlock _newTextBlock(String type, String text) {
    final id = 'p-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final element = <String, dynamic>{
      'id': id,
      'type': type,
      'children': [
        {'id': '$id-t', 'text': text},
      ],
      if (type == 'check_list_item') 'checked': false,
    };
    final block = _SdocBlock(element);
    block.text = TextEditingController(text: text);
    block.textFocus = FocusNode();
    _watch(block.text!);
    return block;
  }

  void _insertParagraphAfter(int index, String text) {
    final block = _newParagraphBlock(text);
    setState(() {
      _blocks.insert(index + 1, block);
      _active = index + 1;
      _dirty = true;
    });
    _focusBlock(block, index + 1, 0);
  }

  void _splitListItem(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    if (before.isEmpty && after.isEmpty) {
      if (block.children.length <= 1) {
        final replacement = _newParagraphBlock('');
        setState(() {
          _blocks[field.blockIndex] = replacement;
          _disposeBlock(block);
          _active = field.blockIndex;
          _dirty = true;
        });
        _focusBlock(replacement, field.blockIndex, 0);
      } else {
        final index = field.blockIndex;
        setState(() {
          _removeListItem(block, field.item);
          _dirty = true;
        });
        _insertParagraphAfter(index, '');
      }
      return;
    }
    controller.text = before;
    final item = field.item;
    final id = 'l-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final element = <String, dynamic>{
      'id': id,
      'type': 'list_item',
      'children': [_paragraphElement(after)..['id'] = '$id-p'],
    };
    final list = block.element['children'];
    if (list is List) list.insert(item + 1, element);
    final newController = TextEditingController(text: after);
    final newFocus = FocusNode();
    block.childElements.insert(item + 1, element);
    block.children.insert(item + 1, newController);
    block.childFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(() => _dirty = true);
    _focusField(_SdocField(block: block, blockIndex: field.blockIndex, kind: _SdocFieldKind.listItem, controller: newController, focus: newFocus, item: item + 1), 0);
  }

  void _splitCalloutChild(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    if (before.isEmpty && after.isEmpty && block.children.length <= 1) {
      _insertParagraphAfter(field.blockIndex, '');
      return;
    }
    controller.text = before;
    final item = field.item;
    final element = _paragraphElement(after);
    final list = block.element['children'];
    if (list is List) list.insert(item + 1, element);
    final newController = TextEditingController(text: after);
    final newFocus = FocusNode();
    block.childElements.insert(item + 1, element);
    block.children.insert(item + 1, newController);
    block.childFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(() => _dirty = true);
    _focusField(_SdocField(block: block, blockIndex: field.blockIndex, kind: _SdocFieldKind.calloutChild, controller: newController, focus: newFocus, item: item + 1), 0);
  }

  void _splitToggleTitle(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    controller.text = before;
    if (after.isEmpty && block.toggleChildren.isNotEmpty) {
      if (block.toggleCollapsed) {
        setState(() {
          block.toggleCollapsed = false;
          _dirty = true;
        });
      }
      _focusField(
        _SdocField(block: block, blockIndex: field.blockIndex, kind: _SdocFieldKind.toggleChild, controller: block.toggleChildren.first, focus: block.toggleChildFocus.first),
        0,
      );
      return;
    }
    _insertParagraphAfter(field.blockIndex, after);
  }

  void _splitToggleChild(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final before = text.substring(0, caret);
    final after = text.substring(caret);
    final content = (block.element['children'] as List?) != null && (block.element['children'] as List).length > 1
        ? (block.element['children'] as List)[1]
        : null;
    final contentChildren = content is Map ? content['children'] : null;
    if (contentChildren is! List) {
      controller.text = before;
      _insertParagraphAfter(field.blockIndex, after);
      return;
    }
    controller.text = before;
    final element = _paragraphElement(after);
    final item = field.item;
    contentChildren.insert(item + 1, element);
    final newController = TextEditingController(text: after);
    final newFocus = FocusNode();
    block.toggleChildElements.insert(item + 1, element);
    block.toggleChildren.insert(item + 1, newController);
    block.toggleChildFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(() => _dirty = true);
    _focusField(_SdocField(block: block, blockIndex: field.blockIndex, kind: _SdocFieldKind.toggleChild, controller: newController, focus: newFocus, item: item + 1), 0);
  }

  void _removeField(_SdocField field) {
    final block = field.block;
    switch (field.kind) {
      case _SdocFieldKind.simple:
      case _SdocFieldKind.code:
        final index = _blocks.indexOf(block);
        if (index >= 0) {
          _blocks.removeAt(index);
          _disposeBlock(block);
        }
      case _SdocFieldKind.listItem:
        _removeListItem(block, field.item);
        if (block.children.isEmpty) {
          final index = _blocks.indexOf(block);
          if (index >= 0) {
            _blocks.removeAt(index);
            _disposeBlock(block);
          }
        }
      case _SdocFieldKind.calloutChild:
        _removeCalloutChild(block, field.item);
        if (block.children.isEmpty) {
          final index = _blocks.indexOf(block);
          if (index >= 0) {
            _blocks.removeAt(index);
            _disposeBlock(block);
          }
        }
      case _SdocFieldKind.toggleChild:
        _removeToggleChild(block, field.item);
      case _SdocFieldKind.toggleTitle:
        break;
    }
  }

  void _removeListItem(_SdocBlock block, int item) {
    if (item < 0 || item >= block.children.length) return;
    final controller = block.children.removeAt(item);
    final focus = block.childFocus.removeAt(item);
    _lastTexts.remove(controller);
    controller.dispose();
    focus.dispose();
    if (item < block.childElements.length) block.childElements.removeAt(item);
    final list = block.element['children'];
    if (list is List && item < list.length) list.removeAt(item);
  }

  void _removeCalloutChild(_SdocBlock block, int item) {
    if (item < 0 || item >= block.children.length) return;
    final controller = block.children.removeAt(item);
    final focus = block.childFocus.removeAt(item);
    _lastTexts.remove(controller);
    controller.dispose();
    focus.dispose();
    if (item < block.childElements.length) block.childElements.removeAt(item);
    final list = block.element['children'];
    if (list is List && item < list.length) list.removeAt(item);
  }

  void _removeToggleChild(_SdocBlock block, int item) {
    if (item < 0 || item >= block.toggleChildren.length) return;
    final controller = block.toggleChildren.removeAt(item);
    final focus = block.toggleChildFocus.removeAt(item);
    _lastTexts.remove(controller);
    controller.dispose();
    focus.dispose();
    if (item < block.toggleChildElements.length) block.toggleChildElements.removeAt(item);
    final parent = (block.element['children'] as List?) != null && (block.element['children'] as List).length > 1
        ? (block.element['children'] as List)[1]
        : null;
    final contentChildren = parent is Map ? parent['children'] : null;
    if (contentChildren is List && item < contentChildren.length) contentChildren.removeAt(item);
  }

  void _resetBlockFields(_SdocBlock block) {
    final text = block.text;
    if (text != null) {
      _lastTexts.remove(text);
      text.dispose();
    }
    for (final controller in block.children) {
      _lastTexts.remove(controller);
      controller.dispose();
    }
    block.toggleTitle?.dispose();
    for (final controller in block.toggleChildren) {
      _lastTexts.remove(controller);
      controller.dispose();
    }
    block.textFocus?.dispose();
    for (final focus in block.childFocus) {
      focus.dispose();
    }
    block.toggleTitleFocus?.dispose();
    for (final focus in block.toggleChildFocus) {
      focus.dispose();
    }
    block.text = null;
    block.textFocus = null;
    block.children = const [];
    block.childFocus = const [];
    block.childElements = const [];
    block.toggleTitle = null;
    block.toggleTitleFocus = null;
    block.toggleChildren = const [];
    block.toggleChildFocus = const [];
    block.toggleChildElements = const [];
  }

  void _saveTableText(dynamic node) {
    if (node is! Map) return;
    if (node['type'] == 'table_cell') {
      final id = node['id'] as String?;
      final controller = id == null ? null : _tableControllers[id];
      if (controller != null) _setNodeText(node.cast<String, dynamic>(), controller.text);
    }
    for (final child in (node['children'] as List?) ?? const []) {
      _saveTableText(child);
    }
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
        } else if (type == 'toggle_header') {
          final children = (block.element['children'] as List?)?.whereType<Map>().toList() ?? const [];
          if (children.isNotEmpty && block.toggleTitle != null) {
            _setNodeText(children.first.cast<String, dynamic>(), block.toggleTitle!.text);
          }
          if (children.length > 1) {
            final content = children[1]['children'];
            if (content is List) {
              final paragraphs = content.whereType<Map>().toList();
              for (var i = 0; i < block.toggleChildElements.length && i < block.toggleChildren.length; i++) {
                _setNodeText(block.toggleChildElements[i], block.toggleChildren[i].text);
              }
              for (var i = paragraphs.length; i < block.toggleChildren.length; i++) {
                content.add(_paragraphElement(block.toggleChildren[i].text));
              }
            }
          }
          block.element['collapsed'] = block.toggleCollapsed;
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
      for (final element in elements) {
        _saveTableText(element);
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
    if (block.deleted) return;
    final previous = block.type;
    final wasList = previous == 'unordered_list' || previous == 'ordered_list';
    if (!_isSimpleEditable(previous) && !wasList) return;
    final text = block.text?.text ?? (block.children.isNotEmpty ? block.children.first.text : _textOf(block.element));

    if (type == 'unordered_list' || type == 'ordered_list') {
      if (wasList) {
        setState(() {
          block.element['type'] = type;
          _dirty = true;
        });
      } else {
        final id = 'l-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
        final item = <String, dynamic>{
          'id': '$id-i',
          'type': 'list_item',
          'children': [_paragraphElement(text)..['id'] = '$id-p'],
        };
        _resetBlockFields(block);
        block.element
          ..['type'] = type
          ..['children'] = [item];
        final controller = TextEditingController(text: text);
        block.childElements = [item];
        block.children = [controller];
        block.childFocus = [FocusNode()];
        _watch(controller);
        setState(() => _dirty = true);
        _focusBlock(block, index, text.length);
      }
    } else if (type == 'code_block') {
      if (previous != 'code_block') {
        final id = '${block.element['id']}';
        final lines = text.split('\n');
        _resetBlockFields(block);
        block.element['children'] = [
          for (var i = 0; i < lines.length; i++)
            {
              'id': '$id-$i',
              'type': 'code_line',
              'children': [
                {'id': '$id-$i-t', 'text': lines[i]},
              ],
            },
        ];
        block.element['type'] = 'code_block';
        block.element['language'] = block.element['language'] ?? 'plaintext';
        block.text = TextEditingController(text: text);
        block.textFocus = FocusNode();
        _watch(block.text!);
        setState(() => _dirty = true);
        _focusBlock(block, index, text.length);
      }
    } else {
      _resetBlockFields(block);
      final leafId = _textLeafId(block.element);
      block.element['children'] = [
        {'id': leafId, 'text': text},
      ];
      block.element['type'] = type;
      if (type == 'check_list_item' && block.element['checked'] is! bool) {
        block.element['checked'] = false;
      }
      block.text = TextEditingController(text: text);
      block.textFocus = FocusNode();
      _watch(block.text!);
      setState(() => _dirty = true);
      _focusBlock(block, index, text.length);
    }
  }

  void _addBlock() {
    if (_readOnly) return;
    final block = _newParagraphBlock('');
    final index = _active == null ? _blocks.length : (_active! + 1).clamp(0, _blocks.length);
    setState(() {
      _blocks.insert(index, block);
      _active = index;
      _dirty = true;
    });
    _focusBlock(block, index, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    });
  }

  void _deleteBlock(int index) {
    if (_readOnly || _blocks.length <= 1) return;
    final removed = _blocks[index];
    final fields = _fields();
    _SdocField? before;
    _SdocField? after;
    for (final field in fields) {
      if (identical(field.block, removed)) continue;
      if (field.blockIndex < index) {
        before = field;
      } else if (after == null) {
        after = field;
      }
    }
    setState(() {
      removed.deleted = true;
      if (_active == index) _active = index > 0 ? index - 1 : 0;
      _dirty = true;
    });
    final target = before ?? after;
    if (target != null) _focusField(target, before != null ? target.controller.text.length : 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    return Column(
      children: [
        _header(l10n, workspace),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _content(l10n)),
              if (_commentsOpen)
                SdocCommentsPanel(
                  repo: widget.repo,
                  entry: widget.entry,
                  onClose: () => setState(() => _commentsOpen = false),
                ),
            ],
          ),
        ),
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
                IconAction(
                  icon: 'comment',
                  tooltip: l10n.zh ? '评论' : 'Comments',
                  size: 17,
                  onPressed: () => setState(() => _commentsOpen = !_commentsOpen),
                ),
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
      'title' => _textField(block, index, 28, FontWeight.w700, onTap: () => _setActive(index)),
      'paragraph' => _textField(block, index, 15, FontWeight.w400, onTap: () => _setActive(index)),
      'header1' => _textField(block, index, 26, FontWeight.w700, onTap: () => _setActive(index)),
      'header2' => _textField(block, index, 22, FontWeight.w600, onTap: () => _setActive(index)),
      'header3' => _textField(block, index, 18, FontWeight.w600, onTap: () => _setActive(index)),
      'header4' || 'header5' || 'header6' => _textField(block, index, 16, FontWeight.w600, onTap: () => _setActive(index)),
      'code_block' => _codeView(block, index),
      'unordered_list' || 'ordered_list' => _listView(block, index),
      'check_list_item' => _checkView(block, index),
      'quote' => _quoteView(block, index),
      'callout' => _calloutView(block, index),
      'table' => _tableView(block),
      'image_block' => _imageView(block),
      'video' => _videoView(block),
      'embed_link' => _embedView(block),
      'formula' => _formulaView(block),
      'toggle_header' => _toggleView(block, index),
      'multi_column' => _multiColumnView(block),
      _ => _unknownView(block),
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

  Widget _keyboard(_SdocField field, Widget child) {
    if (_readOnly) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => _onKey(field, event),
      child: child,
    );
  }

  Widget _textField(_SdocBlock block, int index, double size, FontWeight weight, {required VoidCallback onTap}) {
    final controller = block.text;
    final focus = block.textFocus;
    if (controller == null || focus == null) return const SizedBox.shrink();
    final field = _SdocField(
      block: block,
      blockIndex: index,
      kind: block.type == 'code_block' ? _SdocFieldKind.code : _SdocFieldKind.simple,
      controller: controller,
      focus: focus,
    );
    return _keyboard(
      field,
      TextField(
        controller: controller,
        focusNode: focus,
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
      ),
    );
  }

  Widget _codeView(_SdocBlock block, int index) {
    final controller = block.text;
    final focus = block.textFocus;
    if (controller == null || focus == null) return const SizedBox.shrink();
    final field = _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.code, controller: controller, focus: focus);
    return GestureDetector(
      onTap: () => _setActive(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
        child: _keyboard(
          field,
          TextField(
            controller: controller,
            focusNode: focus,
            onTap: () => _setActive(index),
            enabled: !_readOnly,
            maxLines: null,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.6),
            decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          ),
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
                    child: i < block.childFocus.length
                        ? _keyboard(
                            _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.listItem, controller: block.children[i], focus: block.childFocus[i], item: i),
                            TextField(
                              controller: block.children[i],
                              focusNode: block.childFocus[i],
                              onTap: () => _setActive(index),
                              enabled: !_readOnly,
                              maxLines: null,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                              decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 3)),
                            ),
                          )
                        : const SizedBox.shrink(),
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
        Expanded(child: _textField(block, index, 15, FontWeight.w400, onTap: () => _setActive(index))),
      ],
    );
  }

  Widget _quoteView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 3))),
      child: _textField(block, index, 15, FontWeight.w400, onTap: () => _setActive(index)),
    );
  }

  Widget _calloutView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFEF7E0), borderRadius: BorderRadius.circular(5)),
      child: Column(
        children: [
          for (var i = 0; i < block.children.length; i++)
            if (i < block.childFocus.length)
              _keyboard(
                _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.calloutChild, controller: block.children[i], focus: block.childFocus[i], item: i),
                TextField(
                  controller: block.children[i],
                  focusNode: block.childFocus[i],
                  onTap: () => _setActive(index),
                  enabled: !_readOnly,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14.5, height: 1.6),
                  decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 3)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _toggleView(_SdocBlock block, int index) {
    final title = block.toggleTitle;
    final titleFocus = block.toggleTitleFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => block.toggleCollapsed = !block.toggleCollapsed),
                icon: Transform.rotate(
                  angle: block.toggleCollapsed ? -1.57 : 0,
                  child: const WebIcon('arrow-down', size: 12, color: AppColors.textSecondary),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: title != null && titleFocus != null
                    ? _keyboard(
                        _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.toggleTitle, controller: title, focus: titleFocus),
                        TextField(
                          controller: title,
                          focusNode: titleFocus,
                          onTap: () => _setActive(index),
                          enabled: !_readOnly,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4)),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (!block.toggleCollapsed)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Column(
                children: [
                  for (var i = 0; i < block.toggleChildren.length; i++)
                    if (i < block.toggleChildFocus.length)
                      _keyboard(
                        _SdocField(block: block, blockIndex: index, kind: _SdocFieldKind.toggleChild, controller: block.toggleChildren[i], focus: block.toggleChildFocus[i], item: i),
                        TextField(
                          controller: block.toggleChildren[i],
                          focusNode: block.toggleChildFocus[i],
                          onTap: () => _setActive(index),
                          enabled: !_readOnly,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14.5, height: 1.55),
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

  Widget _multiColumnView(_SdocBlock block) {
    final columns = (block.element['children'] as List?)?.whereType<Map>().toList() ?? const [];
    if (columns.isEmpty) return _unknownView(block);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
                child: Text(
                  _textOf(columns[i]).trim().isEmpty ? '—' : _textOf(columns[i]),
                  style: const TextStyle(fontSize: 12.5, height: 1.55),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _unknownView(_SdocBlock block) {
    final text = _textOf(block.element).trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: [
          const WebIcon('info', size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? block.type : '$text  ·  ${block.type}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
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
                        child: TextField(
                          controller: _controllerForCell(cell),
                          enabled: !_readOnly,
                          maxLines: null,
                          style: const TextStyle(fontSize: 13, height: 1.45),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
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

  Widget _videoView(_SdocBlock block) {
    final data = block.element['data'];
    final name = data is Map ? (data['name'] as String? ?? '') : '';
    final src = data is Map ? (data['src'] as String? ?? '') : '';
    final embeddable = data is Map && data['is_embeddable_link'] == true;
    final size = data is Map ? (data['size'] as num?)?.toInt() : null;
    final opening = _openingVideos.contains(src);
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: [
          const WebIcon('play-filled', size: 28, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name.isEmpty ? (l10n.zh ? '视频' : 'Video') : name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                if (size != null) ...[
                  const SizedBox(height: 3),
                  Text(_formatSize(size), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (opening)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            OutlinedButton.icon(
              onPressed: () => embeddable ? _openLink(src) : _openVideo(block, src, name),
              icon: Icon(embeddable ? Icons.open_in_new : Icons.play_arrow, size: 15),
              label: Text(embeddable ? (l10n.zh ? '打开链接' : 'Open link') : (l10n.zh ? '播放' : 'Play')),
            ),
        ],
      ),
    );
  }

  Widget _embedView(_SdocBlock block) {
    final link = block.element['link'] as String? ?? '';
    final type = block.element['link_type'] as String? ?? '';
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: [
          const WebIcon('link', size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type.isNotEmpty) Text(type.toUpperCase(), style: const TextStyle(fontSize: 10.5, color: AppColors.muted, letterSpacing: .4)),
                const SizedBox(height: 2),
                Text(link, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.text)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: link.isEmpty ? null : () => _openLink(link),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: Text(l10n.zh ? '打开' : 'Open'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String link) async {
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openVideo(_SdocBlock block, String src, String name) async {
    if (src.isEmpty) return;
    setState(() => _openingVideos.add(src));
    try {
      final bytes = await context.read<AppSession>().api!.loadSdocVideo(widget.repo.id, widget.entry.path, src);
      final temp = await getTemporaryDirectory();
      final dir = Directory(p.join(temp.path, 'seafile-sdoc-video'));
      await dir.create(recursive: true);
      final safeName = name.isEmpty ? src.split('/').last : name;
      final file = File(p.join(dir.path, safeName));
      await file.writeAsBytes(bytes, flush: true);
      if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', file.path], runInShell: true);
      } else {
        await Process.run('xdg-open', [file.path]);
      }
    } catch (error) {
      if (mounted) showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _openingVideos.remove(src));
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Widget _formulaView(_SdocBlock block) {
    final data = block.element['data'];
    final formula = data is Map ? data['formula'] : null;
    if (formula is! String || formula.trim().isEmpty) return _mediaPlaceholder('公式', 'Formula');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FA), borderRadius: BorderRadius.circular(5)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          formula,
          mathStyle: MathStyle.display,
          textStyle: const TextStyle(fontSize: 18, color: AppColors.text),
          onErrorFallback: (error) => Text(formula, style: const TextStyle(fontFamily: 'Menlo', fontSize: 13)),
        ),
      ),
    );
  }

  Widget _imageView(_SdocBlock block) {
    String? src;
    void find(dynamic node) {
      if (src != null || node is! Map) return;
      if (node['type'] == 'image' && node['data'] is Map) {
        final value = (node['data'] as Map)['src'];
        if (value is String && value.isNotEmpty) src = value;
      }
      for (final child in (node['children'] as List?) ?? const []) {
        find(child);
      }
    }

    find(block.element);
    final value = src;
    if (value == null) return _mediaPlaceholder('图片', 'Image');
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(value, fit: BoxFit.contain, height: 280, errorBuilder: (_, __, ___) => _mediaPlaceholder('图片加载失败', 'Image unavailable')),
      );
    }
    final future = _imageCache.putIfAbsent(value, () => context.read<AppSession>().api!.loadSdocImage(widget.repo.id, widget.entry.path, value));
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _mediaPlaceholder('图片加载失败', 'Image unavailable');
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.memory(snapshot.data!, fit: BoxFit.contain, height: 280),
        );
      },
    );
  }

  TextEditingController _controllerForCell(Map cell) {
    final id = (cell['id'] as String?) ?? 'cell-${_idSeed++}';
    return _tableControllers.putIfAbsent(id, () {
      final controller = TextEditingController(text: _plainNode(cell));
      _watch(controller);
      return controller;
    });
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
