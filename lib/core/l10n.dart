import 'package:flutter/widgets.dart';

class L10n {
  const L10n(this.zh);

  final bool zh;

  static L10n of(BuildContext context) => Localizations.of<L10n>(context, L10n)!;

  String get appName => 'Seafile';
  String get appTagline => zh ? '安全地存储和共享文件' : 'Store and share files securely';

  // Login
  String get serverAddress => zh ? '服务器地址' : 'Server address';
  String get serverHint => 'https://cloud.example.com';
  String get username => zh ? '邮箱或用户名' : 'Email or username';
  String get password => zh ? '密码' : 'Password';
  String get rememberMe => zh ? '保持登录' : 'Keep me signed in';
  String get forgotPassword => zh ? '忘记密码？' : 'Forgot password?';
  String get signIn => zh ? '登录' : 'Sign in';
  String get signingIn => zh ? '正在登录…' : 'Signing in…';
  String get advancedOptions => zh ? '高级选项' : 'Advanced options';
  String get allowUntrusted => zh ? '允许不受信任的 TLS 证书（仅用于自签名服务器）' : 'Allow untrusted TLS certificates (self-signed servers only)';
  String get invalidServer => zh ? '请输入有效的服务器地址，例如 https://cloud.seafile.com' : 'Enter a valid server address, for example https://cloud.seafile.com.';
  String get wrongCredentials => zh ? '用户名或密码错误' : 'Wrong username or password.';
  String get serverUnreachable => zh ? '无法连接服务器，请检查地址和网络。' : 'Cannot reach the server. Check the address and your network.';
  String get loginFailed => zh ? '登录失败' : 'Sign-in failed';
  String get twoFactorTitle => zh ? '两步验证' : 'Two-factor authentication';
  String get twoFactorHint => zh ? '请输入身份验证器中的 6 位验证码。' : 'Enter the 6-digit code from your authenticator app.';
  String get otpCode => zh ? '验证码' : 'Verification code';
  String get trustDevice => zh ? '信任此设备' : 'Trust this device';
  String get verify => zh ? '验证' : 'Verify';
  String get invalidOtp => zh ? '验证码不正确' : 'The verification code is incorrect.';

