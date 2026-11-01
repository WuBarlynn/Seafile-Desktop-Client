import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/theme.dart';

class CodeViewer extends StatelessWidget {
  const CodeViewer({super.key, required this.text, required this.fileName, this.scrollController});

  final String text;
  final String fileName;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (lines.length > 5000 || text.length > 800000) {
      return Scrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.65, color: AppColors.text),
          ),
        ),
      );
    }
    final language = _languageFor(fileName);
    final gutterWidth = (lines.length.toString().length * 8 + 26).clamp(44, 92).toDouble();
    final codeStyle = const TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.65, color: AppColors.text);
    final numberStyle = codeStyle.copyWith(color: AppColors.muted);
    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: gutterWidth,
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
              decoration: const BoxDecoration(
                color: AppColors.tableHeader,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < lines.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                      child: Text('${index + 1}', textAlign: TextAlign.right, style: numberStyle),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: SelectableText.rich(
                          TextSpan(style: codeStyle, children: _highlight(line, language)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _CodeLanguage _languageFor(String name) {
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'c' || 'h' || 'cc' || 'cpp' || 'cs' || 'java' || 'js' || 'ts' || 'go' || 'rs' || 'swift' || 'kt' || 'scala' || 'php' || 'groovy' || 'less' || 'css' || 'am' || 'ac' => _CodeLanguage.cLike,
      'py' || 'rb' || 'pl' || 'sh' || 'bat' || 'script' || 'make' || 'cmake' || 'el' || 'properties' || 'yml' || 'yaml' || 'conf' || 'ini' || 'toml' => _CodeLanguage.hash,
      'sql' => _CodeLanguage.sql,
      'html' || 'htm' || 'xhtml' || 'xml' || 'svg' => _CodeLanguage.markup,
      'json' => _CodeLanguage.json,
      'diff' || 'patch' => _CodeLanguage.diff,
      _ => _CodeLanguage.plain,
    };
  }

  static List<InlineSpan> _highlight(String line, _CodeLanguage language) {
    if (language == _CodeLanguage.plain || line.isEmpty) {
      return [TextSpan(text: line)];
    }
    if (language == _CodeLanguage.diff) {
      final color = line.startsWith('+') ? AppColors.success : line.startsWith('-') ? AppColors.danger : AppColors.text;
      return [TextSpan(text: line, style: TextStyle(color: color))];
    }
    if (language == _CodeLanguage.markup) {
      final spans = <InlineSpan>[];
      final pattern = RegExp(r'(<!--.*?-->)|(</?[\w:-]+)|(/?>)');
      var cursor = 0;
      for (final match in pattern.allMatches(line)) {
        if (match.start > cursor) spans.add(TextSpan(text: line.substring(cursor, match.start)));
        final text = match.group(0)!;
        final color = match.group(1) != null
            ? AppColors.muted
            : const Color(0xFF2E7DD1);
        spans.add(TextSpan(text: text, style: TextStyle(color: color)));
        cursor = match.end;
      }
      if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
      return spans;
    }

    final commentPrefix = switch (language) {
      _CodeLanguage.sql => '--',
      _CodeLanguage.hash => '#',
      _ => '//',
    };
    final strings = RegExp(r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)''');
    final numbers = RegExp(r'\b\d+(?:\.\d+)?\b');
    final keywords = RegExp(
      r'\b(abstract|async|await|break|case|catch|class|const|continue|def|delete|do|else|enum|export|extends|false|final|finally|for|from|fun|function|if|implements|import|in|interface|is|lambda|let|new|null|or|package|pass|private|protected|public|raise|return|self|static|super|switch|this|throw|true|try|var|void|while|with|yield|fn|mut|pub|use|match|impl|struct|trait|type|where|and|not|elif|except|finally|print|echo|select|insert|update|delete|create|table|where|join|group|order|by|limit|values|from|into|set)\b',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var index = 0;
    var commentIndex = line.indexOf(commentPrefix);
    if (language == _CodeLanguage.cLike) {
      final block = line.indexOf('/*');
      if (block >= 0 && (commentIndex < 0 || block < commentIndex)) commentIndex = block;
    }
    if (language == _CodeLanguage.json && commentIndex >= 0) commentIndex = -1;
    final codeEnd = commentIndex >= 0 ? commentIndex : line.length;

    void addKeywordText(String value) {
      var cursor = 0;
      for (final match in keywords.allMatches(value)) {
        if (match.start > cursor) spans.add(TextSpan(text: value.substring(cursor, match.start)));
        spans.add(TextSpan(text: match.group(0), style: const TextStyle(color: Color(0xFF8B3DFF), fontWeight: FontWeight.w600)));
        cursor = match.end;
      }
      if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));
    }

    void addPlain(String value) {
      if (value.isEmpty) return;
      var cursor = 0;
      for (final match in numbers.allMatches(value)) {
        if (match.start > cursor) addKeywordText(value.substring(cursor, match.start));
        spans.add(TextSpan(text: match.group(0), style: const TextStyle(color: Color(0xFF1F7A8C))));
        cursor = match.end;
      }
      if (cursor < value.length) addKeywordText(value.substring(cursor));
    }

    while (index < codeEnd) {
      final match = strings.matchAsPrefix(line, index);
      if (match != null) {
        spans.add(TextSpan(text: match.group(0), style: const TextStyle(color: Color(0xFFB35C00))));
        index = match.end;
        continue;
      }
      final next = strings.allMatches(line.substring(index)).firstOrNull;
      final stop = next == null ? codeEnd : index + next.start;
      addPlain(line.substring(index, stop));
      index = stop;
    }
    if (commentIndex >= 0) {
      spans.add(TextSpan(text: line.substring(commentIndex), style: const TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic)));
    }
    return spans;
  }
}

enum _CodeLanguage { cLike, hash, sql, markup, json, diff, plain }

extension on Iterable<Match> {
  Match? get firstOrNull => isEmpty ? null : first;
}
