import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_error.dart';
import '../api/seafile_api.dart';
import '../core/app_info.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import '../state/session_store.dart';
import 'widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.expiredMessage = false});

  final bool expiredMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _serverFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _remember = true;
  bool _allowUntrusted = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _requiresOtp = false;
  bool _trustDevice = false;
  bool _ssoBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastLogin();
  }

  Future<void> _loadLastLogin() async {
    final last = await SessionStore.lastLogin();
    if (!mounted) return;
    setState(() {
      _serverController.text = last.server;
      _usernameController.text = last.username;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_serverController.text.isEmpty) {
        _serverFocus.requestFocus();
      } else if (_usernameController.text.isEmpty) {
        _usernameFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _serverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = L10n.of(context);
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.invalidServer);
      return;
    }
    if (_requiresOtp && _otpController.text.trim().isEmpty) {
      setState(() => _error = l10n.invalidOtp);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AppSession>().signIn(
            server: server,
            username: username,
            password: password,
            otp: _requiresOtp ? _otpController.text.trim() : null,
            rememberDevice: _trustDevice,
            persist: _remember,
            allowUntrusted: _allowUntrusted,
          );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.kind == ApiErrorKind.twoFactorRequired) {
          if (_requiresOtp) {
            _error = l10n.invalidOtp;
          } else {
            _requiresOtp = true;
            _error = null;
            WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocus.requestFocus());
          }
        } else if (error.kind == ApiErrorKind.invalidCredentials) {
          _error = l10n.wrongCredentials;
        } else if (error.kind == ApiErrorKind.unauthorized) {
          _error = error.serverMessage?.isNotEmpty == true ? error.serverMessage : l10n.wrongCredentials;
        } else if (error.kind == ApiErrorKind.network) {
          _error = l10n.serverUnreachable;
        } else {
          final message = error.serverMessage?.trim();
          final lower = (message ?? '').toLowerCase();
          if (lower.contains('unable to login') || lower.contains('incorrect password') || lower.contains('wrong')) {
            _error = l10n.wrongCredentials;
          } else {
            _error = message?.isNotEmpty == true ? message : error.friendly(l10n);
          }
        }
      });
    } on FormatException {
      if (mounted) setState(() => _error = l10n.invalidServer);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _ssoLogin() async {
    if (_ssoBusy || _submitting) return;
    final l10n = L10n.of(context);
    final server = _serverController.text.trim();
    if (server.isEmpty) {
      setState(() => _error = l10n.invalidServer);
      return;
    }
    final session = context.read<AppSession>();
    SeafileApi? temp;
    setState(() {
      _ssoBusy = true;
      _error = null;
    });
    try {
      final uri = SeafileApi.normalizeServerUrl(server);
      temp = SeafileApi(
        serverUrl: uri.toString(),
        allowUntrustedCertificate: _allowUntrusted,
      );
      final link = await temp.clientSsoLink();
      final launched = await launchUrl(link, mode: LaunchMode.externalApplication);
      if (!launched) throw ApiException(ApiErrorKind.unknown, serverMessage: l10n.ssoNotAvailable);
      if (!mounted) return;
      final result = await showDialog<({String username, String token})>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _SsoPollingDialog(api: temp!, link: link),
      );
      if (result == null || !mounted) return;
      await session.signInWithToken(
        server: uri.toString(),
        username: result.username,
        token: result.token,
        allowUntrusted: _allowUntrusted,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.serverMessage?.isNotEmpty == true ? error.serverMessage : l10n.ssoNotAvailable);
    } catch (error) {
      if (mounted) setState(() => _error = l10n.ssoNotAvailable);
    } finally {
      temp?.close();
      if (mounted) setState(() => _ssoBusy = false);
    }
  }

  void _backToCredentials() {
    setState(() {
      _requiresOtp = false;
      _otpController.clear();
      _error = null;
    });
  }

  Future<void> _openPasswordReset() async {
    final l10n = L10n.of(context);
    try {
      final uri = SeafileApi.normalizeServerUrl(_serverController.text);
      await launchUrl(uri.replace(path: '${uri.path}/accounts/password/reset/'), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) showToast(context, l10n.invalidServer, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.9),
                  radius: 1.2,
                  colors: [AppColors.primarySoft.withValues(alpha: 0.65), Colors.white],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: SeafileLogo(height: 38)),
                    const SizedBox(height: 30),
                    Text(
                      _requiresOtp ? l10n.twoFactorTitle : l10n.signIn,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _requiresOtp ? l10n.twoFactorHint : l10n.appTagline,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 26),
                    if (widget.expiredMessage && !_requiresOtp) ...[
                      _MessageBox(
                        icon: Icons.schedule_rounded,
                        message: l10n.sessionExpired,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_requiresOtp) ...[
                      TextField(
                        controller: _otpController,
                        focusNode: _otpFocus,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: '000000',
                          counterText: '',
                          labelText: l10n.otpCode,
                          prefixIcon: const Icon(Icons.shield_outlined, size: 19),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: _trustDevice,
                            onChanged: (value) => setState(() => _trustDevice = value ?? false),
                          ),
                          Text(l10n.trustDevice, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: _serverController,
                        focusNode: _serverFocus,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: l10n.serverAddress,
                          hintText: l10n.serverHint,
                          prefixIcon: const Icon(Icons.dns_outlined, size: 19),
                        ),
                        onSubmitted: (_) => _usernameFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
                        ),
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: (value) => setState(() => _remember = value ?? false),
                          ),
                          Text(l10n.rememberMe, style: const TextStyle(fontSize: 13)),
                          const Spacer(),
                          TextButton(
                            onPressed: _submitting ? null : _openPasswordReset,
                            child: Text(l10n.forgotPassword, style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: Text(l10n.advancedOptions, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _allowUntrusted,
                                  onChanged: (value) => setState(() => _allowUntrusted = value ?? false),
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      '允许不受信任的 TLS 证书（仅用于自签名服务器）。启用后，客户端只对当前服务器跳过证书校验。',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      _MessageBox(icon: Icons.error_outline_rounded, message: _error!, color: AppColors.danger),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 40,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_requiresOtp ? l10n.verify : l10n.signIn),
                      ),
                    ),
                    if (_requiresOtp)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _submitting ? null : _backToCredentials,
                          child: Text(l10n.back),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: _ssoBusy || _submitting ? null : _ssoLogin,
                          icon: _ssoBusy
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.verified_user_outlined, size: 17),
                          label: Text(l10n.ssoLogin),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Seafile Desktop $appVersion',
                        style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.icon, required this.message, required this.color});

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: color, height: 1.45))),
        ],
      ),
    );
  }
}