  // Common
  String get cancel => zh ? '取消' : 'Cancel';
  String get confirm => zh ? '确定' : 'OK';
  String get close => zh ? '关闭' : 'Close';
  String get back => zh ? '返回' : 'Back';
  String get retry => zh ? '重试' : 'Retry';
  String get refresh => zh ? '刷新' : 'Refresh';
  String get save => zh ? '保存' : 'Save';
  String get create => zh ? '创建' : 'Create';
  String get rename => zh ? '重命名' : 'Rename';
  String get delete => zh ? '删除' : 'Delete';
  String get download => zh ? '下载' : 'Download';
  String get upload => zh ? '上传' : 'Upload';
  String get open => zh ? '打开' : 'Open';
  String get preview => zh ? '预览' : 'Preview';
  String get edit => zh ? '编辑' : 'Edit';
  String get editMode => zh ? '编辑' : 'Edit';
  String get previewMode => zh ? '预览' : 'Preview';
  String get saving => zh ? '正在保存…' : 'Saving…';
  String get savedSuccessfully => zh ? '已保存' : 'Saved';
  String get saveFailed => zh ? '保存失败' : 'Save failed';
  String get unsavedChanges => zh ? '有未保存的修改' : 'Unsaved changes';
  String get discardChanges => zh ? '放弃修改' : 'Discard changes';
  String get keepEditing => zh ? '继续编辑' : 'Keep editing';
  String get fileTooLargeToEdit => zh ? '文件过大，无法在线编辑。' : 'This file is too large to edit.';
  String get loadFileFailed => zh ? '文件加载失败' : 'Could not load the file.';
  String get editorHint => zh ? '支持纯文本和 Markdown，保存会覆盖原文件。' : 'Plain text and Markdown are supported; saving replaces the original file.';
  String linesCount(int count) => zh ? '$count 行' : '$count lines';
  String charsCount(int count) => zh ? '$count 字符' : '$count characters';
  String get copy => zh ? '复制' : 'Copy';
  String get move => zh ? '移动' : 'Move';
  String get share => zh ? '分享' : 'Share';
  String get details => zh ? '详细信息' : 'Details';
  String get history => zh ? '历史版本' : 'Version history';
  String get historyNav => zh ? '历史' : 'History';
  String get more => zh ? '更多' : 'More';
  String get chatWithAi => zh ? '与 AI 对话' : 'Chat with AI';
  String get view => zh ? '视图' : 'Views';
  String get allFiles => zh ? 'All files' : 'All files';
  String get tags => zh ? '标签' : 'Tags';
  String get allTags => zh ? '全部标签' : 'All tags';
  String get other => zh ? '其他' : 'Other';
  String get watchFileChanges => zh ? '关注文件改动' : 'Watch file changes';
  String get settings => zh ? '设置' : 'Settings';
  String get addTag => zh ? '添加标签' : 'Add tag';
  String get newTag => zh ? '新建标签' : 'New tag';
  String get tagName => zh ? '标签名称' : 'Tag name';
  String get color => zh ? '颜色' : 'Color';
  String get aiSummary => zh ? 'AI 摘要' : 'AI summary';
  String get fileInfo => zh ? '文件信息' : 'File information';
  String get fileSize => zh ? '文件大小' : 'File size';
  String get modifier => zh ? '修改者' : 'Modified by';
  String get addedToDownloads => zh ? '已加入下载队列' : 'Added to downloads';
  String get addedToUploads => zh ? '已加入上传队列' : 'Added to uploads';
  String get openInNewWindow => zh ? '预览' : 'Preview';
  String get downloadSelected => zh ? '下载所选' : 'Download selected';
  String get noTagsHint => zh ? '为文件添加标签，便于分类和搜索。' : 'Add tags to organize and search files.';
  String get metadata => zh ? '元数据' : 'Metadata';
  String get metadataTab => zh ? '元数据' : 'Metadata';
  String get expiryTime => zh ? '过期时间' : 'Expiry';
  String get collaborators => zh ? '协作者' : 'Collaborators';
  String get status => zh ? '状态' : 'Status';
  String get loadingMore => zh ? '加载更多…' : 'Load more…';
  String get loadMore => zh ? '加载更多' : 'Load more';
  String get clear => zh ? '清空' : 'Clear';
  String get closePanel => zh ? '关闭面板' : 'Close panel';
  String get deleteSelected => zh ? '删除所选' : 'Delete selected';
  String get moveSelected => zh ? '移动所选' : 'Move selected';
  String get copySelected => zh ? '复制所选' : 'Copy selected';
  String get shareSelected => zh ? '分享' : 'Share';
  String get enterFolder => zh ? '打开' : 'Open';
  String get downloadSelectedHint => zh ? '将所选文件下载到…' : 'Download selected to…';
  String get uploadStarted => zh ? '开始上传' : 'Upload started';
  String get uploadFolderStarted => zh ? '开始上传文件夹' : 'Uploading folder';
  String get operationInProgress => zh ? '正在处理…' : 'Working…';
  String get retryUpload => zh ? '重试' : 'Retry';
  String get noPermissionForAction => zh ? '没有权限执行此操作' : 'You do not have permission for this action';
  String get sortTitle => zh ? '排序方式' : 'Sort by';
  String get hideColumns => zh ? '隐藏列' : 'Hide columns';
  String get tagColumn => zh ? '标签' : 'Tags';
  String get created => zh ? '创建时间' : 'Created';
  String get fileIdShort => zh ? 'ID' : 'ID';
  String get showDetails => zh ? '属性' : 'Properties';
  String get permission => zh ? '权限' : 'Permission';
  String get metadataDisabled => zh ? '元数据未启用' : 'Metadata is not enabled';
  String get saveChanges => zh ? '保存' : 'Save';
  String get saved => zh ? '已保存' : 'Saved';
  String get restoreFromTrash => zh ? '恢复' : 'Restore';
  String get trashRestoreSelected => zh ? '恢复所选' : 'Restore selected';
  String get trashEmptyAction => zh ? '清空回收站' : 'Empty trash';
  String get emptyTrashAction => trashEmptyAction;
  String get deletedBy => zh ? '删除者' : 'Deleted by';
  String get originalPath => zh ? '原位置' : 'Original location';
  String get revert => zh ? '还原' : 'Revert';
  String get revertRepoConfirm => zh ? '确定将资料库还原到此版本吗？当前内容会被替换。' : 'Revert the library to this version? Current content will be replaced.';
  String get reverted => zh ? '已还原' : 'Reverted';
  String get newChat => zh ? '新对话' : 'New chat';
  String get chatHistory => zh ? '历史对话' : 'Chat history';
  String get chatPlaceholder => zh ? '向资料库提问…' : 'Ask your library…';
  String get send => zh ? '发送' : 'Send';
  String get stop => zh ? '停止' : 'Stop';
  String get aiThinking => zh ? 'AI 正在思考…' : 'AI is thinking…';
  String get noChats => zh ? '暂无历史对话' : 'No conversations yet';
  String get references => zh ? '参考文件' : 'References';
  String get enableMetadata => zh ? '文件扩展属性' : 'File metadata';
  String get enableTags => zh ? '标签' : 'Tags';
  String get enableAiSummary => zh ? 'AI 对话与搜索' : 'AI chat and search';
  String get globalHiddenProperties => zh ? '全局隐藏属性' : 'Globally hidden properties';
  String get globalHiddenHint => zh ? '全局隐藏属性不会在所有视图中显示。' : 'Globally hidden properties are not shown in any view.';
  String get hideProperties => zh ? '隐藏属性' : 'Hide properties';
  String get metadataAiTab => zh ? '元数据与 AI' : 'Metadata & AI';
  String get generalTab => zh ? '通用' : 'General';
  String get historySetting => zh ? '历史' : 'History';
  String get keepAllHistory => zh ? '保留所有历史' : 'Keep all history';
  String get keepNoHistory => zh ? '不保留历史' : 'Keep no history';
  String get keepDaysHistory => zh ? '仅保留一段时间的历史：' : 'Keep history for:';
  String get days => zh ? '天' : 'days';
  String get metadataEnabledHint => zh ? '为文件启用扩展属性后，你可以向文件添加不同的属性，如协作者、文件过期时间、文件描述。你还可以基于文件的扩展特性创建不同的视图。' : 'Enable extended properties to add collaborators, expiry dates, descriptions, and build views from them.';
  String get aiEnabledHint => zh ? '在文件上启用 AI 对话和 AI 搜索。系统将对你的文件进行摘要，以便 AI 在对话中高效查找你的文件。' : 'Enable AI chat and search. Files are summarised so the AI can find them efficiently.';
  String get tagsEnabledHint => zh ? '启用标签功能以向文件添加标签并按标签搜索文件。' : 'Enable tags to label files and search by tag.';
  String get viewStatus => zh ? '查看状态' : 'View status';
  String get savedPreferences => zh ? '设置已保存' : 'Settings saved';
  String get emptyTrashConfirmShort => zh ? '确定清空回收站吗？' : 'Empty the trash?';
  String get restoreDone => zh ? '已恢复' : 'Restored';
  String get deleteLibraryShort => zh ? '删除资料库' : 'Delete library';

