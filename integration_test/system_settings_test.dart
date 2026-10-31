import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:seafile_desktop/core/l10n.dart';
import 'package:seafile_desktop/core/theme.dart';
import 'package:seafile_desktop/state/session.dart';
import 'package:seafile_desktop/ui/system_settings_page.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('System settings uses a left menu, audit logs and the correct admin console URL', (tester) async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1440, 900));
    final session = AppSession();
    await session.restore();
    expect(session.hasSession, isTrue, reason: 'A stored local test session is required');
    String? openedPath;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSession>.value(
        value: session,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [L10nDelegate()],
          supportedLocales: const [Locale('en')],
          theme: buildAppTheme(),
          home: Scaffold(
            body: SystemSettingsPage(
              onOpenWeb: (path, title) => openedPath = path,
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 200 && find.text('Login logs').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Login logs'), findsOneWidget);
    expect(find.text('File update logs'), findsOneWidget);

    await tester.tap(find.text('Login logs'));
    for (var i = 0; i < 100 && find.text('IP').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('IP'), findsWidgets);

    await tester.tap(find.text('File update logs'));
    for (var i = 0; i < 100 && find.text('Operation').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Operation'), findsWidgets);

    await tester.tap(find.text('Full admin console'));
    await tester.pump();
    expect(openedPath, '/sys/info/');
  });
}
