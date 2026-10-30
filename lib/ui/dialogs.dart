import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../core/app_info.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/session.dart';
import 'widgets.dart';

Future<bool> showUnlockRepoDialog(BuildContext context, Repository repo) async {
  final session = context.read<AppSession>();
  final l10n = L10n.of(context);
  final controller = TextEditingController();
  final focus = FocusNode();
  var remember = true;
  var loading = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          final password = controller.text;
          if (password.isEmpty || loading) return;
          setState(() {
            loading = true;
            error = null;
          });
          try {
            await session.unlockRepo(repo, password, remember: remember);
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          } on RepoCryptoException catch (exception) {
            setState(() {
              error = exception.wrongPassword ? l10n.wrongLibraryPassword : exception.message;
              loading = false;
            });
            focus.requestFocus();
          } on ApiException catch (exception) {
            setState(() {
              error = exception.friendly(l10n);
              loading = false;
            });
          } catch (exception) {
            setState(() {
              error = exception.toString();
              loading = false;
            });
          }
        }

        return AlertDialog(
          title: Row(
            children: [
              const WebIcon('lock', size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(l10n.unlockLibrary),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.unlockLibraryHint(repo.name), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  obscureText: true,
                  enabled: !loading,
                  decoration: InputDecoration(labelText: l10n.libraryPassword),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: remember,
                      onChanged: loading ? null : (value) => setState(() => remember = value ?? false),
                    ),
                    Text(l10n.rememberPassword, style: const TextStyle(fontSize: 13)),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.unlock),
            ),
          ],
        );
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => focus.dispose());
  controller.dispose();
  return result ?? false;
}

Future<Repository?> showCreateLibraryDialog(BuildContext context) async {
  final session = context.read<AppSession>();
  final l10n = L10n.of(context);
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final passwordController = TextEditingController();
  final nameFocus = FocusNode();
  var encrypted = false;
  var loading = false;
  String? error;

  final result = await showDialog<Repository>(
    context: context,
    barrierDismissible: !loading,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            setState(() => error = l10n.libraryNameRequired);
            return;
          }
          if (encrypted && passwordController.text.isEmpty) {
            setState(() => error = l10n.wrongLibraryPassword);
            return;
          }
          setState(() {
            loading = true;
            error = null;
          });
          try {
            final created = await session.api!.createLibrary(
              name: name,
              description: descriptionController.text.trim(),
              password: encrypted ? passwordController.text : null,
            );
            await session.refreshLibraries();
            if (dialogContext.mounted) Navigator.pop(dialogContext, created);
          } catch (exception) {
            setState(() {
              error = friendlyError(context, exception);
              loading = false;
            });
          }
        }

        return AlertDialog(
          title: Text(l10n.createLibrary),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  autofocus: true,
                  enabled: !loading,
                  decoration: InputDecoration(labelText: l10n.libraryName, hintText: l10n.libraryNameHint),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  enabled: !loading,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: l10n.libraryDescription, hintText: l10n.descriptionOptional),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: encrypted,
                      onChanged: loading ? null : (value) => setState(() => encrypted = value ?? false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.encryptLibrary, style: const TextStyle(fontSize: 13)),
                          Text(l10n.encryptLibraryHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (encrypted) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    enabled: !loading,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.libraryPassword, hintText: l10n.optional),
                    onSubmitted: (_) => submit(),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(onPressed: loading ? null : () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: loading ? null : submit,
              child: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.create),
            ),
          ],
        );
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => nameFocus.dispose());
  nameController.dispose();
  descriptionController.dispose();
  passwordController.dispose();
  return result;
}

Future<void> showSeafileAboutDialog(BuildContext context) async {
  final session = context.read<AppSession>();
  final l10n = L10n.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SeafileLogo(height: 26),
          const SizedBox(width: 10),
          Text(l10n.aboutSeafile),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.aboutDescription, style: const TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            _infoRow(l10n.clientVersion, appVersion),
            _infoRow(l10n.serverVersion, session.serverInfo?.version ?? '—'),
            _infoRow(l10n.server, session.serverBase),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://github.com/WuBarlynn/Seafile-Desktop-Client'), mode: LaunchMode.externalApplication),
              child: Text(
                'GitHub · WuBarlynn/Seafile-Desktop-Client',
                style: TextStyle(fontSize: 13, color: AppColors.primary, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.close)),
      ],
    ),
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, color: AppColors.text))),
      ],
    ),
  );
}
