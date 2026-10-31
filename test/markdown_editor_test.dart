import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/ui/markdown_editor.dart';

void main() {
  testWidgets('Enter splits a block and Backspace merges it back', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(key: key, initialText: 'alpha', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('alpha')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.text, 'alpha\n\n');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(key.currentState!.text, 'alpha');
  });

  testWidgets('Delete at the end merges the next block', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(key: key, initialText: 'alpha\n\nbeta', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('alpha')));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    field.controller!.selection = TextSelection.collapsed(offset: field.controller!.text.length);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(key.currentState!.text, 'alphabeta');
  });

  testWidgets('Delete removes a following divider block', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(key: key, initialText: 'alpha\n\n---', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('alpha')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(key.currentState!.text, 'alpha');
  });

  testWidgets('Undo and redo restore block edits from the toolbar', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(key: key, initialText: 'alpha', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('alpha')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.text, 'alpha\n\n');
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(key.currentState!.text, 'alpha');
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(key.currentState!.text, 'alpha\n\n');
  });

  testWidgets('IME composition never triggers block splitting or merging', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(key: key, initialText: 'ni', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains('ni')));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    field.controller!.value = const TextEditingValue(
      text: '你',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(key.currentState!.text, '你');
  });
}
