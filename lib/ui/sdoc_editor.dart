import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import 'editor_menus.dart';
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

class _SdocTextStyle {
  const _SdocTextStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.code = false,
    this.superscript = false,
    this.subscript = false,
    this.color,
    this.highlight,
    this.fontSize,
    this.font,
    this.link,
  });

  static const none = _SdocTextStyle();

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool code;
  final bool superscript;
  final bool subscript;
  final String? color;
  final String? highlight;
  final double? fontSize;
  final String? font;
  final String? link;

  bool get isEmpty =>
      !bold &&
      !italic &&
      !underline &&
      !strikethrough &&
      !code &&
      !superscript &&
      !subscript &&
      color == null &&
      highlight == null &&
      fontSize == null &&
      font == null &&
      link == null;

  _SdocTextStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? code,
    bool? superscript,
    bool? subscript,
    String? color,
    String? highlight,
    double? fontSize,
    String? font,
    String? link,
  }) {
    return _SdocTextStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      code: code ?? this.code,
      superscript: superscript ?? this.superscript,
      subscript: subscript ?? this.subscript,
      color: color ?? this.color,
      highlight: highlight ?? this.highlight,
      fontSize: fontSize ?? this.fontSize,
      font: font ?? this.font,
      link: link ?? this.link,
    );
  }

  _SdocTextStyle withFont(String? value) => _SdocTextStyle(
    bold: bold,
    italic: italic,
    underline: underline,
    strikethrough: strikethrough,
    code: code,
    superscript: superscript,
    subscript: subscript,
    color: color,
    highlight: highlight,
    fontSize: fontSize,
    font: value,
    link: link,
  );

  _SdocTextStyle withColor(String? value) => _SdocTextStyle(
    bold: bold,
    italic: italic,
    underline: underline,
    strikethrough: strikethrough,
    code: code,
    superscript: superscript,
    subscript: subscript,
    color: value,
    highlight: highlight,
    fontSize: fontSize,
    font: font,
    link: link,
  );

  _SdocTextStyle withHighlight(String? value) => _SdocTextStyle(
    bold: bold,
    italic: italic,
    underline: underline,
    strikethrough: strikethrough,
    code: code,
    superscript: superscript,
    subscript: subscript,
    color: color,
    highlight: value,
    fontSize: fontSize,
    font: font,
    link: link,
  );

  _SdocTextStyle withLink(String? value) => _SdocTextStyle(
    bold: bold,
    italic: italic,
    underline: underline,
    strikethrough: strikethrough,
    code: code,
    superscript: superscript,
    subscript: subscript,
    color: color,
    highlight: highlight,
    fontSize: fontSize,
    font: font,
    link: value,
  );

  factory _SdocTextStyle.fromLeaf(Map node) {
    double? size;
    final rawSize = node['font_size'];
    if (rawSize is num) {
      size = rawSize.toDouble();
    } else if (rawSize is String) {
      size = double.tryParse(rawSize.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return _SdocTextStyle(
      bold: node['bold'] == true,
      italic: node['italic'] == true,
      underline: node['underline'] == true,
      strikethrough: node['strikethrough'] == true,
      code: node['code'] == true,
      superscript: node['superscript'] == true,
      subscript: node['subscript'] == true,
      color: node['color'] is String ? node['color'] as String : null,
      highlight: node['highlight_color'] is String
          ? node['highlight_color'] as String
          : null,
      fontSize: size,
      font: node['font'] is String ? node['font'] as String : null,
      link: node['link'] is String ? node['link'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (underline) 'underline': true,
    if (strikethrough) 'strikethrough': true,
    if (code) 'code': true,
    if (superscript) 'superscript': true,
    if (subscript) 'subscript': true,
    if (color != null) 'color': color,
    if (highlight != null) 'highlight_color': highlight,
    if (fontSize != null) 'font_size': fontSize,
    if (font != null) 'font': font,
    if (link != null) 'link': link,
  };

  TextStyle apply(TextStyle base) {
    var style = base;
    if (bold) style = style.copyWith(fontWeight: FontWeight.w700);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (underline || strikethrough) {
      style = style.copyWith(
        decoration: TextDecoration.combine([
          if (underline) TextDecoration.underline,
          if (strikethrough) TextDecoration.lineThrough,
        ]),
      );
    }
    if (superscript || subscript) {
      style = style.copyWith(
        fontSize: (style.fontSize ?? 15) * 0.72,
        fontFeatures: [
          superscript
              ? const FontFeature.superscripts()
              : const FontFeature.subscripts(),
        ],
      );
    }
    if (code) {
      style = style.copyWith(
        fontFamily: 'Menlo',
        backgroundColor: const Color(0xFFF1F3F5),
        color: const Color(0xFFC7254E),
      );
    }
    if (color != null) style = style.copyWith(color: _parseHexColor(color!));
    if (highlight != null)
      style = style.copyWith(backgroundColor: _parseHexColor(highlight!));
    if (fontSize != null) style = style.copyWith(fontSize: fontSize);
    if (font != null) style = style.copyWith(fontFamily: font);
    if (link != null) {
      style = style.copyWith(
        color: _parseHexColor('#1a73e8'),
        decoration: TextDecoration.underline,
      );
    }
    return style;
  }

  static Color? _parseHexColor(String value) {
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 3) hex = hex.split('').map((char) => '$char$char').join();
    if (hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  @override
  bool operator ==(Object other) {
    return other is _SdocTextStyle &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough &&
        other.code == code &&
        other.superscript == superscript &&
        other.subscript == subscript &&
        other.color == color &&
        other.highlight == highlight &&
        other.fontSize == fontSize &&
        other.font == font &&
        other.link == link;
  }

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    underline,
    strikethrough,
    code,
    superscript,
    subscript,
    color,
    highlight,
    fontSize,
    font,
    link,
  );
}

class _SdocTextController extends TextEditingController {
  _SdocTextController({String text = '', List<_SdocTextStyle>? styles})
    : _styles = styles != null && styles.length == text.length
          ? List.of(styles)
          : List.filled(text.length, _SdocTextStyle.none),
      super(text: text);

  factory _SdocTextController.fromNode(dynamic node) {
    final buffer = StringBuffer();
    final styles = <_SdocTextStyle>[];
    void visit(dynamic value) {
      if (value is Map) {
        final text = value['text'];
        if (text is String) {
          buffer.write(text);
          styles.addAll(
            List.filled(text.length, _SdocTextStyle.fromLeaf(value)),
          );
        }
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

    visit(node is Map ? node['children'] : node);
    return _SdocTextController(text: buffer.toString(), styles: styles);
  }

  List<_SdocTextStyle> _styles;
  TextSelection? _lastRange;

  @override
  set value(TextEditingValue newValue) {
    final oldText = super.value.text;
    if (oldText != newValue.text) {
      _styles = _diffStyles(oldText, _styles, newValue.text);
    }
    final selection = newValue.selection;
    if (selection.isValid && !selection.isCollapsed) _lastRange = selection;
    super.value = newValue;
  }

  TextSelection? get _formatRange {
    final current = selection;
    if (current.isValid && !current.isCollapsed) return current;
    final last = _lastRange;
    if (last != null && last.end <= text.length) return last;
    return null;
  }

  static List<_SdocTextStyle> _diffStyles(
    String oldText,
    List<_SdocTextStyle> oldStyles,
    String newText,
  ) {
    var prefix = 0;
    final maxPrefix = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldText.length - prefix &&
        suffix < newText.length - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix++;
    }
    final inserted = newText.length - prefix - suffix;
    final inherited = prefix > 0
        ? oldStyles[prefix - 1]
        : (oldStyles.isNotEmpty ? oldStyles.first : _SdocTextStyle.none);
    return [
      ...oldStyles.sublist(0, prefix),
      ...List.filled(inserted, inherited),
      ...oldStyles.sublist(oldText.length - suffix),
    ];
  }

  void toggleMark(
    _SdocTextStyle Function(_SdocTextStyle) toggle, {
    bool allIfCollapsed = false,
  }) {
    final range = _formatRange;
    if (range == null && !allIfCollapsed) return;
    final start = range == null ? 0 : range.start.clamp(0, text.length);
    final end = range == null ? text.length : range.end.clamp(0, text.length);
    for (var i = start; i < end; i++) {
      _styles[i] = toggle(_styles[i]);
    }
    notifyListeners();
  }

  void clearMarks() {
    final range = _formatRange;
    final start = range == null ? 0 : range.start.clamp(0, text.length);
    final end = range == null ? text.length : range.end.clamp(0, text.length);
    for (var i = start; i < end; i++) {
      _styles[i] = _SdocTextStyle.none;
    }
    notifyListeners();
  }

  _SdocTextController cutAt(int offset) {
    final safe = offset.clamp(0, text.length);
    final tail = _SdocTextController(
      text: text.substring(safe),
      styles: _styles.sublist(safe),
    );
    value = TextEditingValue(
      text: text.substring(0, safe),
      selection: TextSelection.collapsed(offset: safe),
    );
    return tail;
  }

  void appendWith(_SdocTextController other) {
    final offset = text.length;
    final next = '$text${other.text}';
    final nextStyles = [..._styles, ...other._styles];
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _styles = nextStyles;
    if (text.length == offset)
      selection = TextSelection.collapsed(offset: offset);
    notifyListeners();
  }

  List<Map<String, dynamic>> toChildren(String prefix) {
    if (text.isEmpty) {
      return [
        {'id': '$prefix-0', 'text': ''},
      ];
    }
    final children = <Map<String, dynamic>>[];
    var start = 0;
    var run = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || _styles[i] != _styles[start]) {
        children.add({
          'id': '$prefix-$run',
          'text': text.substring(start, i),
          ..._styles[start].toJson(),
        });
        start = i;
        run++;
      }
    }
    return children;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(text: '', style: base);
    final children = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || _styles[i] != _styles[start]) {
        children.add(
          TextSpan(
            text: text.substring(start, i),
            style: _styles[start].apply(base),
          ),
        );
        start = i;
      }
    }
    return TextSpan(style: base, children: children);
  }
}

