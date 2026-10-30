import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/file_kind.dart';
import '../state/session.dart';
import 'widgets.dart';

final Map<String, Uint8List?> _thumbnailCache = {};

Future<Uint8List?> loadThumbnail(BuildContext context, Repository repo, Dirent entry, {int size = 256}) async {
  final key = '${repo.id}|${entry.path}|${entry.versionKey}|$size';
  if (_thumbnailCache.containsKey(key)) return _thumbnailCache[key];
  final api = context.read<AppSession>().api;
  if (api == null) return null;
  try {
    final bytes = await api.thumbnail(repo.id, entry.path, size: size);
    if (_thumbnailCache.length > 400) _thumbnailCache.clear();
    _thumbnailCache[key] = bytes;
    return bytes;
  } catch (_) {
    _thumbnailCache[key] = null;
    return null;
  }
}

class ThumbnailView extends StatelessWidget {
  const ThumbnailView({
    super.key,
    required this.repo,
    required this.entry,
    this.width = 96,
    this.height = 72,
    this.iconSize = 34,
  });

  final Repository repo;
  final Dirent entry;
  final double width;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (entry.isDir || !FileKind.of(entry.name).canThumbnail) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(child: FileTypeIcon(name: entry.name, isDir: entry.isDir, size: iconSize)),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: loadThumbnail(context, repo, entry),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              snapshot.data!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: (width * 2).round(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
          );
        }
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return SizedBox(
      width: width,
      height: height,
      child: Center(child: FileTypeIcon(name: entry.name, isDir: entry.isDir, size: iconSize)),
    );
  }
}
