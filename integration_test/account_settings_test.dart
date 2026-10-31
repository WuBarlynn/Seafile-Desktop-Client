import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/ui/account_settings_page.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account settings expose profile, WebDAV, notifications and devices', (tester) async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.center();
    final session = AppSession();
    await session.restore();
    expect(session.hasSession, isTrue);
    String? openedPath;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSession>.value(
        value: session,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [L10nDelegate()],
          supportedLocales: const [Locale('en')],
          theme: buildAppTheme(),
          home: Scaffold(body: AccountSettingsPage(onOpenWeb: (path, title) => openedPath = path)),
        ),
      ),
    );

    for (var i = 0; i < 160 && find.text('WebDAV access').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('WebDAV access'), findsOneWidget);
    expect(find.text('Email notifications'), findsOneWidget);
    expect(find.text('Linked devices'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);

    await tester.tap(find.text('More account options'));
    await tester.pump();
    expect(openedPath, '/profile/');
  });
}
