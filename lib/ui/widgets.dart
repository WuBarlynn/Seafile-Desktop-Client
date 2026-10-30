import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/api_error.dart';
import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';

class WebIcon extends StatelessWidget {
  const WebIcon(this.name, {super.key, this.size = 18, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/web/icons/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color ?? AppColors.textSecondary, BlendMode.srcIn),
    );
  }
}

class SeafileLogo extends StatelessWidget {
  const SeafileLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/web/seafile-logo.png',
      height: height,
      filterQuality: FilterQuality.high,
    );
  }
}

String webFileIconName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  return switch (ext) {
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' || 'heic' || 'heif' || 'tif' || 'tiff' || 'svg' || 'ico' || 'avif' || 'jfif' => 'pic.png',
    'mp4' || 'mov' || 'm4v' || 'avi' || 'mkv' || 'webm' || 'flv' || 'wmv' || 'ogv' => 'video.png',
    'mp3' || 'wav' || 'aac' || 'm4a' || 'flac' || 'ogg' || 'oga' || 'opus' || 'wma' || 'ac3' => 'music.png',
    'pdf' => 'pdf.png',
    'md' || 'markdown' => 'md.png',
    'txt' || 'log' => 'txt.png',
    'css' => 'css.png',
    'doc' || 'docx' || 'odt' || 'fodt' => 'word.png',
    'xls' || 'xlsx' || 'ods' || 'fods' || 'csv' => 'excel.png',
    'ppt' || 'pptx' || 'odp' || 'fodp' => 'ppt.png',
    'sdoc' => 'sdoc.png',
    'zip' || 'rar' || '7z' || 'tar' || 'gz' || 'bz2' || 'xz' => 'zip.png',
    'psd' || 'psb' => 'psd.png',
    'exdraw' => 'draw.png',
    _ => 'file.png',
  };
}

class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.name, this.isDir = false, this.size = 24, this.permission});

  final String name;
  final bool isDir;
  final double size;
  final String? permission;

  @override
  Widget build(BuildContext context) {
    if (isDir) {
      final readOnly = (permission ?? '').toLowerCase() == 'r';
      return Image.asset(
        readOnly ? 'assets/web/folder-read-only-24.png' : 'assets/web/folder-24.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      );
    }
    return Image.asset(
      'assets/web/file/${webFileIconName(name)}',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

class RepoTypeIcon extends StatelessWidget {
  const RepoTypeIcon({super.key, required this.repo, this.size = 24});

  final Repository repo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final encrypted = repo.encrypted;
    final readOnly = repo.isReadOnly;
    final permission = (repo.permission ?? '').toLowerCase();
    final cloud = permission == 'cloud-edit' || permission == 'preview';
    final name = encrypted
        ? 'lib-encrypted.png'
        : cloud
            ? (permission == 'cloud-edit' ? 'lib-cloud-preview-edit.png' : 'lib-cloud-preview.png')
            : readOnly
                ? 'lib-readonly.png'
                : 'lib.png';
    return Image.asset('assets/web/lib/$name', width: size, height: size, filterQuality: FilterQuality.medium);
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 30, this.image});

  final String name;
  final double size;
  final ImageProvider? image;

  static const _palette = [
    Color(0xFFFFA94D),
    Color(0xFF6C9BD2),
    Color(0xFF69B578),
    Color(0xFFB08BD6),
    Color(0xFFE07A8B),
  ];

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'[\s._@-]+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${_first(parts.first)}${_first(parts.last)}'.toUpperCase();
    }
    final runes = trimmed.runes.toList();
    return String.fromCharCodes(runes.take(2)).toUpperCase();
  }

  String _first(String value) => value.isEmpty ? '' : String.fromCharCode(value.runes.first);

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    if (image != null) {
      return CircleAvatar(radius: size / 2, backgroundImage: image);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.w600, height: 1),
      ),
    );
  }
}

class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.cursor = SystemMouseCursors.click});

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}

class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 18,
    this.color,
    this.padding = const EdgeInsets.all(6),
  });

  final String icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        hoverColor: AppColors.hover,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: padding,
          child: WebIcon(icon, size: size, color: onPressed == null ? AppColors.muted : color),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = 'folder-open', this.action});

  final String title;
  final String? message;
  final String icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebIcon(icon, size: 46, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class CompactSwitch extends StatelessWidget {
  const CompactSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 18,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? AppColors.primary : const Color(0xFFD9DEE7),
            borderRadius: BorderRadius.circular(9),
            boxShadow: value ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.24), blurRadius: 4)] : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 2, offset: const Offset(0, 1))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResizeHandle extends StatefulWidget {
  const ResizeHandle({super.key, required this.onDrag, this.width = 5});

  final ValueChanged<double> onDrag;
  final double width;

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _dragging = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: widget.width,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 1,
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag, this.onDeleted});

  final TagInfo tag;
  final VoidCallback? onDeleted;

  Color get _color {
    final value = tag.color.replaceFirst('#', '');
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return AppColors.primary;
    return Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(tag.name, style: TextStyle(fontSize: 12, color: _color, height: 1.2)),
          if (onDeleted != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDeleted,
              child: Icon(Icons.close_rounded, size: 12, color: _color),
            ),
          ],
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : const Color(0xFF33383D),
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '',
  String cancelLabel = '',
  bool danger = false,
}) async {
  final l10n = L10n.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel.isEmpty ? l10n.cancel : cancelLabel),
        ),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel.isEmpty ? l10n.confirm : confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String? hint,
  String confirmLabel = '',
  String? Function(String value)? validator,
}) async {
  final l10n = L10n.of(context);
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, hintText: hint, errorText: error),
              onFieldSubmitted: (_) {
                final value = controller.text.trim();
                final validation = validator?.call(value);
                if (validation != null) {
                  setState(() => error = validation);
                  return;
                }
                Navigator.pop(context, value);
              },
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              final validation = validator?.call(value);
              if (validation != null) {
                setState(() => error = validation);
                return;
              }
              Navigator.pop(context, value);
            },
            child: Text(confirmLabel.isEmpty ? l10n.confirm : confirmLabel),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<void> showErrorDialog(BuildContext context, String message, {String? title}) {
  final l10n = L10n.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? l10n.operationFailed),
      content: Text(message),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.confirm)),
      ],
    ),
  );
}

String friendlyError(BuildContext context, Object error) {
  if (error is ApiException) return error.friendly(L10n.of(context));
  return error.toString();
}

class DividerLine extends StatelessWidget {
  const DividerLine({super.key, this.height = 1, this.color = AppColors.border});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: height, color: color);
}
