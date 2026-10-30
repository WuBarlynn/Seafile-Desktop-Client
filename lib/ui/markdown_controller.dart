import 'package:flutter/material.dart';

/// Styles Markdown syntax in place so the editor itself is the preview.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  static final _heading = RegExp(r'^(#{1,6})\s');
  static final _quote = RegExp(r'^\s*>\s?');
  static final _fence = RegExp(r'^\s*```');
  static final _inline = RegExp(r'(\*\*[^*]+\*\*|__[^_]+__|`[^`]+`|~~[^~]+~~|\*[^*\n]+\*|_[^_\n]+_|\[[^\]]+\]\([^)]+\))');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (withComposing && value.composing.isValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final base = style ?? const TextStyle();
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    var inCode = false;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final newline = index == lines.length - 1 ? '' : '\n';
      if (_fence.hasMatch(line)) {
        inCode = !inCode;
        spans.add(TextSpan(text: '$line$newline', style: base.copyWith(fontFamily: 'Menlo', color: const Color(0xFF8F959E))));
        continue;
      }
      if (inCode) {
        spans.add(TextSpan(text: '$line$newline', style: base.copyWith(fontFamily: 'Menlo', fontSize: 13, color: const Color(0xFF3D4B5C))));
        continue;
      }
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final sizes = [0.0, 30.0, 25.0, 21.0, 18.0, 16.0, 15.0];
        spans.add(TextSpan(
          text: '$line$newline',
          style: base.copyWith(fontSize: sizes[level], fontWeight: FontWeight.w700, height: 1.45),
        ));
        continue;
      }
      if (_quote.hasMatch(line)) {
        spans.add(TextSpan(
          text: '$line$newline',
          style: base.copyWith(color: const Color(0xFF6B7280), fontStyle: FontStyle.italic, height: 1.6),
        ));
        continue;
      }
      final bullet = RegExp(r'^(\s*)([-*+]|\d+[.)])\s').firstMatch(line);
      if (bullet != null) {
        spans.add(TextSpan(text: '${bullet.group(1)}', style: base));
        spans.add(TextSpan(
          text: '$line'.substring(bullet.group(1)!.length),
          style: base.copyWith(color: const Color(0xFF374151), height: 1.6),
        ));
        spans.add(TextSpan(text: newline, style: base));
        continue;
      }
      _appendInline(spans, '$line$newline', base);
    }
    return TextSpan(style: base, children: spans);
  }

  void _appendInline(List<TextSpan> spans, String line, TextStyle base) {
    var start = 0;
    for (final match in _inline.allMatches(line)) {
      if (match.start > start) {
        spans.add(TextSpan(text: line.substring(start, match.start), style: base));
      }
      final token = match.group(0)!;
      TextStyle? style;
      String? visible = token;
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
    if (start < line.length) {
      spans.add(TextSpan(text: line.substring(start), style: base));
    }
  }
}
