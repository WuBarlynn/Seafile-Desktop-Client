import 'package:flutter/material.dart';

import '../api/models.dart';
import '../core/format.dart';
import 'web_handoff.dart';

Future<void> openOnlineEditor(
  BuildContext context,
  Repository repo,
  Dirent entry,
) {
  final path = '/lib/${repo.id}/file${encodeRepoPath(entry.path)}';
  return openAuthenticatedWeb(context, path, title: entry.name);
}
