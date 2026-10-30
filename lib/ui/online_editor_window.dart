import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../state/session.dart';
import 'widgets.dart';

final List<Webview> _onlineEditorWindows = [];

Future<void> openOnlineEditor(BuildContext context, Repository repo, Dirent entry) async {
  final session = context.read<AppSession>();
  final api = session.api;
  if (api == null) return;
  final l10n = L10n.of(context);
  final target = '${session.serverBase}/lib/${repo.id}/file${encodeRepoPath(entry.path)}';
  Uri url = Uri.parse(target);

  Webview? webview;
  try {
    final support = await getApplicationSupportDirectory();
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: entry.name,
        windowWidth: 1280,
        windowHeight: 900,
        windows: WindowsWebviewOptions(userDataFolder: p.join(support.path, 'WebView2')),
      ),
    );
    _onlineEditorWindows.add(webview);
    webview.onClose.then((_) => _onlineEditorWindows.remove(webview));
  } catch (_) {
    webview = null;
  }

  String? token;
  try {
    token = await api.clientLoginToken();
  } catch (_) {}
  if (token != null && token.isNotEmpty) {
    url = Uri.parse('${session.serverBase}/client-login/').replace(queryParameters: {
      'token': token,
      'next': target,
    });
  }

  if (webview != null) {
    await webview.launch(url.toString());
    return;
  }

  await launchUrl(url, mode: LaunchMode.externalApplication);
  if (context.mounted) showToast(context, l10n.onlineEditorFailed);
}
