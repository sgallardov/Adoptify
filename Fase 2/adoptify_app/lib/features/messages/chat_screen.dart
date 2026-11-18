import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'messages_service.dart';

// Chat con una fundación (o, desde la vista de fundación, con un adoptante). Pantalla completa.
// Pide solo los mensajes nuevos cada 10 s, así lo que escribe el otro lado aparece sin recargar.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage>? _messages;
  String? _error;
  bool _sending = false;
  bool _started = false;
  Timer? _timer;

  MessagesService get _service => MessagesService(AuthScope.of(context).api);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _timer = Timer.periodic(messagesPollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await _service.fetchMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
      _toBottom();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error, 'No pudimos cargar los mensajes.'));
    }
  }

  Future<void> _poll() async {
    final current = _messages;
    if (!mounted || current == null) return;
    try {
      final incoming = await _service.fetchMessages(
        widget.conversation.id,
        afterId: current.isEmpty ? 0 : current.last.id,
      );
      if (!mounted || incoming.isEmpty) return;
      setState(() => _messages = mergeMessages(_messages ?? const [], incoming));
      _toBottom();
    } catch (_) {
      // Se reintenta en la próxima vuelta sin borrar lo que ya se ve
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await _service.send(widget.conversation.id, body);
      if (!mounted) return;
      _draft.clear();
      setState(() => _messages = mergeMessages(_messages ?? const [], [message]));
      _toBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error, 'No se pudo enviar el mensaje. Inténtalo de nuevo.'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFoundation = AuthScope.of(context).user?.isFoundation ?? false;
    final title = isFoundation ? widget.conversation.userName : widget.conversation.foundationName;
    final messages = _messages;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              Expanded(
                child: _error != null && messages == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(onPressed: () {
                              setState(() => _error = null);
                              _load();
                            }, child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : messages == null
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AdoptifySpacing.xl),
                                  child: Text(
                                    'Todavía no hay mensajes. Escribe el primero.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: _scroll,
                                padding: const EdgeInsets.all(AdoptifySpacing.lg),
                                itemCount: messages.length,
                                separatorBuilder: (_, _) => const SizedBox(height: AdoptifySpacing.sm),
                                itemBuilder: (context, index) => _Bubble(message: messages[index]),
                              ),
              ),
              _Composer(controller: _draft, sending: _sending, enabled: messages != null, onSend: _send),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final mine = message.mine;
    final foreground = mine ? colors.onAccent : colors.text;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.sm),
          decoration: BoxDecoration(
            color: mine ? colors.primaryStrong : colors.muted,
            borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(message.body, style: textTheme.bodyMedium?.copyWith(color: foreground)),
              ),
              const SizedBox(height: AdoptifySpacing.xs),
              Text(shortTime(message.createdAt), style: textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.75))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.sm, AdoptifySpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Escribe un mensaje…', counterText: ''),
            ),
          ),
          const SizedBox(width: AdoptifySpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => IconButton.filled(
              tooltip: 'Enviar mensaje',
              onPressed: enabled && !sending && value.text.trim().isNotEmpty ? onSend : null,
              icon: sending
                  ? const SizedBox.square(dimension: AdoptifySpacing.lg + AdoptifySpacing.xs, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }
}