  String get loading => zh ? '加载中…' : 'Loading…';
  String get operationFailed => zh ? '操作失败' : 'Operation failed';
  String get networkError => zh ? '网络错误，请稍后重试。' : 'Network error. Please try again.';
  String get permissionDenied => zh ? '没有权限执行此操作' : 'You do not have permission to do this.';
  String get notFound => zh ? '文件或目录不存在' : 'The file or folder no longer exists.';
  String get serverError => zh ? '服务器错误' : 'Server error';
  String get sessionExpired => zh ? '登录已过期，请重新登录' : 'Your session has expired. Please sign in again.';
  String get unknownError => zh ? '发生未知错误' : 'An unknown error occurred.';
  String get search => zh ? '搜索' : 'Search';
  String get workspace => zh ? '工作区' : 'Workspace';
  String get favorites => zh ? '收藏夹' : 'Favorites';
  String get starredEmpty => zh ? '还没有收藏任何文件' : 'No starred items yet';
  String get starredHint => zh ? '在文件上点击星标即可收藏。' : 'Star a file or folder to keep it here.';
  String get starredLoadFailed => zh ? '加载收藏失败' : 'Could not load favorites.';
  String get activitiesEmpty => zh ? '暂无文件活动' : 'No activities yet';
  String get activitiesHint => zh ? '资料库中的文件变动会显示在这里。' : 'File changes in your libraries appear here.';
  String get activitiesLoadFailed => zh ? '加载文件活动失败' : 'Could not load activities.';
  String get activityCreate => zh ? '新增了' : 'created';
  String get activityEdit => zh ? '修改了' : 'edited';
  String get activityDelete => zh ? '删除了' : 'deleted';
  String get activityRecover => zh ? '恢复了' : 'restored';
  String get activityRename => zh ? '重命名了' : 'renamed';
  String get activityMove => zh ? '移动了' : 'moved';
  String get activityCopy => zh ? '复制了' : 'copied';
  String get activityOther => zh ? '操作了' : 'updated';
  String get deletedLibrariesHint => zh ? '删除的资料库会保留一段时间，可在这里恢复。' : 'Deleted libraries are kept for a while and can be restored here.';
  String get noDeletedLibraries => zh ? '没有已删除的资料库' : 'No deleted libraries';
  String get restoreLibrary => zh ? '恢复资料库' : 'Restore library';
  String get cleanAll => zh ? '全部清理' : 'Clean all';
  String get cleanDeletedConfirm => zh ? '确定永久清理全部已删除资料库吗？此操作无法撤销。' : 'Permanently clean all deleted libraries? This cannot be undone.';
  String get libraryRestored => zh ? '资料库已恢复' : 'Library restored';
  String get deletedLibrariesCleaned => zh ? '已清理删除的资料库' : 'Deleted libraries cleaned';
  String get shareAdminEmpty => zh ? '暂无分享链接' : 'No share links';
  String get shareAdminHint => zh ? '你创建的所有分享链接会显示在这里。' : 'All share links you created are listed here.';
  String get shareAdminLoadFailed => zh ? '加载分享链接失败' : 'Could not load share links.';
  String get openInWebApp => zh ? '在网页版中打开' : 'Open in web app';
  String get groupManagement => zh ? '群组管理' : 'Group management';
  String get myWikis => zh ? '我的知识库' : 'My wikis';
  String get sharedWikis => zh ? '共享给我的知识库' : 'Shared with me';
  String get legacyWikis => zh ? '旧版知识库' : 'Legacy wikis';
  String get noWikis => zh ? '暂无知识库' : 'No wikis yet';
  String get wikisHint => zh ? '知识库在网页版中创建和编辑。' : 'Wikis are created and edited in the web app.';
  String get wikisLoadFailed => zh ? '加载知识库失败' : 'Could not load wikis.';
  String get published => zh ? '已发布' : 'Published';
  String get updatedAt => zh ? '更新于' : 'Updated';
  String get notifications => zh ? '通知' : 'Notifications';
  String get notificationsEmpty => zh ? '暂无通知' : 'No notifications';
  String get notificationsHint => zh ? '共享、评论、上传等通知会显示在这里。' : 'Shares, comments and uploads appear here.';
  String get notificationsLoadFailed => zh ? '加载通知失败' : 'Could not load notifications.';
  String get markAllRead => zh ? '全部已读' : 'Mark all read';
  String get notificationGeneric => zh ? '有一条新的文件通知' : 'You have a file notification';
  String notificationFileUploaded(String file, String repo) => zh ? '上传了文件 $file 到 $repo' : 'uploaded $file to $repo';
  String notificationFileComment(String file, String repo) => zh ? '在 $repo 中评论了 $file' : 'commented on $file in $repo';
  String notificationRepoShare(String repo) => zh ? '共享了资料库 $repo' : 'shared the library $repo';
  String notificationFolderShare(String folder, String repo) => zh ? '共享了 $repo 中的文件夹 $folder' : 'shared the folder $folder in $repo';
  String notificationGroup(String group) => zh ? '邀请你加入群组 $group' : 'invited you to the group $group';
  String notificationDeleted(String repo) => zh ? '删除了 $repo 中的文件' : 'deleted files in $repo';
  String notificationDiscussion(String repo) => zh ? '$repo 中有新的文档评论或回复' : 'new document comment or reply in $repo';
  String get activities => zh ? '文件活动' : 'Activities';
  String get wikis => zh ? '知识库' : 'Wikis';
  String get shareAdmin => zh ? '共享管理' : 'Share Admin';
  String get helpResources => zh ? '帮助和资源' : 'Help and resources';
  String get help => zh ? '帮助' : 'Help';
  String get clients => zh ? '客户端' : 'Clients';
  String get collapseSidebar => zh ? '收起侧边栏' : 'Collapse sidebar';
  String get expandSidebar => zh ? '展开侧边栏' : 'Expand sidebar';
  String get newGroup => zh ? '新建群组' : 'New group';
  String get deletedLibraries => zh ? '已删除的资料库' : 'Deleted libraries';
  String get noSharedLibraries => zh ? '没有共享的资料库' : 'No shared libraries';
  String get noPublicLibraries => zh ? '没有公共资料库' : 'No public libraries';
  String get searchShortcut => zh ? '搜索文件 (⌘ + K)' : 'Search files (⌘ + K)';
  String get featureNotAvailable => zh ? '此功能暂未在桌面端提供，请在网页版中操作。' : 'This feature is not available in the desktop client yet. Use the web app.';
  String get refreshLibraries => zh ? '刷新资料库' : 'Refresh libraries';
  String get newLibraryShort => zh ? '新建资料库' : 'New library';
  String get newLibrary => newLibraryShort;
  String get unlimitedQuota => zh ? '无限空间' : 'Unlimited storage';
  String get logoutConfirm => zh ? '确定退出登录吗？保存的资料库密码将同时从本机清除。' : 'Sign out? Saved library passwords will be removed from this device.';
  String get libraryDescription => zh ? '描述（可选）' : 'Description (optional)';
  String get descriptionOptional => zh ? '添加描述' : 'Add a description';
  String get noMatches => zh ? '没有匹配项' : 'No matches';

