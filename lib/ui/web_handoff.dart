import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n.dart';
import '../state/session.dart';
import 'widgets.dart';

/// Opens a SeaHub web page in the system browser. When possible a one-time
/// client-login token is used so the browser session is established
/// automatically (2FA accounts fall back to the normal browser session).
Future<void> openAuthenticatedWeb(BuildContext context, String path) async {
  final session = context.read<AppSession>();
  final api = session.api;
  if (api == null) return;
  final l10n = L10n.of(context);
  final target = path.startsWith('http://') || path.startsWith('https://')
      ? Uri.parse(path)
      : Uri.parse('${session.serverBase}${path.startsWith('/') ? '' : '/'}$path');
  String? token;
  try {
    token = await api.clientLoginToken();
  } catch (_) {}
  Uri url = target;
  if (token != null && token.isNotEmpty) {
    url = Uri.parse('${session.serverBase}/client-login/').replace(queryParameters: {
      'token': token,
      'next': target.toString(),
    });
  }
  if (context.mounted && token == null) showToast(context, l10n.webLoginFallback);
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
