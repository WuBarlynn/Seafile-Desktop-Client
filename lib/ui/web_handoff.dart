import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';
import '../state/session.dart';
import 'widgets.dart';

final List<Webview> _webWindows = [];

/// Closes every embedded web window and clears its cookies/storage. Called on
/// sign-out so a later account cannot inherit the previous web session.
Future<void> clearAuthenticatedWeb() async {
  for (final webview in List<Webview>.of(_webWindows)) {
    try {
      await webview.close();
    } catch (_) {}
  }
  _webWindows.clear();
  try {
    await InAppWebViewController.clearAllCache();
    await CookieManager.instance().deleteAllCookies();
  } catch (_) {}
  try {
    final support = await getApplicationSupportDirectory();
    await WebviewWindow.clearAll(
      windows: WindowsWebviewOptions(userDataFolder: p.join(support.path, 'WebView2')),
    );
  } catch (_) {}
}

/// Opens a SeaHub page in an embedded WebView window when possible, using a
/// one-time client-login token for an authenticated session. Falls back to the
/// system browser when the platform WebView runtime is unavailable.
Future<void> openAuthenticatedWeb(
  BuildContext context,
  String path, {
  String? title,
}) async {
  final session = context.read<AppSession>();
  final api = session.api;
  if (api == null) return;
  final l10n = L10n.of(context);
  final target = path.startsWith('http://') || path.startsWith('https://')
      ? Uri.parse(path)
      : Uri.parse(
          '${session.serverBase}${path.startsWith('/') ? '' : '/'}$path',
        );
  String? token;
  try {
    token = await api.clientLoginToken();
  } catch (_) {}
  Uri url = target;
  if (token != null && token.isNotEmpty) {
    url = Uri.parse('${session.serverBase}/client-login/')
        .replace(queryParameters: {'token': token, 'next': target.toString()});
  }

  Webview? webview;
  try {
    final support = await getApplicationSupportDirectory();
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: title ?? 'Seafile',
        windowWidth: 1280,
        windowHeight: 900,
        windows: WindowsWebviewOptions(
          userDataFolder: p.join(support.path, 'WebView2'),
        ),
      ),
    );
    _webWindows.add(webview);
    webview.onClose.then((_) => _webWindows.remove(webview));
    await webview.launch(url.toString());
    return;
  } catch (_) {
    try {
      await webview?.close();
    } catch (_) {}
  }

  if (context.mounted && token == null) {
    showToast(context, l10n.webLoginFallback);
  }
  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    showToast(context, l10n.onlineEditorFailed);
  }
}
