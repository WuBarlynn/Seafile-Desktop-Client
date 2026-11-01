import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/code_highlight.dart';
import '../core/theme.dart';

class CodeViewer extends StatelessWidget {
  const CodeViewer({
    super.key,
    required this.text,
    required this.fileName,
    this.scrollController,
  });

  final String text;
  final String fileName;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final highlighter = CodeHighlighter.forFile(fileName);
    final blockStarts = highlighter.blockCommentStarts(lines);
    final gutterWidth = _gutterWidth(lines.length);
    final numberStyle = CodeHighlighter.codeStyle.copyWith(color: AppColors.muted);
    return Scrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: gutterWidth,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.fromLTRB(0, 3, 10, 3),
                  decoration: const BoxDecoration(
                    color: AppColors.tableHeader,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.right,
                    style: numberStyle,
                    strutStyle: CodeHighlighter.codeStrut,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 3, 24, 3),
                    child: SelectableText.rich(
                      TextSpan(
                        style: CodeHighlighter.codeStyle,
                        children: highlighter.highlightLine(
                          line,
                          CodeHighlighter.codeStyle,
                          inBlockComment: blockStarts[index],
                        ),
                      ),
                      style: CodeHighlighter.codeStyle,
                      strutStyle: CodeHighlighter.codeStrut,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _gutterWidth(int lineCount) {
    return (lineCount.toString().length * 8 + 26).clamp(44, 92).toDouble();
  }
}

class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.controller,
    required this.fileName,
    this.readOnly = false,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String fileName;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  double _charWidth = 8;
  String? _gutter;
  int _gutterCount = 0;
  String _lastText = '';
  int _lastTextLength = 0;
  double _codeWidth = 0;

  static const _lineHeight = 13 * 1.65;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    _lastText = widget.controller.text;
    _lastTextLength = _lastText.length;
    _charWidth = _measure('M');
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  double _measure(String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: CodeHighlighter.codeStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  void _handleControllerChange() {
    final text = widget.controller.text;
    if (text != _lastText) {
      final delta = text.length - _lastTextLength;
      var widen = delta.abs() > 120;
      if (!widen && text.isNotEmpty) {
        final selection = widget.controller.selection;
        final offset = selection.isValid ? selection.extentOffset.clamp(0, text.length) : text.length;
        var start = offset;
        while (start > 0 && text[start - 1] != '\n') {
          start--;
        }
        var end = offset;
        while (end < text.length && text[end] != '\n') {
          end++;
        }
        var estimate = 0.0;
        for (final rune in text.substring(start, end).runes) {
          if (rune == 9) {
            estimate += 8 * 7.8;
          } else if (rune >= 0x2E80) {
            estimate += 13.0;
          } else {
            estimate += 7.8;
          }
        }
        widen = estimate + 80 > _codeWidth;
      }
      _lastText = text;
      _lastTextLength = text.length;
      if (widen) setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCaret());
  }

  void _scrollToCaret() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.extentOffset < 0) return;
    final offset = selection.extentOffset.clamp(0, widget.controller.text.length);
    final before = widget.controller.text.substring(0, offset);
    final line = '\n'.allMatches(before).length;
    final column = offset - before.lastIndexOf('\n') - 1;
    final y = 12 + line * _lineHeight;
    final x = 16 + column * _charWidth;
    _ensureVisible(_vertical, y, viewportPadding: 28);
    _ensureVisible(_horizontal, x, viewportPadding: 48);
  }

  void _ensureVisible(ScrollController controller, double target, {required double viewportPadding}) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return;
    final current = position.pixels;
    if (target >= current + viewportPadding && target <= current + viewport - viewportPadding) {
      return;
    }
    final destination = (target - viewport / 2).clamp(0.0, position.maxScrollExtent);
    controller.animateTo(destination, duration: AppMotion.hover, curve: AppMotion.curve);
  }

  String _gutterFor(int count) {
    if (_gutter == null || _gutterCount != count) {
      _gutterCount = count;
      _gutter = List<String>.generate(count, (index) => '${index + 1}').join('\n');
    }
    return _gutter!;
  }

  double _contentWidth(String text) {
    var widest = '';
    var widestScore = 0.0;
    for (final line in text.split('\n')) {
      var score = 0.0;
      for (final rune in line.runes) {
        if (rune == 9) {
          score += 8 * 7.8;
        } else if (rune >= 0x2E80) {
          score += 13.0;
        } else {
          score += 7.8;
        }
      }
      if (score > widestScore) {
        widestScore = score;
        widest = line;
      }
    }
    if (widest.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: widest, style: CodeHighlighter.codeStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.controller.text.split('\n');
    final lineCount = lines.length;
    final gutterWidth = CodeViewer._gutterWidth(lineCount);
    final measured = _contentWidth(widget.controller.text);
    final numberStyle = CodeHighlighter.codeStyle.copyWith(color: AppColors.muted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final codeWidth = math.max(
          math.max(0.0, constraints.maxWidth - gutterWidth),
          measured * 1.15 + 16 + 24 + 120,
        ).toDouble();
        _codeWidth = codeWidth;
        return Scrollbar(
          controller: _vertical,
          child: SingleChildScrollView(
            controller: _vertical,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: gutterWidth,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.tableHeader,
                      border: Border(right: BorderSide(color: AppColors.border)),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: gutterWidth,
                      padding: const EdgeInsets.fromLTRB(0, 12, 10, 24),
                      child: Text(
                        _gutterFor(lineCount),
                        key: const ValueKey('code-editor-gutter'),
                        textAlign: TextAlign.right,
                        style: numberStyle,
                        strutStyle: CodeHighlighter.codeStrut,
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontal,
                          child: SizedBox(
                            width: codeWidth,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 24, 24),
                              child: TextField(
                                key: const ValueKey('code-editor-field'),
                                controller: widget.controller,
                                focusNode: widget.focusNode,
                                readOnly: widget.readOnly,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: CodeHighlighter.codeStyle,
                                strutStyle: CodeHighlighter.codeStrut,
                                cursorColor: AppColors.primary,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: widget.onChanged,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