  // Sidebar / shell
  String get myLibraries => zh ? '我的资料库' : 'My libraries';
  String get sharedWithMe => zh ? '共享给我的' : 'Shared with me';
  String get groupLibraries => zh ? '群组资料库' : 'Group libraries';
  String get otherLibraries => zh ? '其他资料库' : 'Other libraries';
  String get allLibraries => zh ? '全部资料库' : 'All libraries';
  String get libraries => zh ? '资料库' : 'Libraries';
  String get searchFiles => zh ? '搜索文件' : 'Search files';
  String get logout => zh ? '退出登录' : 'Sign out';
  String get about => zh ? '关于' : 'About';
  String get account => zh ? '账户' : 'Account';
  String get storageQuota => zh ? '存储空间' : 'Storage';
  String get server => zh ? '服务器' : 'Server';
  String get version => zh ? '版本' : 'Version';
  String quotaUsage(String used, String total) => zh ? '$used / $total' : '$used of $total';
  String get unknownUser => zh ? '未知用户' : 'Unknown user';
  String get librariesCount => zh ? '个资料库' : 'libraries';
  String get collapse => zh ? '收起' : 'Collapse';
  String get expand => zh ? '展开' : 'Expand';

  // Library home
  String get noLibraries => zh ? '还没有资料库' : 'No libraries yet';
  String get noLibrariesHint => zh ? '新建一个资料库，开始上传和整理文件。' : 'Create a library to start uploading and organizing files.';
  String get createLibrary => zh ? '新建资料库' : 'New library';
  String get libraryName => zh ? '资料库名称' : 'Library name';
  String get libraryNameHint => zh ? '输入资料库名称' : 'Enter a library name';
  String get libraryNameRequired => zh ? '请输入资料库名称' : 'Enter a library name';
  String get createdBy => zh ? '创建者' : 'Owner';
  String get lastModified => zh ? '最近修改' : 'Last modified';
  String get readOnly => zh ? '只读' : 'Read only';
  String get encryptedLibrary => zh ? '加密资料库' : 'Encrypted library';
  String get encryptLibrary => zh ? '加密资料库' : 'Encrypt this library';
  String get encryptLibraryHint => zh ? '为此资料库设置密码，文件内容将在服务端加密存储。' : 'Set a password for this library. File contents are encrypted on the server.';
  String get optional => zh ? '可选' : 'Optional';
  String get libraryCreated => zh ? '资料库已创建' : 'Library created';
  String get libraryRenamed => zh ? '资料库已重命名' : 'Library renamed';
  String get libraryDeleted => zh ? '资料库已删除' : 'Library deleted';
  String get renameLibrary => zh ? '重命名资料库' : 'Rename library';
  String get deleteLibrary => zh ? '删除资料库' : 'Delete library';
  String deleteLibraryConfirm(String name) => zh
      ? '确定删除“$name”吗？资料库及其中所有文件将被删除，此操作无法撤销。'
      : 'Delete “$name”? The library and all of its files will be permanently deleted.';
  String get libraryInfo => zh ? '资料库信息' : 'Library information';
  String get emptyLibrary => zh ? '这个资料库还是空的' : 'This library is empty';
  String get emptyLibraryHint => zh ? '上传文件或新建文件夹开始使用。' : 'Upload files or create a folder to get started.';

