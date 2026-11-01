import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
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

  testWidgets('Editor menus share the compact app menu style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(initialText: 'alpha', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    final toolbarMenus = tester.widgetList<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
    expect(toolbarMenus, isNotEmpty);
    expect(toolbarMenus.every((menu) => menu.popUpAnimationStyle?.duration == AppMotion.menu), isTrue);
    await tester.tap(find.byTooltip('Insert'));
    await tester.pumpAndSettle();
    expect(find.text('Table'), findsWidgets);
    final insertItems = tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
    expect(insertItems, isNotEmpty);
    expect(insertItems.every((item) => item.height == 36), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Block type'));
    await tester.pumpAndSettle();
    expect(find.text('Heading 6'), findsWidgets);
    final blockItems = tester.widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>));
    expect(blockItems.every((item) => item.height == 36), isTrue);
  });

  testWidgets('Parses and edits Markdown tables as cells', (tester) async {
    final key = GlobalKey<MarkdownEditorState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(
          key: key,
          initialText: '| A | B |\n| --- | --- |\n| 1 | 2 |',
          readOnly: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).at(2), '9');
    await tester.pump();
    expect(key.currentState!.text, contains('| 9 | 2 |'));
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

  testWidgets('editing a block keeps its line height and position', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(initialText: 'alpha', readOnly: false),
      ),
    ));
    await tester.pumpAndSettle();

    final display = find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText() == 'alpha');
    final beforeSize = tester.getSize(display);
    final beforeTop = tester.getTopLeft(display);

    await tester.tap(display);
    await tester.pump();

    final field = find.byType(TextField).first;
    final afterSize = tester.getSize(field);
    final afterTop = tester.getTopLeft(field);
    expect((afterSize.height - beforeSize.height).abs(), lessThan(1.0));
    expect((afterTop.dy - beforeTop.dy).abs(), lessThan(1.0));
  });

  testWidgets('table rows stretch every cell to the tallest content', (tester) async {
    final longText = List.filled(14, 'long cell').join(' ');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [L10nDelegate()],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MarkdownEditor(
          initialText: '| A | B |\n| --- | --- |\n| $longText | short |',
          readOnly: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    double height(int row, int column) => tester.getSize(find.byKey(ValueKey('md-table-$row-$column'))).height;

    expect((height(0, 0) - height(0, 1)).abs(), lessThan(0.5));
    expect((height(1, 0) - height(1, 1)).abs(), lessThan(0.5));
    expect(height(1, 0), greaterThan(36));
    final grid = tester.widget<Container>(find.byKey(const ValueKey('md-table-grid')));
    expect((grid.decoration as BoxDecoration).border, isA<Border>());
  });
}
