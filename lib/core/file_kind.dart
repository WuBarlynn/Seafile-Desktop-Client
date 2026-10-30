import 'package:flutter/material.dart';

enum FileKind {
  folder,
  image,
  video,
  audio,
  pdf,
  text,
  markdown,
  officeDocument,
  sdoc,
  archive,
  other;

  static FileKind of(String name, {bool isDirectory = false}) {
    if (isDirectory) return FileKind.folder;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' || 'heic' || 'heif' || 'tif' || 'tiff' || 'svg' || 'raw' || 'dng' => FileKind.image,
      'mp4' || 'mov' || 'm4v' || 'avi' || 'mkv' || 'webm' || '3gp' || 'flv' || 'wmv' => FileKind.video,
      'mp3' || 'wav' || 'aac' || 'm4a' || 'flac' || 'ogg' || 'opus' || 'aiff' => FileKind.audio,
      'pdf' => FileKind.pdf,
      'md' || 'markdown' || 'mdown' => FileKind.markdown,
      'txt' || 'log' || 'csv' || 'json' || 'xml' || 'html' || 'htm' || 'yaml' || 'yml' || 'toml' || 'ini' || 'conf' || 'sh' || 'swift' || 'm' || 'h' || 'c' || 'cpp' || 'js' || 'ts' || 'py' || 'rb' || 'go' || 'rs' || 'java' || 'kt' || 'css' => FileKind.text,
      'doc' || 'docx' || 'xls' || 'xlsx' || 'ppt' || 'pptx' || 'pages' || 'numbers' || 'key' || 'rtf' => FileKind.officeDocument,
      'sdoc' => FileKind.sdoc,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' || 'bz2' || 'xz' => FileKind.archive,
      _ => FileKind.other,
    };
  }

  bool get isPreviewable =>
      this == FileKind.image ||
      this == FileKind.pdf ||
      this == FileKind.text ||
      this == FileKind.markdown;

  bool get canThumbnail => this == FileKind.image;

  IconData get icon => switch (this) {
        FileKind.folder => Icons.folder_rounded,
        FileKind.image => Icons.image_rounded,
        FileKind.video => Icons.movie_rounded,
        FileKind.audio => Icons.audiotrack_rounded,
        FileKind.pdf => Icons.picture_as_pdf_rounded,
        FileKind.text => Icons.code_rounded,
        FileKind.markdown => Icons.article_rounded,
        FileKind.officeDocument => Icons.description_rounded,
        FileKind.sdoc => Icons.edit_document,
        FileKind.archive => Icons.folder_zip_rounded,
        FileKind.other => Icons.insert_drive_file_rounded,
      };

  Color get color => switch (this) {
        FileKind.folder => const Color(0xFFF0A62B),
        FileKind.image => const Color(0xFFE0527A),
        FileKind.video => const Color(0xFF7A57D1),
        FileKind.audio => const Color(0xFF1E9AAE),
        FileKind.pdf => const Color(0xFFD64B45),
        FileKind.text => const Color(0xFF3A7FD5),
        FileKind.markdown => const Color(0xFF4C6FBF),
        FileKind.officeDocument => const Color(0xFF2E8B57),
        FileKind.sdoc => const Color(0xFF2A8F8A),
        FileKind.archive => const Color(0xFF63717D),
        FileKind.other => const Color(0xFF7B8794),
      };

  Color get background => color.withValues(alpha: 0.11);
}
