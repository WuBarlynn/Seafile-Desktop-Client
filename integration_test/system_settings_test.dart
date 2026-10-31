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

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('System settings mirrors the web admin menu and pages', (tester) async {
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

    await waitFor(tester, find.text('Virus scan'));
    for (final label in ['Information', 'Statistics', 'Devices', 'Settings', 'Libraries', 'Users', 'Groups', 'Departments', 'Notifications', 'Links', 'Logs', 'Virus scan', 'Admin logs']) {
      expect(find.text(label), findsWidgets, reason: 'missing admin navigation item $label');
    }

    await tester.tap(find.text('Settings').first);
    await waitFor(tester, find.text('Branding'));
    expect(find.text('Two-factor authentication'), findsOneWidget);
    expect(find.text('Text file extensions'), findsOneWidget);

    await tester.tap(find.text('Logs').first);
    await waitFor(tester, find.text('IP'));
    expect(find.text('IP'), findsWidgets);
    await tester.tap(find.text('File update').last);
    await waitFor(tester, find.text('Operation'));
    expect(find.text('Operation'), findsWidgets);

    await tester.tap(find.text('Notifications').first);
    await waitFor(tester, find.text('Add notification'));

    await tester.tap(find.text('Statistics').first);
    await waitFor(tester, find.text('Added'));
    expect(find.text('Added'), findsWidgets);

    await tester.tap(find.text('Information').first);
    await waitFor(tester, find.text('Full admin console'));
    await tester.tap(find.text('Full admin console'));
    await tester.pump();
    expect(openedPath, '/sys/info/');
  });
}
