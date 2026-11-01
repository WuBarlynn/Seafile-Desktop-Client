import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

class InlineWebEditor extends StatefulWidget {
  const InlineWebEditor({super.key, required this.repo, required this.entry})
      : path = null;

  const InlineWebEditor.page({super.key, required this.path})
      : repo = null,
        entry = null;

  final Repository? repo;
  final Dirent? entry;
  final String? path;

  @override
  State<InlineWebEditor> createState() => _InlineWebEditorState();
}

class _InlineWebEditorState extends State<InlineWebEditor> {
  InAppWebViewController? _controller;
  String? _url;
  String? _target;
  String? _error;
  bool _loading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final session = context.read<AppSession>();
    final remotePath = widget.path ?? '/lib/${widget.repo!.id}/file${encodeRepoPath(widget.entry!.path)}';
    final target = '${session.serverBase}$remotePath';
    String? token;
    try {
      token = await session.api?.clientLoginToken();
    } catch (_) {}
    var url = target;
    if (token != null && token.isNotEmpty) {
      url = Uri.parse('${session.serverBase}/client-login/').replace(queryParameters: {
        'token': token,
        'next': target,
      }).toString();
    }
    if (!mounted) return;
    setState(() {
      _target = target;
      _url = url;
    });
  }

  Future<void> _openExternal() async {
    final target = _target;
    if (target == null) return;
    await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      color: const Color(0xFFF4F5F7),
      child: Column(
        children: [
          if (widget.entry == null)
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  _button(Icons.arrow_back, l10n.zh ? '后退' : 'Back', () => _controller?.goBack()),
                  _button(Icons.arrow_forward, l10n.zh ? '前进' : 'Forward', () => _controller?.goForward()),
                  _button(Icons.refresh, l10n.refresh, () => _controller?.reload()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _target ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                  _button(Icons.open_in_new, l10n.openInBrowser, _openExternal),
                ],
              ),
            ),
          if (_loading)
            LinearProgressIndicator(value: _progress > 0 && _progress < 1 ? _progress : null, minHeight: 2, backgroundColor: AppColors.hover),
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const WebIcon('exclamation-circle', size: 38, color: AppColors.muted),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _loading = true;
                                });
                                _controller?.reload();
                              },
                              child: Text(l10n.retry),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(onPressed: _openExternal, child: Text(l10n.openInBrowser)),
                          ],
                        ),
                      ],
                    ),
                  )
                : _url == null
                    ? const Center(child: CircularProgressIndicator())
                    : InAppWebView(
                        initialUrlRequest: URLRequest(url: WebUri(_url!)),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          isInspectable: false,
                          supportZoom: true,
                          useShouldOverrideUrlLoading: false,
                          javaScriptCanOpenWindowsAutomatically: false,
                          supportMultipleWindows: false,
                          sharedCookiesEnabled: true,
                          isFraudulentWebsiteWarningEnabled: false,
                          userAgent: Platform.isMacOS
                              ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
                              : null,
                        ),
                        onConsoleMessage: (controller, message) {
                          debugPrint('[inline-web] ${message.messageLevel}: ${message.message}');
                        },
                        onCreateWindow: (controller, action) async {
                          final url = action.request.url;
                          if (url == null) return false;
                          await controller.loadUrl(urlRequest: URLRequest(url: url));
                          return true;
                        },
                        onWebViewCreated: (controller) => _controller = controller,
                        onLoadStart: (controller, url) {
                          if (!mounted) return;
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                        },
                        onLoadStop: (controller, url) {
                          if (!mounted) return;
                          setState(() {
                            _loading = false;
                            _progress = 1;
                          });
                          controller.evaluateJavascript(source: r"""
(() => {
  const styleId = 'seafile-desktop-file-chrome';
  if (location.pathname.indexOf('/lib/') !== -1 && !document.getElementById(styleId)) {
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = '.file-view-header,.onlyoffice-file-view-header-shown,.docx-view-header > .file-view-header,.sdoc-view-header{display:none!important}.sf-only-office{padding-top:0!important}';
    document.head.appendChild(style);
  }
  let tries = 0;
  const fit = () => {
    const iframe = document.querySelector('iframe');
    if (!iframe) return;
    const top = Math.max(0, iframe.getBoundingClientRect().top);
    const height = Math.max(480, window.innerHeight - top);
    iframe.style.width = '100%';
    iframe.style.height = height + 'px';
  };
  const timer = setInterval(() => { fit(); if (++tries > 30) clearInterval(timer); }, 300);
  window.addEventListener('resize', fit);
  fit();
})()
""");
                        },
                        onProgressChanged: (controller, progress) {
                          if (!mounted) return;
                          setState(() => _progress = progress / 100);
                        },
                        onReceivedError: (controller, request, error) {
                          if (!mounted || request.isForMainFrame == false) return;
                          setState(() {
                            _loading = false;
                            _error = error.description;
                          });
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: onTap == null ? AppColors.muted : AppColors.textSecondary),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      ),
    );
  }
}
