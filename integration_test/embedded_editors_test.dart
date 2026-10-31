import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/state/transfer_manager.dart';
import 'package:seafile_desktop/state/workspace.dart';
import 'package:seafile_desktop/ui/app_shell.dart';
import 'package:seafile_desktop/ui/inline_web_editor.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> capture(String name) async {
    await windowManager.show();
    await windowManager.focus();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final result = await Process.run('screencapture', ['-x', '${Directory.systemTemp.path}/embed-$name.png']);
    debugPrint('CAPTURE embed-$name exit=${result.exitCode}');
  }

  testWidgets('Excalidraw and Office files open in embedded editors', (tester) async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.center();
    await windowManager.show();
    final session = AppSession();
    await session.restore();
    expect(session.hasSession, isTrue);
    final transfer = TransferManager(session);
    final workspace = WorkspaceController(session);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSession>.value(value: session),
        ChangeNotifierProvider<TransferManager>.value(value: transfer),
        ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          L10nDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    ));
    await waitFor(tester, find.text('seasearch-test'));
    await tester.tap(find.text('seasearch-test').first);
    await waitFor(tester, find.text('exdraw-test.exdraw'));
    await tester.tap(find.text('exdraw-test.exdraw').first);
    await waitFor(tester, find.byType(InlineWebEditor));
    expect(find.text('后退'), findsNothing);
    await Future<void>.delayed(const Duration(seconds: 8));
    await tester.pump();
    await capture('exdraw');

    await tester.tap(find.text('seasearch-test').last);
    await waitFor(tester, find.text('未命名.docx'));
    await tester.tap(find.text('未命名.docx').first);
    await waitFor(tester, find.byType(InlineWebEditor));
    expect(find.text('后退'), findsNothing);
    await Future<void>.delayed(const Duration(seconds: 12));
    await tester.pump();
    await capture('office');
  });
}
