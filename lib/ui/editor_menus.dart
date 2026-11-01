import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
import '../core/theme.dart';

/// Menu chrome shared by the native editors so every popup matches the rest of
/// the app: white surface, hairline border, 8px radius and 36px rows.
PopupMenuButton<T> editorPopupMenu<T>({
  required String tooltip,
  required List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder,
  required ValueChanged<T> onSelected,
  required Widget child,
  double minWidth = 180,
}) {
  return PopupMenuButton<T>(
    tooltip: tooltip,
    offset: const Offset(0, 4),
    position: PopupMenuPosition.under,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    constraints: BoxConstraints(
      minWidth: minWidth,
      maxWidth: 300,
      maxHeight: 430,
    ),
    onSelected: onSelected,
    itemBuilder: itemBuilder,
    child: child,
  );
}

class EditorMenuTrigger extends StatefulWidget {
  const EditorMenuTrigger({
    super.key,
    this.icon,
    this.label,
    this.showArrow = true,
    this.iconColor,
  });

  final IconData? icon;
  final String? label;
  final bool showArrow;
  final Color? iconColor;

  @override
  State<EditorMenuTrigger> createState() => _EditorMenuTriggerState();
}

class _EditorMenuTriggerState extends State<EditorMenuTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.hover,
        curve: AppMotion.curve,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null)
              Icon(
                widget.icon,
                size: 16,
                color: widget.iconColor ?? AppColors.textSecondary,
              ),
            if (widget.icon != null && widget.label != null)
              const SizedBox(width: 4),
            if (widget.label != null)
              Text(
                widget.label!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            if (widget.showArrow) ...[
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<T> editorMenuItem<T>(
  T value, {
  required String label,
  IconData? icon,
  Widget? leading,
  TextStyle? textStyle,
  bool selected = false,
  bool danger = false,
  bool enabled = true,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    enabled: enabled,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? const Icon(Icons.check, size: 15, color: AppColors.primary)
              : leading ??
                    (icon == null
                        ? null
                        : Icon(
                            icon,
                            size: 16,
                            color: danger
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (textStyle ?? const TextStyle(fontSize: 13)).copyWith(
              color: danger ? AppColors.danger : AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}

PopupMenuDivider editorMenuDivider() => const PopupMenuDivider(height: 9);


/// Shows the fast editor context menu at a global pointer position. Native
/// text-selection toolbars stay disabled in the editors so this is the only
/// menu that appears.
Future<void> showEditorContextMenu({
  required BuildContext context,
  required Offset position,
  required TextEditingController controller,
  VoidCallback? onInsertLink,
  VoidCallback? onCopyDocumentLink,
}) async {
  final l10n = L10n.of(context);
  final overlay = Overlay.of(context).context.findRenderObject();
  final size = overlay is RenderBox ? overlay.size : MediaQuery.sizeOf(context);
  final selection = controller.selection;
  final hasSelection = selection.isValid && !selection.isCollapsed;
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      (size.width - position.dx).clamp(0.0, double.infinity),
      (size.height - position.dy).clamp(0.0, double.infinity),
    ),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    menuPadding: const EdgeInsets.symmetric(vertical: 5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    items: [
      editorMenuItem('cut', label: l10n.zh ? '剪切' : 'Cut', icon: Icons.content_cut, enabled: hasSelection),
      editorMenuItem('copy', label: l10n.copy, icon: Icons.content_copy, enabled: hasSelection),
      editorMenuItem('paste', label: l10n.zh ? '粘贴' : 'Paste', icon: Icons.content_paste),
      editorMenuItem('delete', label: l10n.delete, icon: Icons.delete_outline, danger: true, enabled: hasSelection),
      editorMenuDivider(),
      editorMenuItem('select_all', label: l10n.zh ? '全选' : 'Select all', icon: Icons.select_all),
      if (onInsertLink != null) ...[
        editorMenuDivider(),
        editorMenuItem('link', label: l10n.zh ? '添加链接' : 'Add link', icon: Icons.link),
      ],
      if (onCopyDocumentLink != null)
        editorMenuItem('copy_link', label: l10n.zh ? '复制文档链接' : 'Copy document link', icon: Icons.link),

    ],
  );
  if (action == null) return;

  TextSelection selected() {
    final current = controller.selection;
    if (!current.isValid) return TextSelection.collapsed(offset: controller.text.length);
    return current;
  }

  switch (action) {
    case 'cut':
      final current = selected();
      if (current.isCollapsed) return;
      final text = controller.text.substring(current.start, current.end);
      await Clipboard.setData(ClipboardData(text: text));
      final value = controller.value;
      controller.value = TextEditingValue(
        text: value.text.replaceRange(current.start, current.end, ''),
        selection: TextSelection.collapsed(offset: current.start),
        composing: TextRange.empty,
      );
    case 'copy':
      final current = selected();
      if (current.isCollapsed) return;
      await Clipboard.setData(ClipboardData(text: controller.text.substring(current.start, current.end)));
    case 'paste':
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      final current = selected();
      final value = controller.value;
      final start = current.isCollapsed ? current.start : current.start;
      final end = current.isCollapsed ? current.start : current.end;
      controller.value = TextEditingValue(
        text: value.text.replaceRange(start, end, text),
        selection: TextSelection.collapsed(offset: start + text.length),
        composing: TextRange.empty,
      );
    case 'delete':
      final current = selected();
      if (current.isCollapsed) return;
      final value = controller.value;
      controller.value = TextEditingValue(
        text: value.text.replaceRange(current.start, current.end, ''),
        selection: TextSelection.collapsed(offset: current.start),
        composing: TextRange.empty,
      );
    case 'select_all':
      controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    case 'link':
      onInsertLink?.call();
    case 'copy_link':
      onCopyDocumentLink?.call();
  }
}