enum _SdocFieldKind {
  simple,
  code,
  listItem,
  calloutChild,
  toggleTitle,
  toggleChild,
}

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
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  Timer? _historyTimer;
  Timer? _autoSaveTimer;
  String _lastSnapshot = '';
  String? _savedSnapshot;
  DateTime? _lastSavedAt;
  bool _restoring = false;
  Map<String, dynamic>? _document;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  int? _active;
  int _idSeed = 0;

  bool get isDirty => _dirty;
  bool get canUndo =>
      _undoStack.isNotEmpty || (_dirty && _lastSnapshot.isNotEmpty);
  bool get canRedo => _redoStack.isNotEmpty;
  bool get _readOnly => widget.entry.isReadOnly || widget.repo.isReadOnly;

  @override
  void initState() {
    super.initState();
    _lastSavedAt = widget.entry.mtime;
    _load();
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _autoSaveTimer?.cancel();
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
      final document = await context.read<AppSession>().api!.loadSdocDocument(
        widget.repo.id,
        widget.entry.path,
      );
      if (!mounted) return;
      _document = document;
      _buildBlocks(document);
      _lastSnapshot = _snapshotNow();
      _savedSnapshot = _lastSnapshot;
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
    final elements =
        (document['elements'] as List?)
            ?.whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList() ??
        [];
    for (final element in elements) {
      final block = _SdocBlock(element);
      final type = block.type;
      if (type == 'unordered_list' || type == 'ordered_list') {
        final children =
            (element['children'] as List?)
                ?.whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList() ??
            [];
        block.childElements = children;
        block.children = [
          for (final child in children) _SdocTextController.fromNode(child),
        ];
        block.childFocus = [for (final _ in children) FocusNode()];
        for (final controller in block.children) {
          _watch(controller);
        }
      } else if (type == 'callout') {
        final children =
            (element['children'] as List?)
                ?.whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList() ??
            [];
        block.childElements = children;
        block.children = [
          for (final child in children) _SdocTextController.fromNode(child),
        ];
        block.childFocus = [for (final _ in children) FocusNode()];
        for (final controller in block.children) {
          _watch(controller);
        }
      } else if (type == 'toggle_header') {
        final children =
            (element['children'] as List?)
                ?.whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList() ??
            [];
        final titleElement = children.isNotEmpty ? children.first : null;
        final contentElement = children.length > 1 ? children[1] : null;
        block.toggleCollapsed = element['collapsed'] == true;
        block.toggleTitle = titleElement == null
            ? _SdocTextController()
            : _SdocTextController.fromNode(titleElement);
        block.toggleTitleFocus = FocusNode();
        _watch(block.toggleTitle!);
        final contentChildren =
            (contentElement?['children'] as List?)
                ?.whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList() ??
            [];
        block.toggleChildElements = contentChildren;
        block.toggleChildren = [
          for (final child in contentChildren)
            _SdocTextController.fromNode(child),
        ];
        block.toggleChildFocus = [for (final _ in contentChildren) FocusNode()];
        for (final controller in block.toggleChildren) {
          _watch(controller);
        }
      } else if (_isSimpleEditable(type)) {
        block.text = _SdocTextController(text: _textOf(element));
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

  _SdocBlock _newParagraphBlock(
    String text, {
    TextEditingController? controller,
  }) {
    final block = _SdocBlock(_paragraphElement(text));
    block.text = controller ?? _SdocTextController(text: text);
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
    if (_readOnly) return;
    if (!_dirty) {
      setState(_changed);
    } else {
      _scheduleAutoSave();
      _scheduleHistory();
    }
  }

  void _changed() {
    if (_readOnly) return;
    _dirty = true;
    _scheduleAutoSave();
    _scheduleHistory();
  }

  void _scheduleAutoSave() {
    if (_readOnly) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) unawaited(save(auto: true));
    });
  }

  void _scheduleHistory() {
    if (_readOnly || _restoring) return;
    _historyTimer?.cancel();
    _historyTimer = Timer(
      const Duration(milliseconds: 600),
      _commitTextHistory,
    );
  }

  void _commitTextHistory() {
    if (!mounted) return;
    final current = _snapshotNow();
    if (current == _lastSnapshot) return;
    _undoStack.add(_lastSnapshot);
    _trimHistory();
    _redoStack.clear();
    _lastSnapshot = current;
    setState(() {});
  }

  void _trimHistory() {
    if (_undoStack.length > 100)
      _undoStack.removeRange(0, _undoStack.length - 100);
  }

  void _undo() {
    _historyTimer?.cancel();
    final current = _snapshotNow();
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
    final current = _snapshotNow();
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
    if (_document == null) return;
    _restoring = true;
    for (final block in _blocks) {
      _disposeBlock(block);
    }
    for (final controller in _tableControllers.values) {
      controller.dispose();
    }
    _blocks.clear();
    _tableControllers.clear();
    _lastTexts.clear();
    final elements = (jsonDecode(source) as List)
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    _document!['elements'] = elements;
    _buildBlocks(_document!);
    _active = _blocks.isEmpty ? null : 0;
    _lastSnapshot = _snapshotNow();
    _dirty = _lastSnapshot != _savedSnapshot;
    _restoring = false;
    setState(() {});
    _scheduleAutoSave();
  }

  String _snapshotNow() {
    if (_blocks.isEmpty) return _savedSnapshot ?? '';
    return jsonEncode(_composeElements());
  }

  String _formatSavedTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
        for (
          var j = 0;
          j < block.children.length && j < block.childFocus.length;
          j++
        ) {
          fields.add(
            _SdocField(
              block: block,
              blockIndex: i,
              kind: _SdocFieldKind.listItem,
              controller: block.children[j],
              focus: block.childFocus[j],
              item: j,
            ),
          );
        }
      } else if (type == 'callout') {
        for (
          var j = 0;
          j < block.children.length && j < block.childFocus.length;
          j++
        ) {
          fields.add(
            _SdocField(
              block: block,
              blockIndex: i,
              kind: _SdocFieldKind.calloutChild,
              controller: block.children[j],
              focus: block.childFocus[j],
              item: j,
            ),
          );
        }
      } else if (type == 'toggle_header') {
        if (block.toggleTitle != null && block.toggleTitleFocus != null) {
          fields.add(
            _SdocField(
              block: block,
              blockIndex: i,
              kind: _SdocFieldKind.toggleTitle,
              controller: block.toggleTitle!,
              focus: block.toggleTitleFocus!,
            ),
          );
        }
        if (!block.toggleCollapsed) {
          for (
            var j = 0;
            j < block.toggleChildren.length &&
                j < block.toggleChildFocus.length;
            j++
          ) {
            fields.add(
              _SdocField(
                block: block,
                blockIndex: i,
                kind: _SdocFieldKind.toggleChild,
                controller: block.toggleChildren[j],
                focus: block.toggleChildFocus[j],
                item: j,
              ),
            );
          }
        }
      } else if (_isSimpleEditable(type) &&
          block.text != null &&
          block.textFocus != null) {
        fields.add(
          _SdocField(
            block: block,
            blockIndex: i,
            kind: type == 'code_block'
                ? _SdocFieldKind.code
                : _SdocFieldKind.simple,
            controller: block.text!,
            focus: block.textFocus!,
          ),
        );
      }
    }
    return fields;
  }

  int _fieldPosition(List<_SdocField> fields, _SdocField field) {
    for (var i = 0; i < fields.length; i++) {
      if (identical(fields[i].focus, field.focus) &&
          identical(fields[i].controller, field.controller))
        return i;
    }
    return -1;
  }

  _SdocField? _previousField(_SdocField field) {
    final fields = _fields();
    final position = _fieldPosition(fields, field);
    if (position <= 0) return null;
    final previous = fields[position - 1];
    if (previous.blockIndex != field.blockIndex &&
        previous.blockIndex != field.blockIndex - 1)
      return null;
    return previous;
  }

  _SdocField? _nextField(_SdocField field) {
    final fields = _fields();
    final position = _fieldPosition(fields, field);
    if (position < 0 || position >= fields.length - 1) return null;
    final next = fields[position + 1];
    if (next.blockIndex != field.blockIndex &&
        next.blockIndex != field.blockIndex + 1)
      return null;
    return next;
  }

  _SdocField? _firstFieldOfBlock(_SdocBlock block, int index) {
    final type = block.type;
    if (_isSimpleEditable(type) &&
        block.text != null &&
        block.textFocus != null) {
      return _SdocField(
        block: block,
        blockIndex: index,
        kind: type == 'code_block'
            ? _SdocFieldKind.code
            : _SdocFieldKind.simple,
        controller: block.text!,
        focus: block.textFocus!,
      );
    }
    if ((type == 'unordered_list' ||
            type == 'ordered_list' ||
            type == 'callout') &&
        block.children.isNotEmpty &&
        block.childFocus.isNotEmpty) {
      return _SdocField(
        block: block,
        blockIndex: index,
        kind: type == 'callout'
            ? _SdocFieldKind.calloutChild
            : _SdocFieldKind.listItem,
        controller: block.children.first,
        focus: block.childFocus.first,
      );
    }
    if (type == 'toggle_header' &&
        block.toggleTitle != null &&
        block.toggleTitleFocus != null) {
      return _SdocField(
        block: block,
        blockIndex: index,
        kind: _SdocFieldKind.toggleTitle,
        controller: block.toggleTitle!,
        focus: block.toggleTitleFocus!,
      );
    }
    return null;
  }

  void _focusField(_SdocField field, int offset) {
    setState(() => _active = field.blockIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      field.focus.requestFocus();
      field.controller.selection = TextSelection.collapsed(
        offset: offset.clamp(0, field.controller.text.length),
      );
    });
  }

  void _focusBlock(_SdocBlock block, int index, int offset) {
    final field = _firstFieldOfBlock(block, index);
    if (field != null) _focusField(field, offset);
  }

  KeyEventResult _onKey(_SdocField field, KeyEvent event) {
    if (_readOnly) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final value = field.controller.value;
    if (value.composing.isValid) return KeyEventResult.ignored;
    final selection = value.selection;
    if (!selection.isValid) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final text = value.text;
    final command =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (command && key == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
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

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed)
        return KeyEventResult.ignored;
      if (field.kind == _SdocFieldKind.code) return KeyEventResult.ignored;
      _handleEnter(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (!selection.isCollapsed || selection.start != 0)
        return KeyEventResult.ignored;
      if (field.kind == _SdocFieldKind.toggleTitle)
        return KeyEventResult.ignored;
      _handleBackspace(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      if (!selection.isCollapsed || selection.start != text.length)
        return KeyEventResult.ignored;
      _handleDelete(field);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp &&
        selection.isCollapsed &&
        selection.start == 0) {
      final previous = _previousField(field);
      if (previous != null) {
        _focusField(previous, previous.controller.text.length);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown &&
        selection.isCollapsed &&
        selection.start == text.length) {
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
        if (field.kind == _SdocFieldKind.simple &&
            block.type != 'paragraph' &&
            block.type != 'title') {
          setState(() {
            block.element['type'] = 'paragraph';
            _changed();
          });
        }
        return;
      }
      final previous = _previousField(field);
      final next = _nextField(field);
      setState(() {
        _removeField(field);
        _changed();
      });
      final target = previous ?? next;
      if (target != null) {
        _focusField(
          target,
          previous != null ? target.controller.text.length : 0,
        );
      }
      return;
    }
    final previous = _previousField(field);
    if (previous == null) return;
    final offset = previous.controller.text.length;
    final newline =
        previous.kind == _SdocFieldKind.code ||
        field.kind == _SdocFieldKind.code;
    _appendController(previous.controller, controller, newline: newline);
    setState(() {
      _removeField(field);
      _changed();
    });
    _focusField(previous, offset);
  }

  void _handleDelete(_SdocField field) {
    final next = _nextField(field);
    if (next == null || next.kind == _SdocFieldKind.toggleTitle) return;
    final offset = field.controller.text.length;
    final newline =
        next.kind == _SdocFieldKind.code || field.kind == _SdocFieldKind.code;
    _appendController(field.controller, next.controller, newline: newline);
    setState(() {
      _removeField(next);
      _changed();
    });
    _focusField(field, offset);
  }

  TextEditingController _cutController(
    TextEditingController controller,
    int offset,
  ) {
    if (controller is _SdocTextController) return controller.cutAt(offset);
    final after = controller.text.substring(offset);
    controller.text = controller.text.substring(0, offset);
    return _SdocTextController(text: after);
  }

  void _appendController(
    TextEditingController target,
    TextEditingController source, {
    bool newline = false,
  }) {
    if (target is _SdocTextController && source is _SdocTextController) {
      if (newline && target.text.isNotEmpty) {
        target.appendWith(_SdocTextController(text: '\n'));
      }
      target.appendWith(source);
      return;
    }
    target.text =
        '${target.text}${newline && target.text.isNotEmpty ? '\n' : ''}${source.text}';
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
          _changed();
        });
        return;
      }
      _insertParagraphAfter(index, '');
      return;
    }
    final newType = switch (block.type) {
      'quote' => 'quote',
      'check_list_item' => 'check_list_item',
      _ => 'paragraph',
    };
    final afterController = _cutController(controller, caret);
    final newBlock = _newTextBlock(newType, after, controller: afterController);
    setState(() {
      _blocks.insert(index + 1, newBlock);
      _active = index + 1;
      _changed();
    });
    _focusBlock(newBlock, index + 1, 0);
  }

  _SdocBlock _newTextBlock(
    String type,
    String text, {
    TextEditingController? controller,
  }) {
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
    block.text = controller ?? _SdocTextController(text: text);
    block.textFocus = FocusNode();
    _watch(block.text!);
    return block;
  }

  void _insertParagraphAfter(
    int index,
    String text, {
    TextEditingController? controller,
  }) {
    final block = _newParagraphBlock(text, controller: controller);
    setState(() {
      _blocks.insert(index + 1, block);
      _active = index + 1;
      _changed();
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
          _changed();
        });
        _focusBlock(replacement, field.blockIndex, 0);
      } else {
        final index = field.blockIndex;
        setState(() {
          _removeListItem(block, field.item);
          _changed();
        });
        _insertParagraphAfter(index, '');
      }
      return;
    }
    final item = field.item;
    final newController = _cutController(controller, caret);
    final id = 'l-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final element = <String, dynamic>{
      'id': id,
      'type': 'list_item',
      'children': [_paragraphElement(after)..['id'] = '$id-p'],
    };
    final list = block.element['children'];
    if (list is List) list.insert(item + 1, element);
    final newFocus = FocusNode();
    block.childElements.insert(item + 1, element);
    block.children.insert(item + 1, newController);
    block.childFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(_changed);
    _focusField(
      _SdocField(
        block: block,
        blockIndex: field.blockIndex,
        kind: _SdocFieldKind.listItem,
        controller: newController,
        focus: newFocus,
        item: item + 1,
      ),
      0,
    );
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
    final item = field.item;
    final newController = _cutController(controller, caret);
    final element = _paragraphElement(after);
    final list = block.element['children'];
    if (list is List) list.insert(item + 1, element);
    final newFocus = FocusNode();
    block.childElements.insert(item + 1, element);
    block.children.insert(item + 1, newController);
    block.childFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(_changed);
    _focusField(
      _SdocField(
        block: block,
        blockIndex: field.blockIndex,
        kind: _SdocFieldKind.calloutChild,
        controller: newController,
        focus: newFocus,
        item: item + 1,
      ),
      0,
    );
  }

  void _splitToggleTitle(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final after = text.substring(caret);
    final afterController = _cutController(controller, caret);
    if (after.isEmpty && block.toggleChildren.isNotEmpty) {
      if (block.toggleCollapsed) {
        setState(() {
          block.toggleCollapsed = false;
          _changed();
        });
      }
      _focusField(
        _SdocField(
          block: block,
          blockIndex: field.blockIndex,
          kind: _SdocFieldKind.toggleChild,
          controller: block.toggleChildren.first,
          focus: block.toggleChildFocus.first,
        ),
        0,
      );
      return;
    }
    _insertParagraphAfter(field.blockIndex, after, controller: afterController);
  }

  void _splitToggleChild(_SdocField field) {
    final block = field.block;
    final controller = field.controller;
    final text = controller.text;
    final caret = controller.selection.start.clamp(0, text.length);
    final after = text.substring(caret);
    final content =
        (block.element['children'] as List?) != null &&
            (block.element['children'] as List).length > 1
        ? (block.element['children'] as List)[1]
        : null;
    final contentChildren = content is Map ? content['children'] : null;
    if (contentChildren is! List) {
      final afterController = _cutController(controller, caret);
      _insertParagraphAfter(
        field.blockIndex,
        after,
        controller: afterController,
      );
      return;
    }
    final newController = _cutController(controller, caret);
    final element = _paragraphElement(after);
    final item = field.item;
    contentChildren.insert(item + 1, element);
    final newFocus = FocusNode();
    block.toggleChildElements.insert(item + 1, element);
    block.toggleChildren.insert(item + 1, newController);
    block.toggleChildFocus.insert(item + 1, newFocus);
    _watch(newController);
    setState(_changed);
    _focusField(
      _SdocField(
        block: block,
        blockIndex: field.blockIndex,
        kind: _SdocFieldKind.toggleChild,
        controller: newController,
        focus: newFocus,
        item: item + 1,
      ),
      0,
    );
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
    if (item < block.toggleChildElements.length)
      block.toggleChildElements.removeAt(item);
    final parent =
        (block.element['children'] as List?) != null &&
            (block.element['children'] as List).length > 1
        ? (block.element['children'] as List)[1]
        : null;
    final contentChildren = parent is Map ? parent['children'] : null;
    if (contentChildren is List && item < contentChildren.length)
      contentChildren.removeAt(item);
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

  void _setNodeChildren(
    Map<String, dynamic> node,
    TextEditingController controller,
  ) {
    if (controller is _SdocTextController) {
      final runs = controller.toChildren(node['id'] as String? ?? 'run');
      if (_replaceTextChildren(node, runs)) return;
    }
    _setNodeText(node, controller.text);
  }

  bool _replaceTextChildren(dynamic node, List<Map<String, dynamic>> runs) {
    if (node is! Map) return false;
    final children = node['children'];
    if (children is! List) return false;
    if (children.any((child) => child is Map && child['text'] is String)) {
      node['children'] = runs;
      return true;
    }
    for (final child in children) {
      if (_replaceTextChildren(child, runs)) return true;
    }
    return false;
  }

  void _saveTableText(dynamic node) {
    if (node is! Map) return;
    if (node['type'] == 'table_cell') {
      final id = node['id'] as String?;
      final controller = id == null ? null : _tableControllers[id];
      if (controller != null)
        _setNodeChildren(node.cast<String, dynamic>(), controller);
    }
    for (final child in (node['children'] as List?) ?? const []) {
      _saveTableText(child);
    }
  }

  List<Map<String, dynamic>> _composeElements() {
    final elements = <Map<String, dynamic>>[];
    for (final block in _blocks) {
      if (block.deleted) continue;
      final type = block.type;
      if (type == 'unordered_list' || type == 'ordered_list') {
        for (
          var i = 0;
          i < block.childElements.length && i < block.children.length;
          i++
        ) {
          _setNodeChildren(block.childElements[i], block.children[i]);
        }
        elements.add(block.element);
      } else if (type == 'callout') {
        for (
          var i = 0;
          i < block.childElements.length && i < block.children.length;
          i++
        ) {
          _setNodeChildren(block.childElements[i], block.children[i]);
        }
        elements.add(block.element);
      } else if (type == 'toggle_header') {
        final children =
            (block.element['children'] as List?)?.whereType<Map>().toList() ??
            const [];
        if (children.isNotEmpty && block.toggleTitle != null) {
          _setNodeChildren(
            children.first.cast<String, dynamic>(),
            block.toggleTitle!,
          );
        }
        if (children.length > 1) {
          final content = children[1]['children'];
          if (content is List) {
            final paragraphs = content.whereType<Map>().toList();
            for (
              var i = 0;
              i < block.toggleChildElements.length &&
                  i < block.toggleChildren.length;
              i++
            ) {
              _setNodeChildren(
                block.toggleChildElements[i],
                block.toggleChildren[i],
              );
            }
            for (
              var i = paragraphs.length;
              i < block.toggleChildren.length;
              i++
            ) {
              content.add(_paragraphElement(block.toggleChildren[i].text));
            }
          }
        }
        block.element['collapsed'] = block.toggleCollapsed;
        elements.add(block.element);
      } else if (type == 'code_block') {
        final lines = (block.text?.text ?? '').split('\n');
        final existing =
            (block.element['children'] as List?)?.whereType<Map>().toList() ??
            [];
        block.element['children'] = [
          for (var i = 0; i < lines.length; i++)
            {
              'id': i < existing.length
                  ? (existing[i]['id'] as String? ??
                        '${block.element['id']}-$i')
                  : '${block.element['id']}-$i',
              'type': 'code_line',
              'children': [
                {'id': '${block.element['id']}-$i-t', 'text': lines[i]},
              ],
            },
        ];
        elements.add(block.element);
      } else if (_isSimpleEditable(type) && block.text != null) {
        _setNodeChildren(block.element, block.text!);
        elements.add(block.element);
      } else {
        elements.add(block.element);
      }
    }
    for (final element in elements) {
      _saveTableText(element);
    }
    return elements;
  }

  bool get _isComposing =>
      _lastTexts.keys.any((controller) => controller.value.composing.isValid);

  Future<bool> save({bool auto = false}) async {
    if (_readOnly || _saving || !_dirty || _document == null) return true;
    if (auto && _isComposing) {
      _scheduleAutoSave();
      return true;
    }
    _autoSaveTimer?.cancel();
    final l10n = L10n.of(context);
    setState(() => _saving = true);
    try {
      final elements = _composeElements();
      final snapshot = jsonEncode(elements);
      final version = _document!['version'];
      _document!['elements'] = elements;
      _document!['version'] = version is int ? version + 1 : 1;
      _document!['format_version'] = _document!['format_version'] ?? 4;
      await context.read<AppSession>().api!.saveSdocDocument(
        widget.repo.id,
        widget.entry.path,
        _document!,
      );
      if (!mounted) return true;
      final latest = _snapshotNow();
      setState(() {
        _saving = false;
        _savedSnapshot = snapshot;
        if (latest == snapshot) _lastSnapshot = snapshot;
        _dirty = latest != snapshot;
        _lastSavedAt = DateTime.now();
      });
      if (!auto) {
        final workspace = context.read<WorkspaceController>();
        if (workspace.repoId == widget.repo.id) await workspace.refresh();
        if (mounted) showToast(context, l10n.savedSuccessfully);
      } else if (_dirty) {
        _scheduleAutoSave();
      }
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
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(
              l10n.discardChanges,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l10n.save),
          ),
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
    final text =
        block.text?.text ??
        (block.children.isNotEmpty
            ? block.children.first.text
            : _textOf(block.element));

    if (type == 'unordered_list' || type == 'ordered_list') {
      if (wasList) {
        setState(() {
          block.element['type'] = type;
          _changed();
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
        final controller = _SdocTextController(text: text);
        block.childElements = [item];
        block.children = [controller];
        block.childFocus = [FocusNode()];
        _watch(controller);
        setState(_changed);
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
        block.text = _SdocTextController(text: text);
        block.textFocus = FocusNode();
        _watch(block.text!);
        setState(_changed);
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
      block.text = _SdocTextController(text: text);
      block.textFocus = FocusNode();
      _watch(block.text!);
      setState(_changed);
      _focusBlock(block, index, text.length);
    }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                FileTypeIcon(
                  name: widget.entry.name,
                  size: 22,
                  permission: widget.entry.permission,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_dirty) ...[
                        const SizedBox(width: 7),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 15,
                          color: AppColors.muted,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        _saving
                            ? (l10n.zh ? '正在保存…' : 'Saving…')
                            : _lastSavedAt == null
                            ? (l10n.zh ? '未保存' : 'Not saved')
                            : l10n.zh
                            ? '上次保存 ${_formatSavedTime(_lastSavedAt!)}'
                            : 'Saved ${_formatSavedTime(_lastSavedAt!)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconAction(
                  icon: 'comment',
                  tooltip: l10n.zh ? '评论' : 'Comments',
                  size: 17,
                  onPressed: () =>
                      setState(() => _commentsOpen = !_commentsOpen),
                ),
                if (workspace.repoId == widget.repo.id)
                  IconAction(
                    icon: 'share',
                    tooltip: l10n.share,
                    size: 17,
                    onPressed: () =>
                        shareEntry(context, workspace, widget.entry),
                  ),
                IconAction(
                  icon: 'history',
                  tooltip: l10n.history,
                  size: 17,
                  onPressed: () =>
                      showFileHistory(context, workspace, widget.entry),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (!_readOnly)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolbarButton(
                      icon: Icons.undo,
                      tooltip: l10n.zh ? '撤销' : 'Undo',
                      onTap: canUndo ? _undo : null,
                    ),
                    _ToolbarButton(
                      icon: Icons.redo,
                      tooltip: l10n.zh ? '重做' : 'Redo',
                      onTap: canRedo ? _redo : null,
                    ),
                    _toolDivider(),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '插入' : 'Insert',
                      minWidth: 190,
                      onSelected: (value) {
                        switch (value) {
                          case 'table':
                            _insertTable();
                          case 'image':
                            unawaited(_insertImage());
                          case 'image_local':
                            unawaited(_insertLocalImage());
                          case 'video_local':
                            unawaited(_insertLocalVideo());
                          case 'video_url':
                            unawaited(_insertVideoLink());
                          case 'sdoc_link':
                            unawaited(
                              _insertEmbedLink('sdoc', '链接 sdoc', 'Link sdoc'),
                            );
                          case 'file_link':
                            unawaited(
                              _insertEmbedLink('file', '文件链接', 'File link'),
                            );
                          case 'whiteboard':
                            unawaited(
                              _insertEmbedLink(
                                'whiteboard',
                                '白板',
                                'Whiteboard',
                              ),
                            );
                          case 'code_block':
                            _insertCodeBlock();
                          case 'formula':
                            unawaited(_insertFormula());
                          case 'divider':
                            _insertDivider();
                          case 'callout':
                            _insertCallout();
                        }
                      },
                      itemBuilder: (context) => [
                        editorMenuItem(
                          'table',
                          label: l10n.zh ? '表格' : 'Table',
                          icon: Icons.table_chart_outlined,
                        ),
                        editorMenuItem(
                          'code_block',
                          label: l10n.zh ? '代码块' : 'Code block',
                          icon: Icons.data_object,
                        ),
                        editorMenuItem(
                          'formula',
                          label: l10n.zh ? '公式' : 'Formula',
                          icon: Icons.functions,
                        ),
                        editorMenuItem(
                          'divider',
                          label: l10n.zh ? '分隔线' : 'Divider',
                          icon: Icons.horizontal_rule,
                        ),
                        editorMenuItem(
                          'callout',
                          label: l10n.zh ? '高亮块' : 'Callout',
                          icon: Icons.lightbulb_outline,
                        ),
                        editorMenuDivider(),
                        editorMenuItem(
                          'image',
                          label: l10n.zh ? '网络图片' : 'Image URL',
                          icon: Icons.image_outlined,
                        ),
                        editorMenuItem(
                          'image_local',
                          label: l10n.zh ? '本地图片' : 'Local image',
                          icon: Icons.upload_file,
                        ),
                        editorMenuItem(
                          'video_local',
                          label: l10n.zh ? '本地视频' : 'Local video',
                          icon: Icons.video_file_outlined,
                        ),
                        editorMenuItem(
                          'video_url',
                          label: l10n.zh ? '视频链接' : 'Video link',
                          icon: Icons.link,
                        ),
                        editorMenuDivider(),
                        editorMenuItem(
                          'whiteboard',
                          label: l10n.zh ? '白板' : 'Whiteboard',
                          icon: Icons.draw_outlined,
                        ),
                        editorMenuItem(
                          'sdoc_link',
                          label: l10n.zh ? '链接 sdoc' : 'Link sdoc',
                          icon: Icons.note_alt_outlined,
                        ),
                        editorMenuItem(
                          'file_link',
                          label: l10n.zh ? '文件链接' : 'File link',
                          icon: Icons.attach_file,
                        ),
                      ],
                      child: EditorMenuTrigger(
                        icon: Icons.add_circle_outline,
                        label: l10n.zh ? '插入' : 'Insert',
                      ),
                    ),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '段落样式' : 'Block type',
                      onSelected: _changeType,
                      itemBuilder: (context) {
                        final activeType = _activeBlock?.type ?? 'paragraph';
                        final options = <String, String>{
                          'paragraph': l10n.zh ? '段落' : 'Paragraph',
                          'header1': l10n.zh ? '一级标题' : 'Heading 1',
                          'header2': l10n.zh ? '二级标题' : 'Heading 2',
                          'header3': l10n.zh ? '三级标题' : 'Heading 3',
                          'header4': l10n.zh ? '四级标题' : 'Heading 4',
                          'header5': l10n.zh ? '五级标题' : 'Heading 5',
                          'header6': l10n.zh ? '六级标题' : 'Heading 6',
                          'quote': l10n.zh ? '引用' : 'Quote',
                          'unordered_list': l10n.zh ? '无序列表' : 'Unordered list',
                          'ordered_list': l10n.zh ? '有序列表' : 'Ordered list',
                          'check_list_item': l10n.zh ? '任务列表' : 'Check list',
                          'code_block': l10n.zh ? '代码块' : 'Code block',
                        };
                        return [
                          for (final entry in options.entries)
                            editorMenuItem(
                              entry.key,
                              label: entry.value,
                              selected: entry.key == activeType,
                            ),
                        ];
                      },
                      child: EditorMenuTrigger(label: _blockTypeLabel(l10n)),
                    ),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '字体' : 'Font',
                      onSelected: (value) =>
                          _setFontFamily(value.isEmpty ? null : value),
                      itemBuilder: (context) => [
                        editorMenuItem(
                          '',
                          label: l10n.zh ? '默认字体' : 'Default font',
                        ),
                        for (final font in const [
                          'Arial',
                          'Times New Roman',
                          'Courier New',
                          'Georgia',
                          'PingFang SC',
                          'Songti SC',
                          'Kaiti SC',
                          'Menlo',
                        ])
                          editorMenuItem(
                            font,
                            label: font,
                            textStyle: TextStyle(fontFamily: font),
                          ),
                      ],
                      child: EditorMenuTrigger(label: l10n.zh ? '字体' : 'Font'),
                    ),
                    editorPopupMenu<double>(
                      tooltip: l10n.zh ? '字号' : 'Font size',
                      minWidth: 90,
                      onSelected: _setFontSize,
                      itemBuilder: (context) => [
                        for (final size in const [
                          11.0,
                          12.0,
                          14.0,
                          16.0,
                          18.0,
                          20.0,
                          22.0,
                          24.0,
                          26.0,
                          28.0,
                          32.0,
                        ])
                          editorMenuItem(
                            size,
                            label: size.toInt().toString(),
                            selected: _activeFontSize.toInt() == size.toInt(),
                          ),
                      ],
                      child: EditorMenuTrigger(
                        label: _activeFontSize.toInt().toString(),
                      ),
                    ),
                    _toolDivider(),
                    _ToolbarButton(
                      icon: Icons.format_bold,
                      tooltip: l10n.zh ? '粗体' : 'Bold',
                      onTap: () => _toggleInlineMark(
                        (style) => style.copyWith(bold: !style.bold),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_italic,
                      tooltip: l10n.zh ? '斜体' : 'Italic',
                      onTap: () => _toggleInlineMark(
                        (style) => style.copyWith(italic: !style.italic),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_underlined,
                      tooltip: l10n.zh ? '下划线' : 'Underline',
                      onTap: () => _toggleInlineMark(
                        (style) => style.copyWith(underline: !style.underline),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_strikethrough,
                      tooltip: l10n.zh ? '删除线' : 'Strikethrough',
                      onTap: () => _toggleInlineMark(
                        (style) =>
                            style.copyWith(strikethrough: !style.strikethrough),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.code,
                      tooltip: l10n.zh ? '行内代码' : 'Inline code',
                      onTap: () => _toggleInlineMark(
                        (style) => style.copyWith(code: !style.code),
                      ),
                    ),
                    _ToolbarButton(
                      icon: Icons.link,
                      tooltip: l10n.zh ? '链接' : 'Link',
                      onTap: () => unawaited(_setLink()),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_clear,
                      tooltip: l10n.zh ? '清除格式' : 'Clear formatting',
                      onTap: _clearFormatting,
                    ),
                    _toolDivider(),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '字体颜色' : 'Font color',
                      minWidth: 160,
                      onSelected: (value) =>
                          _setTextColor(value.isEmpty ? null : value),
                      itemBuilder: (context) => [
                        editorMenuItem(
                          '',
                          label: l10n.zh ? '默认' : 'Default',
                          icon: Icons.format_clear,
                        ),
                        for (final entry in const {
                          '#000000': '黑色 / Black',
                          '#6b7280': '灰色 / Gray',
                          '#d93025': '红色 / Red',
                          '#e8710a': '橙色 / Orange',
                          '#188038': '绿色 / Green',
                          '#1a73e8': '蓝色 / Blue',
                          '#9334e6': '紫色 / Purple',
                        }.entries)
                          editorMenuItem(
                            entry.key,
                            label: entry.value,
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _SdocTextStyle._parseHexColor(entry.key),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                      ],
                      child: const EditorMenuTrigger(
                        icon: Icons.format_color_text,
                      ),
                    ),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '高亮颜色' : 'Highlight color',
                      minWidth: 160,
                      onSelected: (value) =>
                          _setHighlightColor(value.isEmpty ? null : value),
                      itemBuilder: (context) => [
                        editorMenuItem(
                          '',
                          label: l10n.zh ? '无高亮' : 'No highlight',
                          icon: Icons.format_clear,
                        ),
                        for (final entry in const {
                          '#fff2a8': '黄色 / Yellow',
                          '#d7f7d7': '绿色 / Green',
                          '#d7e9ff': '蓝色 / Blue',
                          '#ffd7e7': '粉色 / Pink',
                          '#eeeeee': '灰色 / Gray',
                        }.entries)
                          editorMenuItem(
                            entry.key,
                            label: entry.value,
                            leading: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _SdocTextStyle._parseHexColor(entry.key),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: AppColors.border),
                              ),
                            ),
                          ),
                      ],
                      child: const EditorMenuTrigger(
                        icon: Icons.format_color_fill,
                      ),
                    ),
                    editorPopupMenu<TextAlign>(
                      tooltip: l10n.zh ? '对齐方式' : 'Alignment',
                      minWidth: 150,
                      onSelected: _setAlignment,
                      itemBuilder: (context) {
                        final align =
                            _activeBlock?.element['text_align'] as String? ??
                            'left';
                        return [
                          editorMenuItem(
                            TextAlign.left,
                            label: l10n.zh ? '左对齐' : 'Left',
                            icon: Icons.format_align_left,
                            selected: align == 'left',
                          ),
                          editorMenuItem(
                            TextAlign.center,
                            label: l10n.zh ? '居中' : 'Center',
                            icon: Icons.format_align_center,
                            selected: align == 'center',
                          ),
                          editorMenuItem(
                            TextAlign.right,
                            label: l10n.zh ? '右对齐' : 'Right',
                            icon: Icons.format_align_right,
                            selected: align == 'right',
                          ),
                        ];
                      },
                      child: const EditorMenuTrigger(
                        icon: Icons.format_align_left,
                      ),
                    ),
                    editorPopupMenu<String>(
                      tooltip: l10n.zh ? '更多' : 'More',
                      minWidth: 190,
                      onSelected: (value) {
                        switch (value) {
                          case 'superscript':
                            _toggleInlineMark(
                              (style) => style.copyWith(
                                superscript: !style.superscript,
                                subscript: false,
                              ),
                              allIfCollapsed: true,
                            );
                          case 'subscript':
                            _toggleInlineMark(
                              (style) => style.copyWith(
                                subscript: !style.subscript,
                                superscript: false,
                              ),
                              allIfCollapsed: true,
                            );
                          case 'font_increase':
                            _adjustFontSize(1);
                          case 'font_decrease':
                            _adjustFontSize(-1);
                        }
                      },
                      itemBuilder: (context) => [
                        editorMenuItem(
                          'superscript',
                          label: l10n.zh ? '上标' : 'Superscript',
                          icon: Icons.superscript,
                        ),
                        editorMenuItem(
                          'subscript',
                          label: l10n.zh ? '下标' : 'Subscript',
                          icon: Icons.subscript,
                        ),
                        editorMenuDivider(),
                        editorMenuItem(
                          'font_increase',
                          label: l10n.zh ? '增大字号' : 'Increase font size',
                          icon: Icons.text_increase,
                        ),
                        editorMenuItem(
                          'font_decrease',
                          label: l10n.zh ? '减小字号' : 'Decrease font size',
                          icon: Icons.text_decrease,
                        ),
                      ],
                      child: const EditorMenuTrigger(icon: Icons.more_horiz),
                    ),
                    _toolDivider(),
                    _ToolbarButton(
                      icon: Icons.format_quote,
                      tooltip: l10n.zh ? '引用' : 'Quote',
                      onTap: () => _changeType('quote'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: l10n.zh ? '无序列表' : 'Bulleted list',
                      onTap: () => _changeType('unordered_list'),
                    ),
                    _ToolbarButton(
                      icon: Icons.format_list_numbered,
                      tooltip: l10n.zh ? '有序列表' : 'Numbered list',
                      onTap: () => _changeType('ordered_list'),
                    ),
                    _ToolbarButton(
                      icon: Icons.checklist,
                      tooltip: l10n.zh ? '任务列表' : 'Checklist',
                      onTap: () => _changeType('check_list_item'),
                    ),
                    _ToolbarButton(
                      icon: Icons.search,
                      tooltip: l10n.zh ? '查找' : 'Find',
                      onTap: () => unawaited(_findInDocument()),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _SdocField? _activeTextField() {
    final fields = _fields();
    for (final field in fields) {
      if (field.focus.hasFocus) return field;
    }
    for (final field in fields) {
      if (field.blockIndex == _active) return field;
    }
    return fields.isEmpty ? null : fields.first;
  }

  void _toggleInlineMark(
    _SdocTextStyle Function(_SdocTextStyle) toggle, {
    bool allIfCollapsed = false,
  }) {
    final controller = _activeTextField()?.controller;
    if (controller is! _SdocTextController) return;
    controller.toggleMark(toggle, allIfCollapsed: allIfCollapsed);
    setState(_changed);
  }

  double get _activeFontSize {
    return switch (_activeBlock?.type) {
      'title' => 28,
      'header1' => 26,
      'header2' => 22,
      'header3' => 18,
      'header4' || 'header5' || 'header6' => 16,
      'code_block' => 13,
      _ => 15,
    };
  }

  void _setFontSize(double size) {
    _toggleInlineMark(
      (style) => style.copyWith(fontSize: size),
      allIfCollapsed: true,
    );
  }

  void _adjustFontSize(int delta) {
    final base = _activeFontSize;
    _toggleInlineMark(
      (style) => style.copyWith(
        fontSize: ((style.fontSize ?? base) + delta).clamp(8, 72),
      ),
      allIfCollapsed: true,
    );
  }

  void _setFontFamily(String? font) {
    _toggleInlineMark((style) => style.withFont(font), allIfCollapsed: true);
  }

  void _setTextColor(String? color) {
    _toggleInlineMark((style) => style.withColor(color), allIfCollapsed: true);
  }

  void _setHighlightColor(String? color) {
    _toggleInlineMark(
      (style) => style.withHighlight(color),
      allIfCollapsed: true,
    );
  }

  Future<void> _findInDocument() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? '查找和替换' : 'Find and replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: L10n.of(context).zh ? '查找内容' : 'Find text',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: replaceController,
              decoration: InputDecoration(
                hintText: L10n.of(context).zh ? '替换内容' : 'Replace with',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'find'),
            child: Text(L10n.of(context).zh ? '查找' : 'Find'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: Text(L10n.of(context).zh ? '替换' : 'Replace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'replace_all'),
            child: Text(L10n.of(context).zh ? '全部替换' : 'Replace all'),
          ),
        ],
      ),
    );
    final query = findController.text;
    final replacement = replaceController.text;
    findController.dispose();
    replaceController.dispose();
    if (!mounted || action == null || query.isEmpty) return;
    switch (action) {
      case 'find':
        _findNext(query);
      case 'replace':
        _replaceCurrent(query, replacement);
      case 'replace_all':
        _replaceAll(query, replacement);
    }
  }

  ({_SdocField field, int offset})? _locateMatch(String query) {
    final fields = _fields();
    if (fields.isEmpty) return null;
    final activeField = _activeTextField();
    final startIndex = activeField == null ? 0 : fields.indexOf(activeField);
    final startOffset = activeField?.controller.selection.end ?? 0;
    final needle = query.toLowerCase();
    for (var step = 0; step < fields.length; step++) {
      final index = (startIndex + step) % fields.length;
      final field = fields[index];
      final text = field.controller.text.toLowerCase();
      final offset = text.indexOf(
        needle,
        step == 0 ? startOffset.clamp(0, text.length) : 0,
      );
      if (offset >= 0) return (field: field, offset: offset);
    }
    return null;
  }

  void _findNext(String query) {
    final match = _locateMatch(query);
    if (match == null) {
      showToast(
        context,
        L10n.of(context).zh ? '未找到匹配内容' : 'No match found',
        error: true,
      );
      return;
    }
    final field = match.field;
    setState(() => _active = field.blockIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      field.focus.requestFocus();
      field.controller.selection = TextSelection(
        baseOffset: match.offset,
        extentOffset: match.offset + query.length,
      );
    });
  }

  void _replaceCurrent(String query, String replacement) {
    final active = _activeTextField();
    final selection = active?.controller.selection;
    var field = active;
    var offset = 0;
    if (active != null &&
        selection != null &&
        selection.isValid &&
        !selection.isCollapsed &&
        active.controller.text
                .substring(selection.start, selection.end)
                .toLowerCase() ==
            query.toLowerCase()) {
      offset = selection.start;
    } else {
      final match = _locateMatch(query);
      if (match == null) {
        _findNext(query);
        return;
      }
      field = match.field;
      offset = match.offset;
    }
    final controller = field?.controller;
    if (field == null || controller == null) return;
    final value = controller.value;
    controller.value = TextEditingValue(
      text: value.text.replaceRange(offset, offset + query.length, replacement),
      selection: TextSelection.collapsed(offset: offset + replacement.length),
    );
    setState(() {
      _active = field!.blockIndex;
      _changed();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      field!.focus.requestFocus();
    });
  }

  void _replaceAll(String query, String replacement) {
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    var count = 0;
    for (final field in _fields()) {
      final text = field.controller.text;
      final matches = pattern.allMatches(text).length;
      if (matches == 0) continue;
      count += matches;
      field.controller.value = TextEditingValue(
        text: text.replaceAll(pattern, replacement),
        selection: TextSelection.collapsed(
          offset: text.replaceAll(pattern, replacement).length,
        ),
      );
    }
    if (count == 0) {
      showToast(
        context,
        L10n.of(context).zh ? '未找到匹配内容' : 'No match found',
        error: true,
      );
      return;
    }
    setState(_changed);
    showToast(
      context,
      L10n.of(context).zh ? '已替换 $count 处' : 'Replaced $count matches',
    );
  }

  Future<void> _setLink() async {
    final controller = _activeTextField()?.controller;
    if (controller is! _SdocTextController || controller._formatRange == null) {
      showToast(
        context,
        L10n.of(context).zh ? '请先选择要添加链接的文字' : 'Select text to add a link',
        error: true,
      );
      return;
    }
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? '添加链接' : 'Add link'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context).zh ? '链接地址' : 'Link address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(L10n.of(context).confirm),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || url == null || url.isEmpty) return;
    final target = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    controller.toggleMark((style) => style.withLink(target));
    setState(_changed);
  }

  void _clearFormatting() {
    final controller = _activeTextField()?.controller;
    if (controller is! _SdocTextController) return;
    controller.clearMarks();
    setState(_changed);
  }

  _SdocBlock? get _activeBlock {
    final index = _active;
    if (index == null || index < 0 || index >= _blocks.length) return null;
    final block = _blocks[index];
    return block.deleted ? null : block;
  }

  String _blockTypeLabel(L10n l10n) {
    final type = _activeBlock?.type ?? 'paragraph';
    return switch (type) {
      'header1' => l10n.zh ? '一级标题' : 'Heading 1',
      'header2' => l10n.zh ? '二级标题' : 'Heading 2',
      'header3' => l10n.zh ? '三级标题' : 'Heading 3',
      'header4' => l10n.zh ? '四级标题' : 'Heading 4',
      'header5' => l10n.zh ? '五级标题' : 'Heading 5',
      'header6' => l10n.zh ? '六级标题' : 'Heading 6',
      'quote' => l10n.zh ? '引用' : 'Quote',
      'unordered_list' => l10n.zh ? '无序列表' : 'Unordered list',
      'ordered_list' => l10n.zh ? '有序列表' : 'Ordered list',
      'check_list_item' => l10n.zh ? '任务列表' : 'Check list',
      'code_block' => l10n.zh ? '代码块' : 'Code block',
      'callout' => l10n.zh ? '高亮块' : 'Callout',
      _ => l10n.zh ? '段落' : 'Paragraph',
    };
  }

  void _setAlignment(TextAlign align) {
    final block = _activeBlock;
    if (block == null) return;
    setState(() {
      block.element['text_align'] = switch (align) {
        TextAlign.center => 'center',
        TextAlign.right => 'right',
        _ => 'left',
      };
      _changed();
    });
  }

  TextAlign _textAlignOf(_SdocBlock block) {
    return switch (block.element['text_align']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  int get _insertIndex => _active == null
      ? _blocks.length
      : (_active! + 1).clamp(0, _blocks.length);

  void _insertNode(_SdocBlock block, {VoidCallback? onInserted}) {
    final index = _insertIndex;
    setState(() {
      _blocks.insert(index, block);
      _active = index;
      _changed();
    });
    if (onInserted != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onInserted());
    }
  }

  void _insertCodeBlock() {
    final id = 'code-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final element = <String, dynamic>{
      'id': id,
      'type': 'code_block',
      'language': 'plaintext',
      'children': [
        {
          'id': '$id-0',
          'type': 'code_line',
          'children': [
            {'id': '$id-0-t', 'text': ''},
          ],
        },
      ],
    };
    final block = _SdocBlock(element)
      ..text = _SdocTextController()
      ..textFocus = FocusNode();
    _watch(block.text!);
    _insertNode(
      block,
      onInserted: () {
        final field = _firstFieldOfBlock(block, _blocks.indexOf(block));
        if (field != null) _focusField(field, 0);
      },
    );
  }

  void _insertDivider() {
    final id = 'divider-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'divider',
        'children': [
          {'id': '$id-t', 'text': ''},
        ],
      }),
    );
  }

  void _insertCallout() {
    final id = 'callout-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final children = [_paragraphElement('')];
    final element = <String, dynamic>{
      'id': id,
      'type': 'callout',
      'children': children,
      'style': {'background_color': '#fef7e0'},
    };
    final block = _SdocBlock(element);
    final childMaps = children
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    block.childElements = childMaps;
    block.children = [
      for (final child in childMaps) _SdocTextController.fromNode(child),
    ];
    block.childFocus = [for (final _ in childMaps) FocusNode()];
    for (final controller in block.children) {
      _watch(controller);
    }
    _insertNode(
      block,
      onInserted: () {
        final field = _firstFieldOfBlock(block, _blocks.indexOf(block));
        if (field != null) _focusField(field, 0);
      },
    );
  }

  Future<void> _insertImage() async {
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? '插入网络图片' : 'Insert network image'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context).zh ? '图片地址' : 'Image address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(L10n.of(context).confirm),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || url == null || url.isEmpty) return;
    final id = 'image-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'image',
        'data': {'src': url},
        'children': [
          {'id': '$id-t', 'text': ''},
        ],
      }),
    );
  }

  Future<void> _insertLocalImage() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    try {
      final relative = await context.read<AppSession>().api!.uploadSdocImage(
        widget.repo.id,
        widget.entry.path,
        file.path,
      );
      if (!mounted) return;
      final id = 'image-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
      _insertNode(
        _SdocBlock({
          'id': id,
          'type': 'image',
          'data': {'src': relative},
          'children': [
            {'id': '$id-t', 'text': ''},
          ],
        }),
      );
    } catch (error) {
      if (mounted)
        showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _insertLocalVideo() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Videos',
          extensions: ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    try {
      final relative = await context.read<AppSession>().api!.uploadSdocVideo(
        widget.repo.id,
        widget.entry.path,
        file.path,
      );
      if (!mounted) return;
      final size = await File(file.path).length();
      final id = 'video-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
      _insertNode(
        _SdocBlock({
          'id': id,
          'type': 'video',
          'data': {
            'name': file.name,
            'src': relative,
            'size': size,
            'is_embeddable_link': false,
          },
          'children': [
            {'id': '$id-t', 'text': ''},
          ],
        }),
      );
    } catch (error) {
      if (mounted)
        showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _insertVideoLink() async {
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? '插入视频链接' : 'Insert video link'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context).zh ? '视频地址' : 'Video address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(L10n.of(context).confirm),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || url == null || url.isEmpty) return;
    final id = 'video-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'video',
        'data': {
          'name': url,
          'src': url,
          'size': 0,
          'is_embeddable_link': true,
        },
        'children': [
          {'id': '$id-t', 'text': ''},
        ],
      }),
    );
  }

  Future<void> _insertEmbedLink(
    String linkType,
    String titleZh,
    String titleEn,
  ) async {
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? titleZh : titleEn),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: InputDecoration(
            hintText: L10n.of(context).zh ? '链接地址' : 'Link address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: Text(L10n.of(context).confirm),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || url == null || url.isEmpty) return;
    final target = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'https://$url';
    final id = 'embed-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'embed_link',
        'link': target,
        'link_type': linkType,
        'children': [
          {'id': '$id-t', 'text': ''},
        ],
      }),
    );
  }

  Future<void> _insertFormula() async {
    final controller = TextEditingController();
    final formula = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).zh ? '插入公式' : 'Insert formula'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: L10n.of(context).zh
                ? '输入 LaTeX 公式'
                : 'Enter a LaTeX formula',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(L10n.of(context).confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || formula == null || formula.isEmpty) return;
    final id = 'formula-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'formula',
        'data': {'formula': formula},
        'children': [
          {'id': '$id-t', 'text': ''},
        ],
      }),
    );
  }

  void _insertTable() {
    final id = 'table-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}';
    final rows = <Map<String, dynamic>>[];
    for (var r = 0; r < 3; r++) {
      final rowId = '$id-r$r';
      final cells = <Map<String, dynamic>>[];
      for (var c = 0; c < 2; c++) {
        final cellId = '$rowId-c$c';
        cells.add({
          'id': cellId,
          'type': 'table_cell',
          'children': [_paragraphElement('')..['id'] = '$cellId-p'],
          'style': <String, dynamic>{},
          'inherit_style': <String, dynamic>{},
        });
      }
      rows.add({
        'id': rowId,
        'type': 'table_row',
        'children': cells,
        'style': {'min_height': 42},
      });
    }
    _insertNode(
      _SdocBlock({
        'id': id,
        'type': 'table',
        'children': rows,
        'style': {
          'gridTemplateColumns': 'repeat(2, 220px)',
          'gridAutoRows': 'minmax(42px, auto)',
        },
      }),
    );
  }

  Widget _toolDivider() => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: AppColors.border,
  );

  Widget _content(L10n l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WebIcon(
              'exclamation-circle',
              size: 38,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
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
        key: const ValueKey('sdoc-canvas'),
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
    final child = switch (block.type) {
      'title' => _textField(
        block,
        index,
        28,
        FontWeight.w700,
        onTap: () => _setActive(index),
      ),
      'paragraph' => _textField(
        block,
        index,
        15,
        FontWeight.w400,
        onTap: () => _setActive(index),
      ),
      'header1' => _textField(
        block,
        index,
        26,
        FontWeight.w700,
        onTap: () => _setActive(index),
      ),
      'header2' => _textField(
        block,
        index,
        22,
        FontWeight.w600,
        onTap: () => _setActive(index),
      ),
      'header3' => _textField(
        block,
        index,
        18,
        FontWeight.w600,
        onTap: () => _setActive(index),
      ),
      'header4' || 'header5' || 'header6' => _textField(
        block,
        index,
        16,
        FontWeight.w600,
        onTap: () => _setActive(index),
      ),
      'code_block' => _codeView(block, index),
      'unordered_list' || 'ordered_list' => _listView(block, index),
      'check_list_item' => _checkView(block, index),
      'quote' => _quoteView(block, index),
      'callout' => _calloutView(block, index),
      'table' => _tableView(block),
      'image' || 'image_block' => _imageView(block),
      'video' => _videoView(block),
      'embed_link' => _embedView(block),
      'formula' => _formulaView(block),
      'divider' => const Divider(
        height: 24,
        thickness: 1,
        color: AppColors.border,
      ),
      'toggle_header' => _toggleView(block, index),
      'multi_column' => _multiColumnView(block),
      _ => _unknownView(block),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: child,
    );
  }

  Widget _contextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final l10n = L10n.of(context);
    void hide() => editableTextState.hideToolbar();
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: l10n.zh ? '剪切' : 'Cut',
          onPressed: () {
            editableTextState.cutSelection(SelectionChangedCause.toolbar);
            hide();
          },
        ),
        ContextMenuButtonItem(
          label: l10n.copy,
          onPressed: () {
            editableTextState.copySelection(SelectionChangedCause.toolbar);
            hide();
          },
        ),
        ContextMenuButtonItem(
          label: l10n.zh ? '粘贴' : 'Paste',
          onPressed: () {
            editableTextState.pasteText(SelectionChangedCause.toolbar);
            hide();
          },
        ),
        ContextMenuButtonItem(
          label: l10n.delete,
          onPressed: () {
            _deleteSelection(editableTextState);
            hide();
          },
        ),
        ContextMenuButtonItem(
          label: l10n.zh ? '全选' : 'Select all',
          onPressed: () {
            editableTextState.selectAll(SelectionChangedCause.toolbar);
            hide();
          },
        ),
      ],
    );
  }

  void _deleteSelection(EditableTextState state) {
    final value = state.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid) return;
    if (selection.isCollapsed) {
      if (selection.start <= 0) return;
      state.userUpdateTextEditingValue(
        value.copyWith(
          text: value.text.replaceRange(
            selection.start - 1,
            selection.start,
            '',
          ),
          selection: TextSelection.collapsed(offset: selection.start - 1),
          composing: TextRange.empty,
        ),
        SelectionChangedCause.toolbar,
      );
      return;
    }
    state.userUpdateTextEditingValue(
      value.copyWith(
        text: value.text.replaceRange(selection.start, selection.end, ''),
        selection: TextSelection.collapsed(offset: selection.start),
        composing: TextRange.empty,
      ),
      SelectionChangedCause.toolbar,
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

  Widget _textField(
    _SdocBlock block,
    int index,
    double size,
    FontWeight weight, {
    required VoidCallback onTap,
  }) {
    final controller = block.text;
    final focus = block.textFocus;
    if (controller == null || focus == null) return const SizedBox.shrink();
    final field = _SdocField(
      block: block,
      blockIndex: index,
      kind: block.type == 'code_block'
          ? _SdocFieldKind.code
          : _SdocFieldKind.simple,
      controller: controller,
      focus: focus,
    );
    return _keyboard(
      field,
      TextField(
        controller: controller,
        contextMenuBuilder: _contextMenu,
        focusNode: focus,
        onTap: onTap,
        enabled: !_readOnly,
        maxLines: null,
        textAlign: _textAlignOf(block),
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: 1.5,
          color: AppColors.text,
        ),
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
    final field = _SdocField(
      block: block,
      blockIndex: index,
      kind: _SdocFieldKind.code,
      controller: controller,
      focus: focus,
    );
    return GestureDetector(
      onTap: () => _setActive(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(5),
        ),
        child: _keyboard(
          field,
          TextField(
            controller: controller,
            contextMenuBuilder: _contextMenu,
            focusNode: focus,
            onTap: () => _setActive(index),
            enabled: !_readOnly,
            maxLines: null,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              height: 1.6,
            ),
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: i < block.childFocus.length
                        ? _keyboard(
                            _SdocField(
                              block: block,
                              blockIndex: index,
                              kind: _SdocFieldKind.listItem,
                              controller: block.children[i],
                              focus: block.childFocus[i],
                              item: i,
                            ),
                            TextField(
                              controller: block.children[i],
                              contextMenuBuilder: _contextMenu,
                              focusNode: block.childFocus[i],
                              onTap: () => _setActive(index),
                              enabled: !_readOnly,
                              maxLines: null,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                              ),
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
                      _changed();
                    });
                  },
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _textField(
            block,
            index,
            15,
            FontWeight.w400,
            onTap: () => _setActive(index),
          ),
        ),
      ],
    );
  }

  Widget _quoteView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: _textField(
        block,
        index,
        15,
        FontWeight.w400,
        onTap: () => _setActive(index),
      ),
    );
  }

  Widget _calloutView(_SdocBlock block, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < block.children.length; i++)
            if (i < block.childFocus.length)
              _keyboard(
                _SdocField(
                  block: block,
                  blockIndex: index,
                  kind: _SdocFieldKind.calloutChild,
                  controller: block.children[i],
                  focus: block.childFocus[i],
                  item: i,
                ),
                TextField(
                  controller: block.children[i],
                  contextMenuBuilder: _contextMenu,
                  focusNode: block.childFocus[i],
                  onTap: () => _setActive(index),
                  enabled: !_readOnly,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14.5, height: 1.6),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 3),
                  ),
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
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => block.toggleCollapsed = !block.toggleCollapsed,
                ),
                icon: Transform.rotate(
                  angle: block.toggleCollapsed ? -1.57 : 0,
                  child: const WebIcon(
                    'arrow-down',
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: title != null && titleFocus != null
                    ? _keyboard(
                        _SdocField(
                          block: block,
                          blockIndex: index,
                          kind: _SdocFieldKind.toggleTitle,
                          controller: title,
                          focus: titleFocus,
                        ),
                        TextField(
                          controller: title,
                          contextMenuBuilder: _contextMenu,
                          focusNode: titleFocus,
                          onTap: () => _setActive(index),
                          enabled: !_readOnly,
                          maxLines: null,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
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
                        _SdocField(
                          block: block,
                          blockIndex: index,
                          kind: _SdocFieldKind.toggleChild,
                          controller: block.toggleChildren[i],
                          focus: block.toggleChildFocus[i],
                          item: i,
                        ),
                        TextField(
                          controller: block.toggleChildren[i],
                          contextMenuBuilder: _contextMenu,
                          focusNode: block.toggleChildFocus[i],
                          onTap: () => _setActive(index),
                          enabled: !_readOnly,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14.5, height: 1.55),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 3),
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

  Widget _multiColumnView(_SdocBlock block) {
    final columns =
        (block.element['children'] as List?)?.whereType<Map>().toList() ??
        const [];
    if (columns.isEmpty) return _unknownView(block);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _textOf(columns[i]).trim().isEmpty
                      ? '—'
                      : _textOf(columns[i]),
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
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const WebIcon('info', size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? block.type : '$text  ·  ${block.type}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableView(_SdocBlock block) {
    final rows =
        (block.element['children'] as List?)?.whereType<Map>().toList() ??
        const [];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final cell
                      in ((row['children'] as List?) ?? const [])
                          .whereType<Map>())
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppColors.border),
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: TextField(
                          controller: _controllerForCell(cell),
                          contextMenuBuilder: _contextMenu,
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
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const WebIcon('play-filled', size: 28, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? (l10n.zh ? '视频' : 'Video') : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (size != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatSize(size),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (opening)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            OutlinedButton.icon(
              onPressed: () =>
                  embeddable ? _openLink(src) : _openVideo(block, src, name),
              icon: Icon(
                embeddable ? Icons.open_in_new : Icons.play_arrow,
                size: 15,
              ),
              label: Text(
                embeddable
                    ? (l10n.zh ? '打开链接' : 'Open link')
                    : (l10n.zh ? '播放' : 'Play'),
              ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          const WebIcon('link', size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type.isNotEmpty)
                  Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                      letterSpacing: .4,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  link,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.text),
                ),
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
      final bytes = await context.read<AppSession>().api!.loadSdocVideo(
        widget.repo.id,
        widget.entry.path,
        src,
      );
      final temp = await getTemporaryDirectory();
      final dir = Directory(p.join(temp.path, 'seafile-sdoc-video'));
      await dir.create(recursive: true);
      final safeName = name.isEmpty ? src.split('/').last : name;
      final file = File(p.join(dir.path, safeName));
      await file.writeAsBytes(bytes, flush: true);
      if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isWindows) {
        await Process.start('cmd', [
          '/c',
          'start',
          '',
          file.path,
        ], runInShell: true);
      } else {
        await Process.run('xdg-open', [file.path]);
      }
    } catch (error) {
      if (mounted)
        showToast(context, friendlyError(context, error), error: true);
    } finally {
      if (mounted) setState(() => _openingVideos.remove(src));
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Widget _formulaView(_SdocBlock block) {
    final data = block.element['data'];
    final formula = data is Map ? data['formula'] : null;
    if (formula is! String || formula.trim().isEmpty)
      return _mediaPlaceholder('公式', 'Formula');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          formula,
          mathStyle: MathStyle.display,
          textStyle: const TextStyle(fontSize: 18, color: AppColors.text),
          onErrorFallback: (error) => Text(
            formula,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
          ),
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
        child: Image.network(
          value,
          fit: BoxFit.contain,
          height: 280,
          errorBuilder: (_, __, ___) =>
              _mediaPlaceholder('图片加载失败', 'Image unavailable'),
        ),
      );
    }
    final future = _imageCache.putIfAbsent(
      value,
      () => context.read<AppSession>().api!.loadSdocImage(
        widget.repo.id,
        widget.entry.path,
        value,
      ),
    );
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
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
      final controller = _SdocTextController.fromNode(cell);
      _watch(controller);
      return controller;
    });
  }

  Widget _mediaPlaceholder(String zh, String en) {
    final label = L10n.of(context).zh ? zh : en;
    return Container(
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

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
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = widget.onTap != null),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: widget.onTap == null
                  ? AppColors.borderStrong
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
