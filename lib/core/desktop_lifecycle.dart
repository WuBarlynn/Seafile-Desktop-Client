import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopLifecycle with WindowListener, TrayListener, WidgetsBindingObserver {
  DesktopLifecycle._();

  static final DesktopLifecycle instance = DesktopLifecycle._();

  bool _initialized = false;
  bool _quitting = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    try {
      final zh = Platform.localeName.toLowerCase().startsWith('zh');
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray_icon.ico' : 'assets/app_icon.png',
        iconSize: 18,
      );
      await trayManager.setToolTip('Seafile');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(
          key: 'show',
          label: zh ? '打开 Seafile' : 'Open Seafile',
          onClick: (_) => unawaited(showWindow()),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: zh ? '退出 Seafile' : 'Quit Seafile',
          onClick: (_) => unawaited(quit()),
        ),
      ]));
      trayManager.addListener(this);
    } catch (_) {
      // The window-close-to-background behavior still works when a tray is unavailable.
    }
  }

  Future<void> showWindow() async {
    if (_quitting) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() {
    if (!_quitting) unawaited(windowManager.hide());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(showWindow());
  }
}
