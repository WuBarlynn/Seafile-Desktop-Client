import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/desktop_lifecycle.dart';
import 'state/session.dart';
import 'state/transfer_manager.dart';
import 'state/workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(980, 600));
  await windowManager.setSize(const Size(1320, 840));
  await windowManager.setTitle('Seafile');
  await windowManager.center();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSession()..restore()),
        ChangeNotifierProvider(create: (context) => TransferManager(context.read<AppSession>())),
        ChangeNotifierProvider(create: (context) => WorkspaceController(context.read<AppSession>())),
      ],
      child: const SeafileApp(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await windowManager.show();
  await windowManager.focus();
  await DesktopLifecycle.instance.initialize();
}
