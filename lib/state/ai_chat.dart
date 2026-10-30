import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_error.dart';
import '../api/json_utils.dart';
import '../api/models.dart';
import 'session.dart';

class ChatEntry {
  ChatEntry({required this.role, this.content = '', this.isStreaming = false, this.status});

  final String role;
  String content;
  bool isStreaming;
  String? status;

  bool get isUser => role == 'user';
}

class AiChatController extends ChangeNotifier {
  AiChatController(this._session, this.repoId);

  final AppSession _session;
  final String repoId;
  final List<ChatEntry> messages = [];
  List<AiChatSession> sessions = const [];
  String? currentSessionId;
  String? currentSessionName;
  String? statusText;
  String? error;
  bool sending = false;
  bool loadingSessions = false;
  bool loadingMessages = false;
  CancelToken? _cancelToken;
  Timer? _notifyTimer;
  bool _disposed = false;

  Future<void> loadSessions() async {
    final api = _session.api;
    if (api == null) return;
    loadingSessions = true;
    _scheduleNotify();
    try {
      sessions = await api.listChatSessions(repoId);
      error = null;
    } catch (error) {
      this.error = _friendly(error);
    } finally {
      loadingSessions = false;
      _scheduleNotify();
    }
  }

  Future<void> selectSession(AiChatSession session) async {
    final api = _session.api;
    if (api == null) return;
    currentSessionId = session.id;
    currentSessionName = session.name;
    messages.clear();
    loadingMessages = true;
    error = null;
    _scheduleNotify();
    try {
      final raw = await api.chatMessages(session.id);
      for (final item in raw) {
        final role = firstString(item, ['role']) ?? 'assistant';
        final content = firstString(item, ['content']) ?? '';
        if (content.isEmpty) continue;
        messages.add(ChatEntry(role: role, content: content));
      }
    } catch (error) {
      this.error = _friendly(error);
    } finally {
      loadingMessages = false;
      _scheduleNotify();
    }
  }

  void newChat() {
    _cancelToken?.cancel();
    _cancelToken = null;
    currentSessionId = null;
    currentSessionName = null;
    messages.clear();
    statusText = null;
    error = null;
    sending = false;
    _scheduleNotify();
  }

  Future<void> send(String text, {List<Map<String, dynamic>> attachments = const []}) async {
    final api = _session.api;
    final trimmed = text.trim();
    if (api == null || trimmed.isEmpty || sending) return;
    error = null;
    messages.add(ChatEntry(role: 'user', content: trimmed));
    final assistant = ChatEntry(role: 'assistant', content: '', isStreaming: true);
    messages.add(assistant);
    sending = true;
    statusText = null;
    _scheduleNotify();

    try {
      if (currentSessionId == null) {
        final name = trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
        final created = await api.createChatSession(repoId, name);
        currentSessionId = created.id;
        currentSessionName = created.name;
      }
      _cancelToken = CancelToken();
      final stream = api.sendChat(
        repoId: repoId,
        query: trimmed,
        sessionId: currentSessionId!,
        attachments: attachments,
        cancelToken: _cancelToken,
      );
      await for (final event in stream) {
        if (event.done) break;
        if (event.status != null && event.status!.isNotEmpty) {
          statusText = event.status;
          assistant.status = event.status;
          _scheduleNotify();
        }
        if (event.answer != null && event.answer!.isNotEmpty) {
          if (assistant.content.isEmpty) assistant.status = null;
          assistant.content += event.answer!;
          _scheduleNotify();
        }
        final raw = event.raw;
        if (raw != null && raw['results'] is Map) {
          final results = asMap(raw['results']);
          final reply = firstString(results, ['ai_reply', 'answer']);
          if (reply != null && reply.isNotEmpty && assistant.content.trim().isEmpty) {
            assistant.content = reply;
          }
        }
      }
    } on ApiException catch (error) {
      this.error = error.serverMessage?.isNotEmpty == true ? error.serverMessage : 'AI request failed';
      if (assistant.content.isEmpty) {
        messages.remove(assistant);
      }
    } catch (error) {
      this.error = _friendly(error);
      if (assistant.content.isEmpty) messages.remove(assistant);
    } finally {
      assistant.isStreaming = false;
      assistant.status = null;
      statusText = null;
      sending = false;
      _cancelToken = null;
      _scheduleNotify();
      unawaited(loadSessions());
    }
  }

  void stop() {
    _cancelToken?.cancel();
    _cancelToken = null;
    sending = false;
    for (final message in messages) {
      message.isStreaming = false;
    }
    _scheduleNotify();
  }

  String _friendly(Object error) {
    if (error is ApiException) return error.serverMessage ?? error.kind.name;
    return error.toString();
  }

  void _scheduleNotify() {
    if (_disposed) return;
    if (_notifyTimer?.isActive == true) return;
    _notifyTimer = Timer(const Duration(milliseconds: 60), () {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
