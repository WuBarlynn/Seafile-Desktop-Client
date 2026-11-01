import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/code_highlight.dart';
import 'package:seafile_desktop/core/file_kind.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/ui/code_viewer.dart';

bool _hasNonBaseColor(List<InlineSpan> spans) {
  for (final span in spans) {
    if (span is! TextSpan) continue;
    final color = span.style?.color;
    if (color != null && color != AppColors.text) return true;
    final children = span.children;
    if (children != null && _hasNonBaseColor(children)) return true;
  }
  return false;
}

void main() {
  const extensions = [
    'ac', 'am', 'bat', 'c', 'cc', 'cmake', 'cpp', 'cs', 'css', 'diff', 'el', 'h', 'html', 'htm',
    'java', 'js', 'json', 'less', 'make', 'org', 'php', 'pl', 'properties', 'py', 'rb', 'scala',
    'script', 'sh', 'sql', 'txt', 'text', 'tex', 'vi', 'vim', 'xhtml', 'xml', 'log', 'csv',
    'groovy', 'rst', 'patch', 'go', 'yml',
  ];

  const samples = {
    'ac': 'AC_INIT([demo])',
    'am': 'AM_INIT_AUTOMAKE([foreign])',
    'bat': 'if exist file.txt echo yes',
    'c': 'int main(void) { return 0; }',
    'cc': 'class Foo { public: int value; };',
    'cmake': 'project(Demo)',
    'cpp': 'namespace demo { class Foo {}; }',
    'cs': 'public class Demo {}',
    'css': 'color: #ff0000;',
    'diff': '+added line',
    'el': '(defun demo () nil)',
    'h': '#define LIMIT 10',
    'html': '<div class="demo">hi</div>',
    'htm': '<p>hello</p>',
    'java': 'public class Demo {}',
    'js': 'const value = 1;',
    'json': '{"enabled": true}',
    'less': '.demo { color: red; }',
    'make': 'include config.mk',
    'org': '* Heading',
    'php': '<?php function demo() {}',
    'pl': 'sub demo { return 1; }',
    'properties': 'demo.key=value',
    'py': 'def demo():',
    'rb': 'def demo',
    'scala': 'def demo(): Unit = {}',
    'script': 'if [ -f demo ]; then',
    'sh': 'if [ -f demo ]; then',
    'sql': 'SELECT * FROM demo;',
    'tex': r'\section{Demo}',
    'vi': 'set number',
    'vim': 'set number',
    'xhtml': '<div class="demo">hi</div>',
    'xml': '<node attr="value" />',
    'log': 'ERROR something failed',
    'csv': '1,"demo"',
    'groovy': 'def demo = 1',
    'rst': '.. note::',
    'patch': '-removed line',
    'go': 'func main() {}',
    'yml': 'enabled: true',
  };

  test('all SeaHub text extensions are previewable', () {
    for (final extension in extensions) {
      expect(FileKind.of('sample.$extension'), FileKind.text, reason: extension);
    }
  });

  test('every listed extension has a language, and syntax types highlight', () {
    for (final extension in extensions) {
      final language = detectCodeLanguage('sample.$extension');
      if (extension == 'txt' || extension == 'text') {
        expect(language, CodeLanguage.plain, reason: extension);
        continue;
      }
      expect(language, isNot(CodeLanguage.plain), reason: extension);
      final sample = samples[extension]!;
      final spans = CodeHighlighter(language).highlightLine(sample, CodeHighlighter.codeStyle);
      expect(_hasNonBaseColor(spans), isTrue, reason: '$extension: $sample');
    }
  });

  test('block comment state ignores delimiters inside strings', () {
    final highlighter = CodeHighlighter(CodeLanguage.c);
    expect(highlighter.blockCommentStarts(['var s = "/*";', 'int x;']), [false, false]);
    expect(
      highlighter.blockCommentStarts(['/*', ' * comment', ' */', 'int x;']),
      [false, true, true, false],
    );
  });

  testWidgets('code viewer shows line numbers and highlighted text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: SizedBox(
          height: 320,
          child: CodeViewer(text: 'def hello():\n  return 42\n', fileName: 'sample.py'),
        ),
      ),
    ));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large previews keep line numbers to the last line', (tester) async {
    final source = List<String>.generate(6000, (index) => 'line ${index + 1}').join('\n');
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          height: 320,
          child: CodeViewer(text: source, fileName: 'sample.txt', scrollController: scroll),
        ),
      ),
    ));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(find.text('6000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('code editor has a gutter and syntax highlighting', (tester) async {
    final controller = CodeEditingController(fileName: 'sample.py', text: 'def hello():\n  return 42\n');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 640,
          height: 320,
          child: CodeEditor(controller: controller, fileName: 'sample.py'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final gutter = tester.widget<Text>(find.byKey(const ValueKey('code-editor-gutter')));
    expect(gutter.data, '1\n2\n3');
    final field = tester.widget<TextField>(find.byKey(const ValueKey('code-editor-field')));
    final span = field.controller!.buildTextSpan(
      context: tester.element(find.byType(CodeEditor)),
      style: CodeHighlighter.codeStyle,
      withComposing: false,
    );
    expect(_hasNonBaseColor(span.children ?? const []), isTrue);
    final gutterHeight = tester.getSize(find.byKey(const ValueKey('code-editor-gutter'))).height;
    final fieldHeight = tester.getSize(find.byKey(const ValueKey('code-editor-field'))).height;
    expect((gutterHeight - fieldHeight).abs(), lessThan(2.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide CJK lines do not break editor line-number alignment', (tester) async {
    final text = '${List.filled(40, '中文注释').join()} value = 1;\nshort';
    final controller = CodeEditingController(fileName: 'sample.py', text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 640,
          height: 320,
          child: CodeEditor(controller: controller, fileName: 'sample.py'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final gutterHeight = tester.getSize(find.byKey(const ValueKey('code-editor-gutter'))).height;
    final fieldHeight = tester.getSize(find.byKey(const ValueKey('code-editor-field'))).height;
    expect((gutterHeight - fieldHeight).abs(), lessThan(2.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing a longer line widens the editor and keeps the gutter aligned', (tester) async {
    final controller = CodeEditingController(fileName: 'sample.py', text: 'x\nb\nc');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 640,
          height: 320,
          child: CodeEditor(controller: controller, fileName: 'sample.py'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    controller.text = '${'x' * 400}\nb\nc';
    await tester.pumpAndSettle();
    final gutterSize = tester.getSize(find.byKey(const ValueKey('code-editor-gutter')));
    final fieldSize = tester.getSize(find.byKey(const ValueKey('code-editor-field')));
    expect((gutterSize.height - fieldSize.height).abs(), lessThan(2.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large code edits keep line numbers past 1000 lines', (tester) async {
    final source = List<String>.generate(1500, (index) => 'line ${index + 1}').join('\n');
    final controller = CodeEditingController(fileName: 'sample.py', text: source);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 640,
          height: 320,
          child: CodeEditor(controller: controller, fileName: 'sample.py'),
        ),
      ),
    ));
    await tester.pump();
    final gutter = tester.widget<Text>(find.byKey(const ValueKey('code-editor-gutter')));
    expect(gutter.data, contains('1500'));
    expect(tester.takeException(), isNull);
  });
}
