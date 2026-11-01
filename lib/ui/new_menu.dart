import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/models.dart';
import '../core/format.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/workspace.dart';
import 'share_dialog.dart';
import 'widgets.dart';

class NewMenuButton extends StatelessWidget {
  const NewMenuButton({
    super.key,
    required this.workspace,
    required this.onUploadFiles,
    required this.onUploadFolder,
    this.child,
  });

  final WorkspaceController workspace;
  final VoidCallback onUploadFiles;
  final VoidCallback onUploadFolder;
  final Widget? child;

  MenuStyle get _menuStyle => MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        shadowColor: const WidgetStatePropertyAll(Color(0x29000000)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 5)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        )),
        minimumSize: const WidgetStatePropertyAll(Size(238, 0)),
      );

  ButtonStyle get _itemStyle => ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.text),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
            return const Color(0xFFF2F2F2);
          }
          return Colors.white;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        iconColor: const WidgetStatePropertyAll(AppColors.textSecondary),
        iconSize: const WidgetStatePropertyAll(16),
        minimumSize: const WidgetStatePropertyAll(Size(238, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, color: AppColors.text)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final repo = workspace.repo;
    return MenuAnchor(
      style: _menuStyle,
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        if (workspace.canWrite) ...[
          MenuItemButton(
            style: _itemStyle,
            leadingIcon: const WebIcon('new-folder', size: 16, color: AppColors.textSecondary),
            onPressed: () => _newFolder(context),
            child: Text(l10n.newDirectory, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ),
          SubmenuButton(
            style: _itemStyle,
            menuStyle: _menuStyle,
            leadingIcon: const WebIcon('new-file', size: 16, color: AppColors.textSecondary),
            menuChildren: _fileTypeItems(context, l10n),
            child: Text(l10n.newFile, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ),
          const Divider(height: 10, color: AppColors.border),
          MenuItemButton(
            style: _itemStyle,
            leadingIcon: const WebIcon('upload-files', size: 16, color: AppColors.textSecondary),
            onPressed: onUploadFiles,
            child: Text(l10n.uploadFiles, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ),
          MenuItemButton(
            style: _itemStyle,
            leadingIcon: const WebIcon('upload-folder', size: 16, color: AppColors.textSecondary),
            onPressed: onUploadFolder,
            child: Text(l10n.uploadDirectory, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ),
        ],
        const Divider(height: 10, color: AppColors.border),
        MenuItemButton(
          style: _itemStyle,
          leadingIcon: const WebIcon('share', size: 16, color: AppColors.textSecondary),
          onPressed: () => _shareFolder(context),
          child: Text(l10n.share, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ),
        MenuItemButton(
          style: _itemStyle,
          leadingIcon: const WebIcon('link', size: 16, color: AppColors.textSecondary),
          onPressed: () => _copyPath(context),
          child: Text(l10n.copyPath, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ),
        if (workspace.seaDocEnabled && repo != null && !repo.encrypted) ...[
          const Divider(height: 10, color: AppColors.border),
          MenuItemButton(
            style: _itemStyle,
            leadingIcon: const WebIcon('import-sdoc', size: 16, color: AppColors.textSecondary),
            onPressed: () => _importSdoc(context),
            child: Text(l10n.importSdoc, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          ),
        ],
      ],
      builder: (context, controller, anchorChild) {
        return HoverBuilder(
          builder: (context, hovered) => InkWell(
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(4),
            hoverColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            child: child != null
                ? AnimatedContainer(
                    duration: AppMotion.hover,
                    curve: AppMotion.curve,
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    decoration: BoxDecoration(
                      color: hovered ? AppColors.hover : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: child,
                  )
                : AnimatedContainer(
                  duration: AppMotion.hover,
                  curve: AppMotion.curve,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hovered ? AppColors.hover : Colors.transparent,
                    border: Border.all(color: AppColors.borderStrong),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const WebIcon('plus-sign', size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(l10n.newButton, style: const TextStyle(fontSize: 14, color: AppColors.text)),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }

  List<Widget> _fileTypeItems(BuildContext context, L10n l10n) {
    final repo = workspace.repo;
    final canSeaDoc = workspace.seaDocEnabled && repo != null && !repo.encrypted;
    final items = <Widget>[
      _fileItem(context, l10n.newTextFile, '', l10n),
      const Divider(height: 10, color: AppColors.border),
      if (canSeaDoc) ...[
        _fileItem(context, l10n.newSeaDocFile, '.sdoc', l10n),
        _fileItem(context, l10n.newExcalidrawFile, '.exdraw', l10n),
      ],
      _fileItem(context, l10n.newMarkdownFile, '.md', l10n),
      if (canSeaDoc)
        MenuItemButton(
          style: _itemStyle,
          leadingIcon: const WebIcon('import-sdoc', size: 16, color: AppColors.textSecondary),
          onPressed: () => _importSdoc(context),
          child: Text(l10n.importSdoc, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ),
      _fileItem(context, l10n.newExcelFile, '.xlsx', l10n),
      _fileItem(context, l10n.newPowerPointFile, '.pptx', l10n),
      _fileItem(context, l10n.newWordFile, '.docx', l10n),
    ];
    return items;
  }


  Widget _fileItem(BuildContext context, String label, String suffix, L10n l10n) {
    return MenuItemButton(
      style: _itemStyle,
      onPressed: () => _createFile(context, suffix, l10n),
      child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
    );
  }

  Future<void> _newFolder(BuildContext context) async {
    final l10n = L10n.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.newFolder,
      label: l10n.folderName,
      validator: (value) => value.trim().isEmpty ? l10n.folderNameRequired : null,
    );
    if (name == null || !context.mounted) return;
    try {
      await workspace.createFolder(name.trim());
      if (context.mounted) showToast(context, l10n.folderCreated);
    } catch (error) {
      if (context.mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _createFile(BuildContext context, String suffix, L10n l10n) async {
    final initial = suffix.isEmpty ? l10n.untitled : '${l10n.untitled}$suffix';
    final raw = await showTextPrompt(
      context,
      title: suffix.isEmpty ? l10n.newTextFile : l10n.newFile,
      label: l10n.fileName,
      initialValue: initial,
      validator: (value) {
        if (value.trim().isEmpty) return l10n.fileName;
        final finalName = _normalizeName(value.trim(), suffix);
        if (workspace.entries.any((entry) => entry.name == finalName)) return l10n.fileAlreadyExists;
        return null;
      },
    );
    if (raw == null || !context.mounted) return;
    final name = _normalizeName(raw.trim(), suffix);
    try {
      await workspace.createFile(joinRepoPath(workspace.path, name));
      if (context.mounted) showToast(context, l10n.fileCreated);
    } catch (error) {
      if (context.mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  String _normalizeName(String name, String suffix) {
    if (suffix.isEmpty) return name;
    return name.toLowerCase().endsWith(suffix) ? name : '$name$suffix';
  }

  Future<void> _importSdoc(BuildContext context) async {
    final l10n = L10n.of(context);
    const group = XTypeGroup(label: 'SeaDoc', extensions: ['sdoczip']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !context.mounted) return;
    try {
      await workspace.importSdoc(file.path);
      if (context.mounted) showToast(context, l10n.sdocImported);
    } catch (error) {
      if (context.mounted) showToast(context, friendlyError(context, error), error: true);
    }
  }

  Future<void> _copyPath(BuildContext context) async {
    final l10n = L10n.of(context);
    await Clipboard.setData(ClipboardData(text: workspace.path));
    if (context.mounted) showToast(context, l10n.pathCopied);
  }

  Future<void> _shareFolder(BuildContext context) async {
    final repo = workspace.repo;
    if (repo == null) return;
    final path = workspace.path;
    final target = Dirent(
      name: path == '/' ? repo.name : baseName(path),
      path: path,
      isDir: true,
    );
    await shareEntry(context, workspace, target);
  }
}