  // Browser
  String get uploadFiles => zh ? '上传文件' : 'Upload files';
  String get uploadFolder => zh ? '上传文件夹' : 'Upload folder';
  String get newFolder => zh ? '新建文件夹' : 'New folder';
  String get newButton => zh ? '新建' : 'New';
  String get newDirectory => zh ? '新建目录' : 'New directory';
  String get uploadDirectory => zh ? '上传目录' : 'Upload directory';
  String get newFile => zh ? '新建文件' : 'New file';
  String get newTextFile => zh ? '新建文本文件' : 'New text file';
  String get newSeaDocFile => zh ? '新建 SeaDoc 文件' : 'New SeaDoc file';
  String get newExcalidrawFile => zh ? '新建 Excalidraw 文件' : 'New Excalidraw file';
  String get newMarkdownFile => zh ? '新建 Markdown 文件' : 'New Markdown file';
  String get newExcelFile => zh ? '新建 Excel 文件' : 'New Excel file';
  String get newPowerPointFile => zh ? '新建 PowerPoint 文件' : 'New PowerPoint file';
  String get newWordFile => zh ? '新建 Word 文件' : 'New Word file';
  String get importSdoc => zh ? '导入 sdoc' : 'Import sdoc';
  String get copyPath => zh ? '复制路径' : 'Copy path';
  String get pathCopied => zh ? '路径已复制' : 'Path copied';
  String get fileName => zh ? '文件名' : 'File name';
  String get fileAlreadyExists => zh ? '同名文件已存在，请换一个名称。' : 'A file with this name already exists.';
  String get fileCreated => zh ? '文件已创建' : 'File created';
  String get sdocImported => zh ? 'sdoc 文件已导入' : 'sdoc file imported';
  String get shareCurrentFolder => zh ? '分享当前文件夹' : 'Share this folder';
  String get folderName => zh ? '文件夹名称' : 'Folder name';
  String get folderNameRequired => zh ? '请输入文件夹名称' : 'Enter a folder name';
  String get downloadFolder => zh ? '打包下载' : 'Download folder';
  String get emptyFolder => zh ? '此文件夹为空' : 'This folder is empty';
  String get emptyFolderHint => zh ? '拖入文件即可上传。' : 'Drop files here to upload.';
  String get dropToUpload => zh ? '松开鼠标上传文件' : 'Drop to upload';
  String get name => zh ? '名称' : 'Name';
  String get size => zh ? '大小' : 'Size';
  String get modified => zh ? '修改时间' : 'Modified';
  String get actions => zh ? '操作' : 'Actions';
  String get sortBy => zh ? '排序方式' : 'Sort by';
  String get sortName => zh ? '名称' : 'Name';
  String get sortModified => zh ? '修改时间' : 'Modified';
  String get sortSize => zh ? '大小' : 'Size';
  String get ascending => zh ? '升序' : 'Ascending';
  String get descending => zh ? '降序' : 'Descending';
  String get listView => zh ? '列表视图' : 'List view';
  String get gridView => zh ? '网格视图' : 'Grid view';
  String get filterFolder => zh ? '筛选当前文件夹…' : 'Filter this folder…';
  String get selectAll => zh ? '全选' : 'Select all';
  String get clearSelection => zh ? '取消选择' : 'Clear selection';
  String selectedCount(int count) => zh ? '已选择 $count 项' : '$count selected';
  String itemsCount(int count) => zh ? '共 $count 项' : '$count items';
  String get noMatchingFiles => zh ? '没有匹配的文件' : 'No matching files';
  String get loadFailed => zh ? '加载失败' : 'Failed to load';
  String get path => zh ? '路径' : 'Path';
  String get owner => zh ? '所有者' : 'Owner';
  String get currentFolder => zh ? '当前文件夹' : 'Current folder';
  String get reload => zh ? '重新加载' : 'Reload';
  String get backToLibraries => zh ? '返回资料库' : 'All libraries';
  String get dropFilesHint => zh ? '支持拖拽文件或文件夹' : 'Drag files or folders here';
  String get deleteEntriesTitle => zh ? '删除项目' : 'Delete items';
  String deleteEntriesConfirm(int count) => zh
      ? '确定删除选中的 $count 个项目吗？删除后可在回收站中恢复。'
      : 'Delete the $count selected items? You can restore them from the trash.';
  String deleteEntryConfirm(String name) => zh
      ? '确定删除“$name”吗？删除后可在回收站中恢复。'
      : 'Delete “$name”? You can restore it from the trash.';
  String deleteFolderConfirm(String name) => zh
      ? '确定删除文件夹“$name”及其中的所有内容吗？'
      : 'Delete the folder “$name” and everything inside it?';
  String get entriesDeleted => zh ? '已删除' : 'Deleted';
  String get renamed => zh ? '已重命名' : 'Renamed';
  String get folderCreated => zh ? '文件夹已创建' : 'Folder created';
  String get moved => zh ? '已移动' : 'Moved';
  String get copied => zh ? '已复制' : 'Copied';

