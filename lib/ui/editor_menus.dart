import 'package:flutter/material.dart';

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
        duration: const Duration(milliseconds: 90),
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
