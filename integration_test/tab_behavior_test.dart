import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/state/transfer_manager.dart';
import 'package:seafile_desktop/state/workspace.dart';
import 'package:seafile_desktop/ui/app_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('New tabs open after the active tab, can be reordered, and the File crumb returns Home', (tester) async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1440, 900));
    final session = AppSession();
    await session.restore();
    expect(session.hasSession, isTrue, reason: 'A stored local test session is required');
    final transfer = TransferManager(session);
    final workspace = WorkspaceController(session);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSession>.value(value: session),
        ChangeNotifierProvider<TransferManager>.value(value: transfer),
        ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [L10nDelegate()],
        supportedLocales: const [Locale('en')],
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    ));

    for (var i = 0; i < 200 && !session.loadedLibraries; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await _tapAndWait(tester, find.text('seasearch-test').first, find.text('native-test.sdoc'));

    await _tapAndWait(tester, find.text('native-test.sdoc').first, _tab('native-test.sdoc'));
    await tester.pumpAndSettle();
    await tester.tap(_tab('seasearch-test'));
    await tester.pumpAndSettle();
    await _tapAndWait(tester, find.text('native-test.md').first, _tab('native-test.md'));
    await tester.pumpAndSettle();

    expect(tester.getCenter(_tab('native-test.md')).dx, lessThan(tester.getCenter(_tab('native-test.sdoc')).dx));

    final from = tester.getCenter(_tab('native-test.md'));
    final to = tester.getCenter(_tab('native-test.sdoc')) + const Offset(80, 0);
    await tester.timedDrag(_tab('native-test.md'), to - from, const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(tester.getCenter(_tab('native-test.md')).dx, greaterThan(tester.getCenter(_tab('native-test.sdoc')).dx));

    await tester.tap(find.descendant(of: _tab('native-test.md'), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(_tab('native-test.md'), findsNothing);

    await tester.tap(_tab('seasearch-test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File').first);
    await tester.pumpAndSettle();
    expect(find.text('My libraries'), findsWidgets);
    expect(_tab('seasearch-test'), findsOneWidget);

    await tester.tap(_tab('seasearch-test'));
    await tester.pumpAndSettle();
    expect(find.text('native-test.sdoc'), findsWidgets);
  });
}

Finder _tab(String title) => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_TabChip' && (widget as dynamic).tab.title == title,
    );

Future<void> _tapAndWait(WidgetTester tester, Finder target, Finder expected) async {
  await tester.tap(target);
  for (var i = 0; i < 200 && expected.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
  expect(expected, findsWidgets);
}