class _SsoPollingDialog extends StatefulWidget {
  const _SsoPollingDialog({required this.api, required this.link});

  final SeafileApi api;
  final Uri link;

  @override
  State<_SsoPollingDialog> createState() => _SsoPollingDialogState();
}

class _SsoPollingDialogState extends State<_SsoPollingDialog> {
  bool _cancelled = false;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _poll() async {
    final l10n = L10n.of(context);
    var failures = 0;
    for (var attempt = 0; attempt < 90; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || _cancelled) return;
      try {
        final result = await widget.api.clientSsoStatus(widget.link);
        if (!mounted || _cancelled) return;
        if (result != null) {
          Navigator.pop(context, result);
          return;
        }
        failures = 0;
        if (mounted) setState(() => _checking = true);
      } on ApiException catch (error) {
        failures++;
        if (failures >= 3) {
          if (mounted) {
            setState(() {
              _checking = false;
              _error = error.serverMessage?.isNotEmpty == true ? error.serverMessage : l10n.ssoTimeout;
            });
          }
          return;
        }
      } catch (_) {
        failures++;
      }
    }
    if (mounted) {
      setState(() {
        _checking = false;
        _error = l10n.ssoTimeout;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.ssoTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error == null) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(l10n.ssoWaiting, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ] else
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.pop(context);
          },
          child: Text(_error == null ? l10n.cancel : l10n.close),
        ),
      ],
    );
  }
}
