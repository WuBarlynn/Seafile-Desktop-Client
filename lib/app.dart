import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'state/session.dart';
import 'ui/app_shell.dart';
import 'ui/login_page.dart';
import 'ui/widgets.dart';

class SeafileApp extends StatelessWidget {
  const SeafileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seafile',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        L10nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('zh', 'CN');
        for (final item in supported) {
          if (item.languageCode == locale.languageCode) return item;
        }
        return const Locale('zh', 'CN');
      },
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    if (session.restoring) return const _SplashScreen();
    if (!session.hasSession) return LoginPage(expiredMessage: session.expired);
    return const AppShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SeafileLogo(height: 40),
            const SizedBox(height: 28),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: AppColors.primarySoft,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
