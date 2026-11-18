import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  bool _sendingForm = false;
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

  // Fundación: envía una copia de su formulario de adopción (HU-G3)
  Future<void> _sendForm() async {
    if (_sendingForm) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar formulario'),
        content: Text('¿Enviar tu formulario de adopción a ${widget.conversation.userName}? Responderá desde su app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sendingForm = true);
    try {
      final message = await _service.sendForm(widget.conversation.id);
      if (!mounted) return;
      setState(() => _messages = mergeMessages(_messages ?? const [], [message]));
      _toBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error, 'No se pudo enviar el formulario. Inténtalo de nuevo.'))),
      );
    } finally {
      if (mounted) setState(() => _sendingForm = false);
    }
  }

  // Adoptante: responde el formulario en otra pantalla y vuelve con el mensaje de respuesta
  Future<void> _answer(AdoptionFormRequest form) async {
    final message = await context.push<ChatMessage>('/mensajes/${widget.conversation.id}/formulario', extra: form);
    if (message == null || !mounted) return;
    setState(() => _messages = mergeMessages(_messages ?? const [], [message]));
    _toBottom();
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
    // El aviso de respuesta llega como un mensaje aparte; el formulario original queda marcado como respondido
    final answered = {
      for (final message in messages ?? const <ChatMessage>[])
        if (message.kind == 'form_answers' && message.form != null) message.form!.id,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isFoundation)
            IconButton(
              tooltip: 'Enviar formulario de adopción',
              onPressed: messages == null || _sendingForm ? null : _sendForm,
              icon: const Icon(Icons.assignment_outlined),
            ),
        ],
      ),
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
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final form = message.form;
                                  final pending = message.kind == 'form' && form != null &&
                                      !form.answered && !answered.contains(form.id);
                                  return _Bubble(
                                    message: message,
                                    pending: pending,
                                    onAnswer: pending && !isFoundation ? () => _answer(form) : null,
                                  );
                                },
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
  const _Bubble({required this.message, this.pending = false, this.onAnswer});

  final ChatMessage message;
  // Formulario enviado que todavía no se responde
  final bool pending;
  final VoidCallback? onAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final mine = message.mine;
    final form = message.form;
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
              if (message.kind == 'form' && form != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AdoptifySpacing.xs),
                    child: Text(
                      '${form.questions.length} ${form.questions.length == 1 ? 'pregunta' : 'preguntas'} · '
                      '${pending ? 'Esperando respuestas' : 'Respondido'}',
                      style: textTheme.labelMedium?.copyWith(color: foreground),
                    ),
                  ),
                ),
              if (onAnswer != null)
                Padding(
                  padding: const EdgeInsets.only(top: AdoptifySpacing.sm),
                  child: FilledButton.icon(
                    onPressed: onAnswer,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Responder formulario'),
                  ),
                ),
              if (message.kind == 'form_answers' && form?.answers != null)
                Container(
                  margin: const EdgeInsets.only(top: AdoptifySpacing.sm),
                  padding: const EdgeInsets.all(AdoptifySpacing.sm),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < form!.questions.length; i++) ...[
                        if (i > 0) const SizedBox(height: AdoptifySpacing.sm),
                        Text(form.questions[i].label, style: textTheme.labelMedium?.copyWith(color: colors.textMuted)),
                        Text(formatAnswer(i < form.answers!.length ? form.answers![i] : null),
                            style: textTheme.bodyMedium?.copyWith(color: colors.text)),
                      ],
                    ],
                  ),
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
