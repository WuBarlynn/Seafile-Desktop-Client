import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'theme.dart';

enum CodeLanguage {
  c,
  cpp,
  csharp,
  java,
  javascript,
  typescript,
  go,
  rust,
  swift,
  kotlin,
  scala,
  groovy,
  php,
  python,
  ruby,
  perl,
  shell,
  batch,
  sql,
  json,
  yaml,
  properties,
  makefile,
  cmake,
  autoconf,
  lisp,
  vim,
  css,
  markup,
  latex,
  org,
  rst,
  diff,
  log,
  csv,
  plain,
}

CodeLanguage detectCodeLanguage(String fileName) {
  final extension = p.extension(fileName).toLowerCase().replaceFirst('.', '');
  return switch (extension) {
    'c' || 'h' || 'm' => CodeLanguage.c,
    'cc' || 'cpp' || 'cxx' || 'c++' || 'hh' || 'hpp' || 'hxx' => CodeLanguage.cpp,
    'cs' => CodeLanguage.csharp,
    'java' => CodeLanguage.java,
    'js' || 'mjs' || 'cjs' || 'jsx' => CodeLanguage.javascript,
    'ts' || 'tsx' => CodeLanguage.typescript,
    'go' => CodeLanguage.go,
    'rs' => CodeLanguage.rust,
    'swift' => CodeLanguage.swift,
    'kt' || 'kts' => CodeLanguage.kotlin,
    'scala' || 'sc' => CodeLanguage.scala,
    'groovy' => CodeLanguage.groovy,
    'php' => CodeLanguage.php,
    'py' || 'pyw' => CodeLanguage.python,
    'rb' => CodeLanguage.ruby,
    'pl' || 'pm' => CodeLanguage.perl,
    'sh' || 'bash' || 'zsh' || 'script' => CodeLanguage.shell,
    'bat' || 'cmd' => CodeLanguage.batch,
    'sql' => CodeLanguage.sql,
    'json' => CodeLanguage.json,
    'yml' || 'yaml' => CodeLanguage.yaml,
    'properties' || 'ini' || 'conf' || 'cfg' || 'toml' || 'env' => CodeLanguage.properties,
    'make' || 'mk' || 'mak' => CodeLanguage.makefile,
    'cmake' => CodeLanguage.cmake,
    'ac' || 'am' || 'm4' => CodeLanguage.autoconf,
    'el' || 'lisp' || 'cl' => CodeLanguage.lisp,
    'vi' || 'vim' => CodeLanguage.vim,
    'css' || 'less' || 'scss' || 'sass' => CodeLanguage.css,
    'html' || 'htm' || 'xhtml' || 'xml' || 'svg' || 'xaml' || 'plist' => CodeLanguage.markup,
    'tex' || 'latex' || 'sty' || 'cls' => CodeLanguage.latex,
    'org' => CodeLanguage.org,
    'rst' => CodeLanguage.rst,
    'diff' || 'patch' => CodeLanguage.diff,
    'log' => CodeLanguage.log,
    'csv' || 'tsv' => CodeLanguage.csv,
    _ => CodeLanguage.plain,
  };
}

class CodeHighlighter {
  CodeHighlighter(this.language);

  factory CodeHighlighter.forFile(String fileName) => CodeHighlighter(detectCodeLanguage(fileName));

  final CodeLanguage language;

  static const codeStyle = TextStyle(
    fontFamily: 'Menlo',
    fontSize: 13,
    height: 1.65,
    color: AppColors.text,
  );

  static const codeStrut = StrutStyle(
    fontFamily: 'Menlo',
    fontSize: 13,
    height: 1.65,
    forceStrutHeight: true,
  );

  static const _keywordColor = Color(0xFF8B3DFF);
  static const _stringColor = Color(0xFFB35C00);
  static const _numberColor = Color(0xFF1F7A8C);
  static const _builtinColor = Color(0xFF2E7DD1);
  static const _metaColor = Color(0xFF7A5AF8);
  static const _tagColor = Color(0xFF2E7DD1);
  static const _attributeColor = Color(0xFF0F8B8D);
  static const _linkColor = Color(0xFF2F6FEB);
  static const _addColor = Color(0xFF177245);
  static const _removeColor = Color(0xFFB3261E);

