import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/state/transfer_manager.dart';
import 'package:seafile_desktop/state/workspace.dart';
import 'package:seafile_desktop/ui/app_shell.dart';
import 'package:seafile_desktop/ui/widgets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Avatar menu exposes saved account switching', (tester) async {
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
    await tester.tap(find.byType(AvatarCircle).first);
    await tester.pumpAndSettle();
    expect(find.text('Switch account'), findsOneWidget);
    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();
    expect(find.text('Add account'), findsOneWidget);
    expect(session.accounts, isNotEmpty);
    expect(find.text('Current'), findsOneWidget);
  });
}
