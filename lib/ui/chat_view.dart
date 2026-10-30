import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../state/ai_chat.dart';
import '../state/workspace.dart';
import 'widgets.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  AiChatController? _chat;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  void _bind() {
    final chat = context.read<WorkspaceController>().chat;
    if (chat == _chat) return;
    _chat?.removeListener(_onChatChanged);
    _chat = chat;
    _chat?.addListener(_onChatChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onChatChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels < 260 || position.maxScrollExtent <= 1) {
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _chat?.removeListener(_onChatChanged);
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final chat = _chat;
    if (chat == null) return;
    final value = (text ?? _inputController.text).trim();
    if (value.isEmpty) return;
    _inputController.clear();
    await chat.send(value);
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final workspace = context.watch<WorkspaceController>();
    final chat = workspace.chat;
    _bind();
    if (chat == null) {
      return EmptyState(
        title: l10n.chatWithAi,
        message: l10n.aiThinking,
        icon: 'new-chat',
      );
    }
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildChatHeader(context, workspace, chat, l10n),
          Expanded(
            child: chat.messages.isEmpty && !chat.loadingMessages
                ? _buildEmpty(context, l10n)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    itemCount: chat.messages.length + (chat.error != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return _errorBubble(chat.error!);
                      }
                      final message = chat.messages[index];
                      return _messageBubble(context, message);
                    },
                  ),
          ),
          _buildComposer(context, l10n, chat),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, WorkspaceController workspace, AiChatController chat, L10n l10n) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          const WebIcon('ai', size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(
            chat.currentSessionName?.isNotEmpty == true ? chat.currentSessionName! : l10n.newChat,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          IconAction(
            icon: 'new-chat',
            tooltip: l10n.newChat,
            size: 16,
            onPressed: () {
              chat.newChat();
              _inputController.clear();
              _inputFocus.requestFocus();
            },
          ),
          const SizedBox(width: 2),
          PopupMenuButton<AiChatSession>(
            tooltip: l10n.chatHistory,
            offset: const Offset(0, 34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            itemBuilder: (context) => [
              if (chat.sessions.isEmpty)
                PopupMenuItem(enabled: false, child: Text(l10n.noChats, style: const TextStyle(fontSize: 13))),
              for (final session in chat.sessions)
                PopupMenuItem(
                  value: session,
                  child: SizedBox(
                    width: 280,
                    child: Text(
                      session.name.isEmpty ? session.id : session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
            onSelected: (session) => chat.selectSession(session),
            color: Colors.white,
            child: HoverBuilder(
              builder: (context, hovered) => Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: hovered ? AppColors.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const WebIcon('history', size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, L10n l10n) {
    final suggestions = l10n.zh
        ? ['这个资料库里有哪些文件？', '总结一下最近的文档', '帮我找设计规范']
        : ['What files are in this library?', 'Summarize the recent documents', 'Find the design guidelines'];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: const WebIcon('ai', size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.zh ? '与资料库对话' : 'Chat with your library',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.zh ? 'AI 会检索资料库中的文件并回答你的问题。' : 'The AI searches your library and answers your questions.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final suggestion in suggestions)
                  InkWell(
                    onTap: () => _send(suggestion),
                    borderRadius: BorderRadius.circular(18),
                    hoverColor: AppColors.hover,
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                      ),
                      child: Text(suggestion, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(BuildContext context, ChatEntry message) {
    final isUser = message.isUser;
    final content = isUser ? message.content : _cleanAnswer(message.content);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: isUser
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: SelectableText(message.content, style: const TextStyle(fontSize: 14, height: 1.6)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const WebIcon('ai', size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('Seafile AI', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (message.isStreaming) ...[
                          const SizedBox(width: 8),
                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.4)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (message.status != null && message.content.isEmpty)
                      Text(message.status!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    if (content.isNotEmpty)
                      MarkdownBody(
                        data: content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 14, height: 1.7, color: AppColors.text),
                          h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          h2: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          code: const TextStyle(fontSize: 12.5, fontFamily: 'Menlo', backgroundColor: AppColors.hover),
                          codeblockDecoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(4)),
                          listBullet: const TextStyle(fontSize: 14, height: 1.7),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _errorBubble(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          const WebIcon('exclamation-circle', size: 15, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 12.5, color: AppColors.danger))),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context, L10n l10n, AiChatController chat) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderStrong),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l10n.chatPlaceholder,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: chat.sending
                      ? FilledButton(
                          onPressed: chat.stop,
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                          child: const Icon(Icons.stop_rounded, size: 17),
                        )
                      : FilledButton(
                          onPressed: () => _send(),
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
                          child: const WebIcon('btn-send', size: 17, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cleanAnswer(String value) {
    return value.replaceAllMapped(
      RegExp(r'<seafile-ai-file>(.*?)</seafile-ai-file>', dotAll: true),
      (match) => '`${match.group(1)}`',
    );
  }
}