  // Details
  String get fileDetails => zh ? '详细信息' : 'Details';
  String get type => zh ? '类型' : 'Type';
  String get location => zh ? '位置' : 'Location';
  String get fileId => zh ? '文件 ID' : 'File ID';
  String get noPermission => zh ? '无权限' : 'No permission';

  // Preview
  String get previewUnsupported => zh ? '该文件类型暂不支持内置预览，请下载后打开。' : 'This file type cannot be previewed here. Download it to open.';
  String get previewLoadFailed => zh ? '预览加载失败' : 'Could not load the preview.';
  String get fileTooLarge => zh ? '文件过大，无法内置预览。' : 'This file is too large to preview.';
  String get textPreviewTruncated => zh ? '文件较大，仅显示前 1 MB 内容。' : 'Large file: only the first 1 MB is shown.';
  String get preparingPreview => zh ? '正在准备预览…' : 'Preparing preview…';
  String get downloadToOpen => zh ? '下载' : 'Download';
  String get openWithDefaultApp => zh ? '用默认应用打开' : 'Open in default app';
  String get cannotOpenFile => zh ? '无法打开该文件' : 'Could not open the file';
  String get openInBrowser => zh ? '在网页版中打开' : 'Open in web app';
  String previewOf(String name) => zh ? '预览：$name' : 'Preview: $name';
  String get imageLoadFailed => zh ? '图片加载失败' : 'Could not load the image.';

  // Share
  String get shareLink => zh ? '分享链接' : 'Share link';
  String get createShareLink => zh ? '创建分享链接' : 'Create share link';
  String get existingLinks => zh ? '已有链接' : 'Existing links';
  String get noShareLinks => zh ? '暂无分享链接' : 'No share links';
  String get linkPassword => zh ? '访问密码（可选）' : 'Password (optional)';
  String get expireDays => zh ? '有效期' : 'Expires';
  String get expireNever => zh ? '永久有效' : 'Never';
  String get expireOneDay => zh ? '1 天' : '1 day';
  String get expireSevenDays => zh ? '7 天' : '7 days';
  String get expireThirtyDays => zh ? '30 天' : '30 days';
  String get createLink => zh ? '创建链接' : 'Create link';
  String get copyLink => zh ? '复制链接' : 'Copy link';
  String get linkCopied => zh ? '链接已复制' : 'Link copied';
  String get deleteLink => zh ? '删除链接' : 'Delete link';
  String get deleteLinkConfirm => zh ? '确定删除此分享链接吗？' : 'Delete this share link?';
  String get shareLinkCreated => zh ? '分享链接已创建' : 'Share link created';
  String get sharePasswordWrong => zh ? '密码错误' : 'Wrong password';
  String get linkExpired => zh ? '链接已过期' : 'Expired';
  String get shareLoadFailed => zh ? '加载分享链接失败' : 'Could not load share links.';
  String get shareLinkHint => zh ? '任何获得链接的人都可以访问此内容。' : 'Anyone with the link can access this content.';
  String get allowDownload => zh ? '允许下载' : 'Allow download';
  String get allowUpload => zh ? '允许上传' : 'Allow upload';
  String get allowEdit => zh ? '允许编辑' : 'Allow edit';
  String get passwordProtected => zh ? '密码保护' : 'Password protected';
  String get expiresOn => zh ? '有效期至' : 'Expires';
  String get upOneLevel => zh ? '上一级' : 'Up one level';
  String get cannotMoveIntoItself => zh ? '不能移动到文件夹自身内部' : 'Cannot move a folder into itself';
  String get confirmRestore => zh ? '确定恢复所选项目吗？' : 'Restore the selected items?';
  String get versionDownloaded => zh ? '版本已下载' : 'Version downloaded';
  String get restoring => zh ? '正在恢复…' : 'Restoring…';
  String get currentVersion => zh ? '当前版本' : 'Current version';