  TextSpan highlightText(String text, TextStyle base) {
    final lines = text.split('\n');
    final starts = blockCommentStarts(lines);
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      spans.addAll(highlightLine(lines[i], base, inBlockComment: starts[i]));
      if (i != lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(style: base, children: spans);
  }

  List<bool> blockCommentStarts(List<String> lines) {
    final delimiters = _blockDelimiters;
    if (delimiters == null) return List<bool>.filled(lines.length, false);
    final (start, end) = delimiters;
    final result = <bool>[];
    var inBlock = false;
    for (final line in lines) {
      result.add(inBlock);
      var index = 0;
      while (index < line.length) {
        if (inBlock) {
          final close = line.indexOf(end, index);
          if (close < 0) break;
          inBlock = false;
          index = close + end.length;
        } else {
          final open = line.indexOf(start, index);
          if (open < 0) break;
          inBlock = true;
          index = open + start.length;
        }
      }
    }
    return result;
  }

  List<InlineSpan> highlightLine(String line, TextStyle base, {bool inBlockComment = false}) {
    if (line.isEmpty) return [TextSpan(text: '', style: base)];
    return switch (language) {
      CodeLanguage.diff => _highlightDiff(line, base),
      CodeLanguage.markup => _highlightMarkup(line, base, inBlockComment: inBlockComment),
      CodeLanguage.json => _highlightJson(line, base),
      CodeLanguage.css => _highlightCss(line, base, inBlockComment: inBlockComment),
      CodeLanguage.yaml => _highlightYaml(line, base),
      CodeLanguage.properties => _highlightProperties(line, base),
      CodeLanguage.latex => _highlightLatex(line, base),
      CodeLanguage.org => _highlightOrg(line, base),
      CodeLanguage.rst => _highlightRst(line, base),
      CodeLanguage.log => _highlightLog(line, base),
      CodeLanguage.csv => _highlightCsv(line, base),
      CodeLanguage.plain => [TextSpan(text: line, style: base)],
      _ => _highlightCode(line, base, inBlockComment: inBlockComment),
    };
  }

  (String, String)? get _blockDelimiters {
    switch (language) {
      case CodeLanguage.c:
      case CodeLanguage.cpp:
      case CodeLanguage.csharp:
      case CodeLanguage.java:
      case CodeLanguage.javascript:
      case CodeLanguage.typescript:
      case CodeLanguage.go:
      case CodeLanguage.rust:
      case CodeLanguage.swift:
      case CodeLanguage.kotlin:
      case CodeLanguage.scala:
      case CodeLanguage.groovy:
      case CodeLanguage.php:
      case CodeLanguage.css:
      case CodeLanguage.sql:
        return ('/*', '*/');
      case CodeLanguage.markup:
        return ('<!--', '-->');
      default:
        return null;
    }
  }

  List<InlineSpan> _highlightCode(String line, TextStyle base, {required bool inBlockComment}) {
    final spec = _codeSpecs[language] ?? _plainSpec;
    final spans = <InlineSpan>[];
    final delimiters = _blockDelimiters;
    var inBlock = inBlockComment;
    var index = 0;
    while (index < line.length) {
      if (inBlock && delimiters != null) {
        final close = line.indexOf(delimiters.$2, index);
        if (close < 0) {
          _add(spans, line.substring(index), base, comment: true);
          return spans;
        }
        final end = close + delimiters.$2.length;
        _add(spans, line.substring(index, end), base, comment: true);
        index = end;
        inBlock = false;
        continue;
      }
      if (delimiters != null && line.startsWith(delimiters.$1, index)) {
        inBlock = true;
        continue;
      }
      final commentPrefix = _commentPrefixAt(line, index, spec);
      if (commentPrefix != null) {
        _add(spans, line.substring(index), base, comment: true);
        break;
      }
      if (spec.vimComment && line[index] == '"') {
        _add(spans, line.substring(index), base, comment: true);
        break;
      }
      final char = line[index];
      if (spec.quotes.contains(char)) {
        final start = index;
        index++;
        while (index < line.length) {
          if (line[index] == '\\' && index + 1 < line.length) {
            index += 2;
            continue;
          }
          if (line[index] == char) {
            index++;
            break;
          }
          index++;
        }
        _add(spans, line.substring(start, index), base, color: _stringColor);
        continue;
      }
      if (spec.preprocessor && char == '#') {
        var end = index + 1;
        while (end < line.length && RegExp(r'[A-Za-z_]').hasMatch(line[end])) {
          end++;
        }
        _add(spans, line.substring(index, end), base, color: _metaColor, bold: true);
        index = end;
        continue;
      }
      if (spec.annotation && char == '@') {
        var end = index + 1;
        while (end < line.length && RegExp(r'[\w.]').hasMatch(line[end])) {
          end++;
        }
        _add(spans, line.substring(index, end), base, color: _metaColor);
        index = end;
        continue;
      }
      if (spec.dollarVariable && char == r'$') {
        final end = _variableEnd(line, index, brace: '{', close: '}');
        _add(spans, line.substring(index, end), base, color: _builtinColor);
        index = end;
        continue;
      }
      if (spec.parenthesisVariable && line.startsWith(r'$(', index)) {
        final end = _balancedEnd(line, index + 1, '(', ')');
        _add(spans, line.substring(index, end), base, color: _builtinColor);
        index = end;
        continue;
      }
      if (spec.braceVariable && line.startsWith(r'${', index)) {
        final end = _balancedEnd(line, index + 1, '{', '}');
        _add(spans, line.substring(index, end), base, color: _builtinColor);
        index = end;
        continue;
      }
      if (spec.percentVariable && char == '%') {
        final end = line.indexOf('%', index + 1);
        final stop = end < 0 ? line.length : end + 1;
        _add(spans, line.substring(index, stop), base, color: _builtinColor);
        index = stop;
        continue;
      }
      if (RegExp(r'\d').hasMatch(char)) {
        var end = index + 1;
        while (end < line.length && RegExp(r'[0-9a-fA-FxX._eE+\-]').hasMatch(line[end])) {
          end++;
        }
        _add(spans, line.substring(index, end), base, color: _numberColor);
        index = end;
        continue;
      }
      if (_identifierStart.hasMatch(char)) {
        var end = index + 1;
        while (end < line.length && _identifierPart.hasMatch(line[end])) {
          end++;
        }
        final word = line.substring(index, end);
        final normalized = spec.caseInsensitive ? word.toLowerCase() : word;
        if (spec.keywords.contains(normalized)) {
          _add(spans, word, base, color: _keywordColor, bold: true);
        } else if (spec.builtins.contains(normalized) ||
            (language == CodeLanguage.autoconf && (word.startsWith('AC_') || word.startsWith('AM_')))) {
          _add(spans, word, base, color: _builtinColor);
        } else {
          _add(spans, word, base);
        }
        index = end;
        continue;
      }
      _add(spans, char, base);
      index++;
    }
    return spans;
  }

  int _variableEnd(String line, int start, {required String brace, required String close}) {
    var index = start + 1;
    if (index < line.length && line[index] == brace) {
      return _balancedEnd(line, index, brace, close);
    }
    while (index < line.length && _identifierPart.hasMatch(line[index])) {
      index++;
    }
    return index;
  }

  int _balancedEnd(String line, int openIndex, String open, String close) {
    var depth = 0;
    for (var index = openIndex; index < line.length; index++) {
      if (line[index] == open) depth++;
      if (line[index] == close) {
        depth--;
        if (depth == 0) return index + 1;
      }
    }
    return line.length;
  }

  String? _commentPrefixAt(String line, int index, _LanguageSpec spec) {
    for (final prefix in spec.lineComments) {
      if (prefix == 'REM') {
        if (index == 0 && line.toUpperCase().startsWith('REM ') || index == 0 && line.toUpperCase() == 'REM') {
          return prefix;
        }
        continue;
      }
      if (line.startsWith(prefix, index)) return prefix;
    }
    return null;
  }

  void _add(List<InlineSpan> spans, String text, TextStyle base, {Color? color, bool bold = false, bool comment = false}) {
    if (text.isEmpty) return;
    spans.add(TextSpan(
      text: text,
      style: base.copyWith(
        color: comment ? AppColors.muted : color,
        fontWeight: bold ? FontWeight.w600 : null,
        fontStyle: comment ? FontStyle.italic : null,
      ),
    ));
  }

  List<InlineSpan> _highlightDiff(String line, TextStyle base) {
    final header = line.startsWith('diff ') || line.startsWith('index ') || line.startsWith('+++ ') || line.startsWith('--- ');
    final hunk = line.startsWith('@@');
    final color = header
        ? _metaColor
        : hunk
            ? _builtinColor
            : line.startsWith('+')
                ? _addColor
                : line.startsWith('-')
                    ? _removeColor
                    : line.startsWith('!')
                        ? _stringColor
                        : AppColors.text;
    return [
      TextSpan(
        text: line,
        style: base.copyWith(color: color, fontWeight: header || hunk ? FontWeight.w600 : null),
      ),
    ];
  }

  List<InlineSpan> _highlightMarkup(String line, TextStyle base, {required bool inBlockComment}) {
    final spans = <InlineSpan>[];
    var index = 0;
    if (inBlockComment) {
      final close = line.indexOf('-->');
      if (close < 0) return [TextSpan(text: line, style: base.copyWith(color: AppColors.muted, fontStyle: FontStyle.italic))];
      final end = close + 3;
      _add(spans, line.substring(0, end), base, comment: true);
      index = end;
    }
    final pattern = RegExp(r'''(<!--.*?-->)|(<!DOCTYPE[^>]*>)|(<!\[CDATA\[.*?\]\]>)|(<\/?[\w:.-]+)|(\/?>)|([\w:.-]+)(?=\s*=)|("[^"]*"|'[^']*')|(&[#\w]+;)''');
    var cursor = index;
    for (final match in pattern.allMatches(line, index)) {
      if (match.start > cursor) _add(spans, line.substring(cursor, match.start), base);
      if (match.group(1) != null || match.group(2) != null || match.group(3) != null) {
        _add(spans, match.group(0)!, base, comment: match.group(1) != null, color: _metaColor);
      } else if (match.group(4) != null) {
        _add(spans, match.group(0)!, base, color: _tagColor, bold: true);
      } else if (match.group(5) != null) {
        _add(spans, match.group(0)!, base, color: _tagColor);
      } else if (match.group(6) != null) {
        _add(spans, match.group(0)!, base, color: _attributeColor);
      } else if (match.group(7) != null) {
        _add(spans, match.group(0)!, base, color: _stringColor);
      } else {
        _add(spans, match.group(0)!, base, color: _metaColor);
      }
      cursor = match.end;
    }
    if (cursor < line.length) _add(spans, line.substring(cursor), base);
    return spans;
  }

  List<InlineSpan> _highlightJson(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'("(?:\\.|[^"\\])*")(\s*:)?|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)');
    var cursor = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) _add(spans, line.substring(cursor, match.start), base);
      if (match.group(1) != null) {
        final trailing = match.group(2);
        _add(spans, match.group(1)!, base, color: trailing != null ? _builtinColor : _stringColor);
        if (trailing != null) _add(spans, trailing, base);
      } else if (match.group(3) != null) {
        _add(spans, match.group(0)!, base, color: _keywordColor, bold: true);
      } else {
        _add(spans, match.group(0)!, base, color: _numberColor);
      }
      cursor = match.end;
    }
    if (cursor < line.length) _add(spans, line.substring(cursor), base);
    return spans;
  }

  List<InlineSpan> _highlightCss(String line, TextStyle base, {required bool inBlockComment}) {
    final spans = <InlineSpan>[];
    var index = 0;
    if (inBlockComment) {
      final close = line.indexOf('*/');
      if (close < 0) return [TextSpan(text: line, style: base.copyWith(color: AppColors.muted, fontStyle: FontStyle.italic))];
      _add(spans, line.substring(0, close + 2), base, comment: true);
      index = close + 2;
    }
    final commentIndex = line.indexOf('/*', index);
    final slashComment = language == CodeLanguage.css && line.startsWith('//', index) ? index : line.indexOf('//', index);
    var codeEnd = line.length;
    if (commentIndex >= 0) codeEnd = commentIndex;
    if (slashComment >= 0 && slashComment < codeEnd) codeEnd = slashComment;
    final code = line.substring(index, codeEnd);
    final pattern = RegExp(r'''(@[\w-]+)|(#[0-9a-fA-F]{3,8})|("[^"]*"|'[^']*')|(-?\b\d+(?:\.\d+)?(?:px|em|rem|vh|vw|%|s|ms|deg|fr|pt|ex|ch)?)|([\w-]+)(?=\s*:)''');
    var cursor = 0;
    for (final match in pattern.allMatches(code)) {
      if (match.start > cursor) _add(spans, code.substring(cursor, match.start), base);
      if (match.group(1) != null) {
        _add(spans, match.group(0)!, base, color: _metaColor, bold: true);
      } else if (match.group(2) != null) {
        _add(spans, match.group(0)!, base, color: _numberColor);
      } else if (match.group(3) != null) {
        _add(spans, match.group(0)!, base, color: _stringColor);
      } else if (match.group(4) != null) {
        _add(spans, match.group(0)!, base, color: _numberColor);
      } else {
        _add(spans, match.group(0)!, base, color: _builtinColor);
      }
      cursor = match.end;
    }
    if (cursor < code.length) _add(spans, code.substring(cursor), base);
    if (codeEnd < line.length) _add(spans, line.substring(codeEnd), base, comment: true);
    return spans;
  }

  List<InlineSpan> _highlightYaml(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final comment = _commentStartOutsideQuotes(line, '#');
    final code = line.substring(0, comment ?? line.length);
    final key = RegExp(r'^(\s*)([\w.-]+)(\s*:)').firstMatch(code);
    var cursor = 0;
    if (key != null) {
      _add(spans, key.group(1)!, base);
      _add(spans, key.group(2)!, base, color: _builtinColor, bold: true);
      _add(spans, key.group(3)!, base);
      cursor = key.end;
    }
    final pattern = RegExp(r'''("[^"]*"|'[^']*')|(\b(?:true|false|null|yes|no|on|off)\b)|(-?\b\d+(?:\.\d+)?\b)|(&[\w-]+|\*[\w-]+|![\w!-]+)''');
    for (final match in pattern.allMatches(code, cursor)) {
      if (match.start > cursor) _add(spans, code.substring(cursor, match.start), base);
      if (match.group(1) != null) {
        _add(spans, match.group(0)!, base, color: _stringColor);
      } else if (match.group(2) != null) {
        _add(spans, match.group(0)!, base, color: _keywordColor);
      } else if (match.group(3) != null) {
        _add(spans, match.group(0)!, base, color: _numberColor);
      } else {
        _add(spans, match.group(0)!, base, color: _metaColor);
      }
      cursor = match.end;
    }
    if (cursor < code.length) _add(spans, code.substring(cursor), base);
    if (comment != null) _add(spans, line.substring(comment), base, comment: true);
    return spans;
  }

  List<InlineSpan> _highlightProperties(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('[') && trimmed.contains(']')) {
      final start = line.indexOf('[');
      _add(spans, line.substring(0, start), base);
      _add(spans, line.substring(start), base, color: _builtinColor, bold: true);
      return spans;
    }
    final comment = _commentStartOutsideQuotes(line, '#', ';', '!');
    final code = line.substring(0, comment ?? line.length);
    final separator = RegExp(r'([=:])(.*)$').firstMatch(code);
    if (separator != null) {
      final key = code.substring(0, separator.start).trimRight();
      final gap = code.substring(key.length, separator.start);
      _add(spans, key, base, color: _builtinColor, bold: true);
      _add(spans, gap, base);
      _add(spans, separator.group(1)!, base, color: _metaColor);
      spans.add(_highlightPropertyValue(separator.group(2)!, base));
    } else {
      _add(spans, code, base);
    }
    if (comment != null) _add(spans, line.substring(comment), base, comment: true);
    return spans;
  }

  InlineSpan _highlightPropertyValue(String value, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'''("[^"]*"|'[^']*')|(\b(?:true|false|null|yes|no|on|off)\b)|(-?\b\d+(?:\.\d+)?\b)''');
    var cursor = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > cursor) spans.add(TextSpan(text: value.substring(cursor, match.start), style: base));
      final color = match.group(1) != null
          ? _stringColor
          : match.group(2) != null
              ? _keywordColor
              : _numberColor;
      spans.add(TextSpan(text: match.group(0), style: base.copyWith(color: color)));
      cursor = match.end;
    }
    if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor), style: base));
    return TextSpan(style: base, children: spans);
  }

  List<InlineSpan> _highlightLatex(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final comment = line.indexOf('%');
    final code = line.substring(0, comment < 0 ? line.length : comment);
    final pattern = RegExp(r'(\\[a-zA-Z@]+\*?)|(\$\$?[^$]*\$\$?)|([{}])|(\b\d+(?:\.\d+)?\b)');
    var cursor = 0;
    for (final match in pattern.allMatches(code)) {
      if (match.start > cursor) _add(spans, code.substring(cursor, match.start), base);
      if (match.group(1) != null) {
        _add(spans, match.group(0)!, base, color: _keywordColor, bold: true);
      } else if (match.group(2) != null) {
        _add(spans, match.group(0)!, base, color: _stringColor);
      } else if (match.group(3) != null) {
        _add(spans, match.group(0)!, base, color: _metaColor);
      } else {
        _add(spans, match.group(0)!, base, color: _numberColor);
      }
      cursor = match.end;
    }
    if (cursor < code.length) _add(spans, code.substring(cursor), base);
    if (comment >= 0) _add(spans, line.substring(comment), base, comment: true);
    return spans;
  }

  List<InlineSpan> _highlightOrg(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final heading = RegExp(r'^(\*+)(\s+)(.*)$').firstMatch(line);
    if (heading != null) {
      _add(spans, heading.group(1)!, base, color: _builtinColor, bold: true);
      _add(spans, heading.group(2)!, base);
      spans.add(_highlightOrgInline(heading.group(3)!, base));
      return spans;
    }
    if (line.trimLeft().startsWith('#')) {
      _add(spans, line, base, comment: true);
      return spans;
    }
    final checkbox = RegExp(r'^(\s*[-+]\s+)(\[[ Xx-]\])').firstMatch(line);
    if (checkbox != null) {
      _add(spans, checkbox.group(1)!, base);
      _add(spans, checkbox.group(2)!, base, color: _metaColor, bold: true);
      spans.add(_highlightOrgInline(line.substring(checkbox.end), base));
      return spans;
    }
    spans.add(_highlightOrgInline(line, base));
    return spans;
  }

  InlineSpan _highlightOrgInline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\[\[[^\]]+\](?:\[[^\]]*\])?\])|(\*[^*]+\*|\/[^/]+\/|=[^=]+=|~[^~]+~)|(\b(?:TODO|DONE|WAITING|NEXT|CANCELLED|DELEGATED|IN-PROGRESS)\b)');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) spans.add(TextSpan(text: text.substring(cursor, match.start), style: base));
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(0), style: base.copyWith(color: _linkColor, decoration: TextDecoration.underline)));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(0), style: base.copyWith(color: _stringColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: match.group(0), style: base.copyWith(color: _keywordColor, fontWeight: FontWeight.w600)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: base));
    return TextSpan(style: base, children: spans);
  }

  List<InlineSpan> _highlightRst(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    if (RegExp(r'^\s*\.\.').hasMatch(line)) {
      _add(spans, line, base, comment: true);
      return spans;
    }
    if (RegExp(r'^\s*[=\-~^"#*+`]{4,}\s*$').hasMatch(line)) {
      _add(spans, line, base, color: _metaColor);
      return spans;
    }
    final pattern = RegExp(r'(`[^`]+`_?|``[^`]+``)|(:[\w-]+:)|(\*\*[^*]+\*\*|\*[^*]+\*)');
    var cursor = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) _add(spans, line.substring(cursor, match.start), base);
      if (match.group(1) != null) {
        _add(spans, match.group(0)!, base, color: _stringColor);
      } else if (match.group(2) != null) {
        _add(spans, match.group(0)!, base, color: _metaColor);
      } else {
        _add(spans, match.group(0)!, base, color: _keywordColor, bold: true);
      }
      cursor = match.end;
    }
    if (cursor < line.length) _add(spans, line.substring(cursor), base);
    return spans;
  }

  List<InlineSpan> _highlightLog(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\b(ERROR|FATAL|CRITICAL|WARN(?:ING)?|INFO|DEBUG|TRACE)\b', caseSensitive: false);
    var cursor = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) _add(spans, line.substring(cursor, match.start), base);
      final level = match.group(0)!.toUpperCase();
      final color = switch (level) {
        'ERROR' || 'FATAL' || 'CRITICAL' => _removeColor,
        'WARN' || 'WARNING' => _stringColor,
        'INFO' => _builtinColor,
        _ => AppColors.muted,
      };
      _add(spans, match.group(0)!, base, color: color, bold: true);
      cursor = match.end;
    }
    if (cursor < line.length) _add(spans, line.substring(cursor), base);
    return spans;
  }

  List<InlineSpan> _highlightCsv(String line, TextStyle base) {
    final spans = <InlineSpan>[];
    var index = 0;
    var field = 0;
    while (index < line.length) {
      if (line[index] == '"' || line[index] == "'") {
        final quote = line[index];
        final start = index;
        index++;
        while (index < line.length) {
          if (line[index] == quote && (index + 1 >= line.length || line[index + 1] == ',')) {
            index++;
            break;
          }
          index++;
        }
        _add(spans, line.substring(start, index), base, color: _stringColor);
      } else {
        var end = line.indexOf(',', index);
        if (end < 0) end = line.length;
        final value = line.substring(index, end);
        if (RegExp(r'^\s*-?\d+(?:\.\d+)?\s*$').hasMatch(value)) {
          _add(spans, value, base, color: _numberColor);
        } else {
          _add(spans, value, base, color: field == 0 ? _builtinColor : null);
        }
        index = end;
      }
      if (index < line.length && line[index] == ',') {
        _add(spans, ',', base, color: AppColors.muted);
        index++;
        field++;
      } else if (index < line.length) {
        index++;
      }
    }
    return spans;
  }

  int? _commentStart(String line, List<String> prefixes) {
    var quote = '';
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (quote.isNotEmpty) {
        if (char == '\\') {
          index++;
          continue;
        }
        if (char == quote) quote = '';
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
        continue;
      }
      for (final prefix in prefixes) {
        if (line.startsWith(prefix, index)) return index;
      }
    }
    return null;
  }

  int? _commentStartOutsideQuotes(String line, String first, [String? second, String? third]) {
    final prefixes = [first, if (second != null) second, if (third != null) third];
    return _commentStart(line, prefixes);
  }

  static final _identifierStart = RegExp(r'[A-Za-z_$]');
  static final _identifierPart = RegExp(r'[\w$]');

  static final _plainSpec = _LanguageSpec();

  static Set<String> _words(String value) => value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toSet();

  static final Map<CodeLanguage, _LanguageSpec> _codeSpecs = {
    CodeLanguage.c: _LanguageSpec(
      keywords: _words('auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while _Bool _Complex _Imaginary true false NULL'),
      builtins: _words('printf scanf malloc free memcpy memset strlen strcmp fopen fclose FILE size_t uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t'),
      lineComments: const ['//'],
      preprocessor: true,
    ),
    CodeLanguage.cpp: _LanguageSpec(
      keywords: _words('alignas alignof and and_eq asm auto bitand bitor bool break case catch char char16_t char32_t class compl const constexpr const_cast continue decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or or_eq private protected public register reinterpret_cast return short signed sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor xor_eq override final'),
      builtins: _words('std string vector map unordered_map set unordered_set unique_ptr shared_ptr make_unique make_shared cout cerr cin endl size_t'),
      lineComments: const ['//'],
      preprocessor: true,
    ),
    CodeLanguage.csharp: _LanguageSpec(
      keywords: _words('abstract as base bool break byte case catch char checked class const continue decimal default delegate do double else enum event explicit extern false finally fixed float for foreach goto if implicit in int interface internal is lock long namespace new null object operator out override params private protected public readonly ref return sbyte sealed short sizeof stackalloc static string struct switch this throw true try typeof uint ulong unchecked unsafe ushort using virtual void volatile while async await var record get set init value partial yield nameof'),
      builtins: _words('Console Math String List Dictionary Task DateTime Guid Exception IEnumerable'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.java: _LanguageSpec(
      keywords: _words('abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public record return sealed permits short static strictfp super switch synchronized this throw throws transient try var void volatile while true false null yield'),
      builtins: _words('String System Math List ArrayList Map HashMap Set HashSet Optional Stream Integer Long Double Object Exception Runnable Thread'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.javascript: _LanguageSpec(
      keywords: _words('async await break case catch class const continue debugger default delete do else export extends false finally for from function get if import in instanceof let new null of return set static super switch this throw true try typeof undefined var void while with yield'),
      builtins: _words('console document window require module exports Promise Array Object String Number Boolean Math JSON Map Set Date RegExp Error'),
      lineComments: const ['//'],
      quotes: const ['"', "'", '`'],
    ),
    CodeLanguage.typescript: _LanguageSpec(
      keywords: _words('abstract any as async await boolean break case catch class const continue declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface keyof let namespace new never null number object of private protected public readonly return satisfies set static string super switch symbol this throw true try type typeof undefined unknown var void while yield'),
      builtins: _words('console Promise Array Object String Number Boolean Math JSON Map Set Date Error Record Partial Readonly Pick Omit'),
      lineComments: const ['//'],
      quotes: const ['"', "'", '`'],
    ),
    CodeLanguage.go: _LanguageSpec(
      keywords: _words('break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var true false nil iota'),
      builtins: _words('append cap close complex copy delete imag len make new panic print println real recover bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr'),
      lineComments: const ['//'],
    ),
    CodeLanguage.rust: _LanguageSpec(
      keywords: _words('as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while'),
      builtins: _words('Box Vec String Option Result Some None Ok Err println format vec panic assert assert_eq derive'),
      lineComments: const ['//'],
      quotes: const ['"'],
    ),
    CodeLanguage.swift: _LanguageSpec(
      keywords: _words('associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private protocol public rethrows static struct subscript typealias var break case continue default defer do else fallthrough for guard if in repeat return switch where while as Any catch false is nil super self Self throw throws true try async await some any'),
      builtins: _words('String Int Double Float Bool Array Dictionary Set Optional Result print'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.kotlin: _LanguageSpec(
      keywords: _words('as break class continue do else false for fun if in interface is null object package return super this throw true try typealias typeof val var when while by catch constructor delegate dynamic field file finally get import init param property receiver set setparam where actual abstract annotation companion const crossinline data enum expect external final infix inline inner internal lateinit noinline open operator out override private protected public reified sealed suspend tailrec vararg'),
      builtins: _words('String Int Long Double Float Boolean List MutableList Map MutableMap Set Array println'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.scala: _LanguageSpec(
      keywords: _words('abstract case catch class def do else extends false final finally for forSome if implicit import lazy match new null object override package private protected return sealed super this throw trait try true type val var while with yield given using enum export then'),
      builtins: _words('String Int Long Double Float Boolean List Seq Map Set Option Some None Either println'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.groovy: _LanguageSpec(
      keywords: _words('abstract as assert break case catch class const continue def default do else enum extends final finally for goto if implements import in instanceof interface native new null package private protected public return static strictfp super switch synchronized this throw throws trait transient true false try var void volatile while it'),
      builtins: _words('String Integer List Map Set println each collect findAll'),
      lineComments: const ['//'],
      annotation: true,
    ),
    CodeLanguage.php: _LanguageSpec(
      keywords: _words('abstract and array as break callable case catch class clone const continue declare default die do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile eval exit extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new null or print private protected public readonly require require_once return static switch throw trait true false try unset use var while xor yield string int float bool'),
      builtins: _words('strlen count array_map array_filter array_merge json_encode json_decode str_replace preg_match explode implode sprintf echo'),
      lineComments: const ['//', '#'],
      dollarVariable: true,
      annotation: true,
    ),
    CodeLanguage.python: _LanguageSpec(
      keywords: _words('and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield self match case'),
      builtins: _words('print len range str int float list dict set tuple bool open enumerate zip map filter sorted sum min max abs isinstance type object Exception ValueError TypeError'),
      lineComments: const ['#'],
      quotes: const ['"', "'"],
      annotation: true,
    ),
    CodeLanguage.ruby: _LanguageSpec(
      keywords: _words('BEGIN END alias and begin break case class def defined do else elsif end ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield require include extend prepend attr_accessor attr_reader attr_writer private protected public'),
      builtins: _words('puts print p raise loop each map select reject reduce inject Array Hash String Symbol Integer Float Range Proc'),
      lineComments: const ['#'],
      quotes: const ['"', "'"],
    ),
    CodeLanguage.perl: _LanguageSpec(
      keywords: _words('sub use package my our local state if elsif else unless while until for foreach last next redo return print say die warn open close chomp chop split join map grep sort keys values scalar ref bless new and or not xor eq ne lt gt le ge cmp defined undef'),
      builtins: _words('STDIN STDOUT STDERR ARGV ENV @ARGV @_ \$_'),
      lineComments: const ['#'],
      quotes: const ['"', "'"],
      dollarVariable: true,
    ),
    CodeLanguage.shell: _LanguageSpec(
      keywords: _words('if then else elif fi for while until do done case esac in function select time return exit break continue export local readonly declare typeset unset shift source alias echo printf read cd pwd test set trap exec eval'),
      builtins: _words('sudo ls cat grep sed awk curl wget mkdir rm cp mv chmod chown touch find xargs tee head tail sort uniq cut tr wc git docker make'),
      lineComments: const ['#'],
      quotes: const ['"', "'"],
      dollarVariable: true,
    ),
    CodeLanguage.batch: _LanguageSpec(
      keywords: _words('if else for in do goto call set setlocal endlocal echo rem exit errorlevel exist defined not start pushd popd shift pause title cd dir copy del move ren md rd type'),
      lineComments: const ['::', 'REM'],
      quotes: const ['"'],
      percentVariable: true,
      caseInsensitive: true,
    ),
    CodeLanguage.sql: _LanguageSpec(
      keywords: _words('select from where insert into values update set delete create table alter drop join left right inner outer on group by order having limit offset as and or not null is in like between distinct count sum avg min max union all case when then else end primary key foreign references index view database grant revoke begin commit rollback transaction with exists if'),
      builtins: _words('int integer bigint smallint varchar char text date datetime timestamp boolean decimal numeric float double serial primary'),
      lineComments: const ['--'],
      caseInsensitive: true,
    ),
    CodeLanguage.makefile: _LanguageSpec(
      keywords: _words('include define endef ifeq ifneq ifdef ifndef else endif export unexport override vpath shell wildcard patsubst subst foreach call eval origin flavor info warning error .PHONY .SUFFIXES .DEFAULT .PRECIOUS .INTERMEDIATE .SECONDARY .DELETE_ON_ERROR'),
      lineComments: const ['#'],
      parenthesisVariable: true,
      braceVariable: true,
    ),
    CodeLanguage.cmake: _LanguageSpec(
      keywords: _words('cmake_minimum_required project set unset message if elseif else endif foreach endforeach while endwhile function endfunction macro endmacro add_executable add_library add_subdirectory add_custom_command add_custom_target target_link_libraries target_include_directories target_compile_features target_compile_definitions target_compile_options install find_package include option configure_file list string file get_filename_component execute_process return'),
      builtins: _words('CMAKE_SOURCE_DIR CMAKE_BINARY_DIR CMAKE_CXX_STANDARD PROJECT_SOURCE_DIR PROJECT_BINARY_DIR'),
      lineComments: const ['#'],
      braceVariable: true,
    ),
    CodeLanguage.autoconf: _LanguageSpec(
      keywords: _words('dnl ifdef ifelse define undefine include sinclude divert undivert changequote changecom m4_define m4_include m4_ifdef m4_ifelse'),
      builtins: _words('AC_INIT AC_CONFIG_SRCDIR AC_PROG_CC AC_PROG_CXX AC_CHECK_HEADERS AC_CHECK_FUNCS AC_CHECK_LIB AC_OUTPUT AM_INIT_AUTOMAKE AM_PROG_AR AM_CONDITIONAL'),
      lineComments: const ['#', 'dnl'],
      braceVariable: true,
    ),
    CodeLanguage.lisp: _LanguageSpec(
      keywords: _words('defun defvar defmacro defparameter defconstant lambda let let* setq setf if cond when unless progn prog1 while dolist dotimes car cdr cons list append mapcar require provide interactive message error'),
      builtins: _words('nil t format quote function'),
      lineComments: const [';'],
      quotes: const ['"'],
      caseInsensitive: true,
    ),
    CodeLanguage.vim: _LanguageSpec(
      keywords: _words('set let unlet function endfunction if elseif else endif for endfor while endwhile return call execute normal map noremap nnoremap vnoremap inoremap command autocmd augroup syntax highlight echo echom silent try catch finally throw finish'),
      builtins: _words('g: v: b: w: t: s: a:'),
      lineComments: const [],
      quotes: const ["'"],
      vimComment: true,
    ),
  };
}

class CodeEditingController extends TextEditingController {
  CodeEditingController({required this.fileName, super.text});

  final String fileName;
  late final CodeHighlighter highlighter = CodeHighlighter.forFile(fileName);

  String? _cachedText;
  TextStyle? _cachedStyle;
  TextSpan? _cachedSpan;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? CodeHighlighter.codeStyle;
    if (_cachedText == text && _cachedStyle == base && _cachedSpan != null) {
      return _cachedSpan!;
    }
    final span = text.length > 2 * 1024 * 1024
        ? TextSpan(text: text, style: base)
        : highlighter.highlightText(text, base);
    _cachedText = text;
    _cachedStyle = base;
    _cachedSpan = span;
    return span;
  }
}

class _LanguageSpec {
  _LanguageSpec({
    Set<String>? keywords,
    Set<String>? builtins,
    List<String>? lineComments,
    List<String>? quotes,
    this.preprocessor = false,
    this.annotation = false,
    this.dollarVariable = false,
    this.parenthesisVariable = false,
    this.braceVariable = false,
    this.percentVariable = false,
    this.caseInsensitive = false,
    this.vimComment = false,
  })  : keywords = keywords ?? const {},
        builtins = builtins ?? const {},
        lineComments = lineComments ?? const [],
        quotes = quotes ?? const ['"', "'"];
  final Set<String> keywords;
  final Set<String> builtins;
  final List<String> lineComments;
  final List<String> quotes;
  final bool preprocessor;
  final bool annotation;
  final bool dollarVariable;
  final bool parenthesisVariable;
  final bool braceVariable;
  final bool percentVariable;
  final bool caseInsensitive;
  final bool vimComment;
}
