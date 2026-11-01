import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/ui/csv_viewer.dart';

void main() {
  test('parses quoted cells, escaped quotes and embedded newlines', () {
    final rows = parseCsv('name,note\n"a,b","line one\nline two"\n"say ""hi""",ok\n');
    expect(rows.length, 3);
    expect(rows[0], ['name', 'note']);
    expect(rows[1], ['a,b', 'line one\nline two']);
    expect(rows[2], ['say "hi"', 'ok']);
  });

  test('ignores a trailing empty line', () {
    expect(parseCsv('a,b\n1,2\n'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });

  testWidgets('csv preview renders a table with row numbers', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: SizedBox(
          height: 320,
          width: 640,
          child: CsvTableView(text: 'name,note\nalice,hello\nbob,"a,b"\n'),
        ),
      ),
    ));
    expect(find.text('#'), findsOneWidget);
    expect(find.text('name'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('a,b'), findsOneWidget);
    expect(find.byKey(const ValueKey('csv-row-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('csv-row-1')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