  // Trash
  String get trash => zh ? '回收站' : 'Trash';
  String get trashEmpty => zh ? '回收站是空的' : 'Trash is empty';
  String get restore => zh ? '恢复' : 'Restore';
  String get deleteForever => zh ? '彻底删除' : 'Delete permanently';
  String get emptyTrash => zh ? '清空回收站' : 'Empty trash';
  String get emptyTrashConfirm => zh ? '确定清空回收站吗？此操作无法撤销。' : 'Empty the trash? This cannot be undone.';
  String deleteForeverConfirm(String name) => zh ? '确定彻底删除“$name”吗？此操作无法撤销。' : 'Permanently delete “$name”? This cannot be undone.';
  String get deletedAt => zh ? '删除时间' : 'Deleted';
  String get restoreSuccess => zh ? '已恢复' : 'Restored';
  String get deleteSuccess => zh ? '已彻底删除' : 'Deleted permanently';
  String get trashLoadFailed => zh ? '加载回收站失败' : 'Could not load the trash.';
  String get restoreConflict => zh ? '恢复失败：目标位置已存在同名文件' : 'Restore failed: an item with the same name already exists.';
  String get trashHint => zh ? '已删除的文件会保留在这里。' : 'Deleted items are kept here.';
  String get emptyTrashDone => zh ? '回收站已清空' : 'Trash emptied';

  // History
  String get versionHistory => zh ? '历史版本' : 'Version history';
  String get noHistory => zh ? '暂无历史版本' : 'No version history';
  String get author => zh ? '修改者' : 'Author';
  String get description => zh ? '说明' : 'Description';
  String get downloadVersion => zh ? '下载此版本' : 'Download this version';
  String get previewVersion => zh ? '预览此版本' : 'Preview this version';
  String get restoreVersion => zh ? '恢复此版本' : 'Restore this version';
  String get restoreVersionConfirm => zh ? '确定将文件恢复到该版本吗？当前内容会被覆盖。' : 'Restore this version? The current file will be replaced.';
  String get versionRestored => zh ? '已恢复到此版本' : 'Version restored';
  String get historyLoadFailed => zh ? '加载历史版本失败' : 'Could not load version history.';

  // Destination picker
  String get chooseDestination => zh ? '选择目标位置' : 'Choose destination';
  String get destinationLibrary => zh ? '目标资料库' : 'Destination library';
  String get moveHere => zh ? '移动到此处' : 'Move here';
  String get copyHere => zh ? '复制到此处' : 'Copy here';
  String get selectDestination => zh ? '选择文件夹' : 'Select folder';
  String get noWritePermission => zh ? '目标文件夹没有写入权限' : 'You cannot write to the destination.';
  String get noSubfolders => zh ? '没有子文件夹' : 'No subfolders';
  String get currentLocation => zh ? '当前位置' : 'Current location';

  // Transfers
  String get transfers => zh ? '传输' : 'Transfers';
  String get uploading => zh ? '正在上传' : 'Uploading';
  String get downloading => zh ? '正在下载' : 'Downloading';
  String get completed => zh ? '已完成' : 'Completed';
  String get failed => zh ? '失败' : 'Failed';
  String get cancelled => zh ? '已取消' : 'Cancelled';
  String get waiting => zh ? '等待中' : 'Waiting';
  String get cancelTask => zh ? '取消' : 'Cancel';
  String get clearCompleted => zh ? '清除已完成' : 'Clear completed';
  String get uploadComplete => zh ? '上传完成' : 'Upload complete';
  String get downloadComplete => zh ? '下载完成' : 'Download complete';
  String uploadFailed(String name) => zh ? '“$name”上传失败' : 'Failed to upload “$name”.';
  String downloadFailed(String name) => zh ? '“$name”下载失败' : 'Failed to download “$name”.';
  String get conflictTitle => zh ? '文件已存在' : 'File already exists';
  String conflictMessage(String name) => zh ? '“$name”已存在，是否覆盖？' : '“$name” already exists. Replace it?';
  String get replace => zh ? '覆盖' : 'Replace';
  String get skip => zh ? '跳过' : 'Skip';
  String get skipAll => zh ? '全部跳过' : 'Skip all';
  String get replaceAll => zh ? '全部覆盖' : 'Replace all';
  String get applyToAll => zh ? '应用于全部' : 'Apply to all';
  String get uploadSkipped => zh ? '已跳过已存在的文件' : 'Skipped existing files';
  String savedTo(String path) => zh ? '已保存到 $path' : 'Saved to $path';
  String get transferLoadFailed => zh ? '传输失败' : 'Transfer failed';

