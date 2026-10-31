import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seafile_desktop/api/models.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/state/workspace.dart';
import 'package:seafile_desktop/ui/sdoc_editor.dart';

const _repoId = '4ab8d670-41d7-4797-837d-1ed7fe76d09a';
const _path = '/keyboard-test.sdoc';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SeaDoc block editing and saving follow web keyboard behaviour', (tester) async {
    final session = AppSession();
    await session.restore();
    expect(session.hasSession, isTrue, reason: 'A stored local test session is required');
    final api = session.api!;
    final entries = await api.listDir(_repoId, '/');
    if (!entries.any((entry) => entry.path == _path)) {
      await api.createFile(_repoId, _path);
    }
    await api.saveSdocDocument(_repoId, _path, _fixture());

    final repository = const Repository(id: _repoId, name: 'seasearch-test', permission: 'rw');
    const entry = Dirent(name: 'keyboard-test.sdoc', path: _path, isDir: false, permission: 'rw');
    final workspace = WorkspaceController(session);
    final editorKey = GlobalKey<SdocEditorState>();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSession>.value(value: session),
        ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [L10nDelegate()],
        supportedLocales: const [Locale('en')],
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: SdocEditor(key: editorKey, repo: repository, entry: entry)),
      ),
    ));

    for (var i = 0; i < 200 && find.byType(TextField).evaluate().length < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'first', 'one', 'two', 'last', '']);
    final canvas = tester.getSize(find.byKey(const ValueKey('sdoc-canvas')));
    final viewport = tester.getSize(find.byType(Scaffold));
    expect(canvas.height, greaterThan(viewport.height - 160), reason: 'the SeaDoc canvas must fill the tab height');

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    final paragraph = tester.widget<TextField>(find.byType(TextField).at(1));
    paragraph.controller!.selection = TextSelection.collapsed(offset: paragraph.controller!.text.length);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'first', '', 'one', 'two', 'last', '']);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'first', 'one', 'two', 'last', '']);

    await tester.tap(find.byType(TextField).at(2));
    await tester.pump();
    final listItem = tester.widget<TextField>(find.byType(TextField).at(2));
    listItem.controller!.selection = TextSelection.collapsed(offset: listItem.controller!.text.length);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'first', 'one', '', 'two', 'last', '']);

    await tester.enterText(find.byType(TextField).at(3), 'three');
    await tester.pumpAndSettle();
    final inserted = tester.widget<TextField>(find.byType(TextField).at(3));
    inserted.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'first', 'onethree', 'two', 'last', '']);

    await tester.tap(find.byType(TextField).at(1));
    await tester.pump();
    final firstParagraph = tester.widget<TextField>(find.byType(TextField).at(1));
    firstParagraph.controller!.selection = TextSelection.collapsed(offset: firstParagraph.controller!.text.length);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(_texts(tester), ['Keyboard', 'firstonethree', 'two', 'last', '']);

    final saved = await editorKey.currentState!.save();
    expect(saved, isTrue);
    final document = await api.loadSdocDocument(_repoId, _path);
    final elements = (document['elements'] as List).whereType<Map>().toList();
    final firstElement = elements.firstWhere((element) => element['id'] == 'kb-p1');
    expect(_textOf(firstElement), 'firstonethree');
    final list = elements.firstWhere((element) => element['type'] == 'unordered_list');
    final items = (list['children'] as List).whereType<Map>().toList();
    expect(items.length, 1);
    expect(_textOf(items.first), 'two');
  });
}

Map<String, dynamic> _fixture() => {
      'version': 1,
      'format_version': 4,
      'elements': [
        {
          'id': 'kb-title',
          'type': 'title',
          'children': [
            {'id': 'kb-title-t', 'text': 'Keyboard'}
          ],
        },
        {
          'id': 'kb-p1',
          'type': 'paragraph',
          'children': [
            {'id': 'kb-p1-t', 'text': 'first'}
          ],
        },
        {
          'id': 'kb-list',
          'type': 'unordered_list',
          'children': [
            {
              'id': 'kb-li1',
              'type': 'list_item',
              'children': [
                {
                  'id': 'kb-li1-p',
                  'type': 'paragraph',
                  'children': [
                    {'id': 'kb-li1-t', 'text': 'one'}
                  ],
                }
              ],
            },
            {
              'id': 'kb-li2',
              'type': 'list_item',
              'children': [
                {
                  'id': 'kb-li2-p',
                  'type': 'paragraph',
                  'children': [
                    {'id': 'kb-li2-t', 'text': 'two'}
                  ],
                }
              ],
            },
          ],
        },
        {
          'id': 'kb-p2',
          'type': 'paragraph',
          'children': [
            {'id': 'kb-p2-t', 'text': 'last'}
          ],
        },
        {
          'id': 'kb-p3',
          'type': 'paragraph',
          'children': [
            {'id': 'kb-p3-t', 'text': ''}
          ],
        },
      ],
    };

List<String> _texts(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((field) => field.controller?.text ?? '')
    .toList();

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

  visit(node);
  return buffer.toString();
}
