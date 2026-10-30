import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/session.dart';
import 'dialogs.dart';

Future<bool> ensureRepoUnlocked(BuildContext context, Repository repo) async {
  final session = context.read<AppSession>();
  if (!repo.encrypted) return true;
  if (session.isRepoUnlocked(repo.id)) return true;
  if (await session.tryAutoUnlock(repo)) return true;
  if (!context.mounted) return false;
  return showUnlockRepoDialog(context, repo);
}