  // Encrypted libraries
  String get unlockLibrary => zh ? '解锁资料库' : 'Unlock library';
  String unlockLibraryHint(String name) => zh ? '“$name”是加密资料库，请输入密码。' : '“$name” is encrypted. Enter its password.';
  String get libraryPassword => zh ? '资料库密码' : 'Library password';
  String get rememberPassword => zh ? '记住密码' : 'Remember password';
  String get unlock => zh ? '解锁' : 'Unlock';
  String get unlocking => zh ? '正在解锁…' : 'Unlocking…';
  String get wrongLibraryPassword => zh ? '资料库密码错误' : 'Incorrect library password';
  String get libraryLocked => zh ? '资料库已锁定' : 'Library is locked';
  String get encryptedPreviewUnsupported => zh ? '加密资料库中的文件暂不支持内置预览。' : 'Preview is not available for encrypted libraries yet.';
  String get unlockRequired => zh ? '请先解锁资料库' : 'Unlock the library first';
  String get passwordSaved => zh ? '密码已保存' : 'Password saved';

  // Search
  String get globalSearch => zh ? '全局搜索' : 'Search all libraries';
  String get searchPlaceholder => zh ? '输入关键词搜索所有资料库…' : 'Search across all libraries…';
  String get searchNoResults => zh ? '没有找到匹配的文件' : 'No matching files found';
  String get searchFailed => zh ? '搜索失败，服务器可能未启用搜索服务。' : 'Search failed. The server may not have search enabled.';
  String get searching => zh ? '正在搜索…' : 'Searching…';
  String searchResults(int count) => zh ? '$count 个结果' : '$count results';
  String get searchHint => zh ? '服务器启用搜索后才能搜索文件内容。' : 'File search requires a server with search enabled.';
  String get searchInLibrary => zh ? '在资料库中搜索' : 'Search in library';

  // About
  String get aboutSeafile => zh ? '关于 Seafile' : 'About Seafile';
  String get aboutDescription => zh ? '一个使用 Seafile Web API 的桌面客户端，界面参照 Seafile 网页版。' : 'A desktop client built on the Seafile Web API with an interface modelled on the Seafile web app.';
  String get serverVersion => zh ? '服务器版本' : 'Server version';
  String get clientVersion => zh ? '客户端版本' : 'Client version';
  String get licenses => zh ? '开源许可' : 'Open-source licenses';
  String get sessionExpiredTitle => zh ? '会话已过期' : 'Session expired';

  // Misc
  String get copiedToClipboard => zh ? '已复制到剪贴板' : 'Copied to clipboard';
  String get noSelection => zh ? '请先选择文件或文件夹' : 'Select a file or folder first';
  String get selectLibraryFirst => zh ? '请先打开一个资料库' : 'Open a library first';
  String get readOnlyLibraryHint => zh ? '你对这个资料库只有查看权限。' : 'You only have read access to this library.';
  String get keepWindowOpen => zh ? '此操作会关闭当前窗口' : '';
  String get untitled => zh ? '未命名' : 'Untitled';
  String get support => zh ? '支持' : 'Support';
  String get file => zh ? '文件' : 'File';
  String get folder => zh ? '文件夹' : 'Folder';
  String get item => zh ? '项目' : 'Item';
  String get yes => zh ? '是' : 'Yes';
  String get no => zh ? '否' : 'No';
  String get browse => zh ? '浏览' : 'Browse';
  String get apply => zh ? '应用' : 'Apply';
  String get change => zh ? '更改' : 'Change';
  String get done => zh ? '完成' : 'Done';
  String get skipFolder => zh ? '跳过文件夹' : 'Skip folder';
  String get uploadingFolder => zh ? '正在上传文件夹' : 'Uploading folder';
  String completeCount(int completed, int total) => zh ? '$completed / $total' : '$completed of $total';
  String get selectAllHint => zh ? '⌘A 全选' : '⌘A Select all';
  String get refreshHint => zh ? '刷新' : 'Refresh';
}

class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<L10n> load(Locale locale) async => L10n(locale.languageCode == 'zh');

  @override
  bool shouldReload(covariant LocalizationsDelegate<L10n> old) => false;
}
