import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/file_kind.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/ui/code_viewer.dart';

void main() {
  test('all SeaHub text extensions are previewable', () {
    const extensions = [
      'ac', 'am', 'bat', 'c', 'cc', 'cmake', 'cpp', 'cs', 'css', 'diff', 'el', 'h', 'html', 'htm',
      'java', 'js', 'json', 'less', 'make', 'org', 'php', 'pl', 'properties', 'py', 'rb', 'scala',
      'script', 'sh', 'sql', 'txt', 'text', 'tex', 'vi', 'vim', 'xhtml', 'xml', 'log', 'csv',
      'groovy', 'rst', 'patch', 'go', 'yml',
    ];
    for (final extension in extensions) {
      expect(FileKind.of('sample.$extension'), FileKind.text, reason: extension);
    }
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
}
