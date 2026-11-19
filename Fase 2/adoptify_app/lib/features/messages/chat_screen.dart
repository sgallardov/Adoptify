import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'messages_service.dart';

// Chat con una fundación (o, desde la vista de fundación, con un adoptante). Pantalla completa.
// Pide solo los mensajes nuevos cada 10 s, así lo que escribe el otro lado aparece sin recargar.
// Cuestionario de adopción (HU-G3): si la fundación apretó "Conversar", el chat le hace sus preguntas
// al adoptante una a una; se responden aquí mismo con botones (sí/no, alternativas) o escribiendo.
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
    await _submit(
      () async => [await _service.send(widget.conversation.id, body)],
      'No se pudo enviar el mensaje. Inténtalo de nuevo.',
    );
  }

  // Respuesta a la pregunta pendiente: llega junto con la siguiente pregunta (o el cierre)
  Future<void> _answer(QuestionInfo question, Object? value) => _submit(
    () => _service.answer(widget.conversation.id, question.formId, value),
    'No se pudo enviar tu respuesta. Inténtalo de nuevo.',
  );

  Future<void> _submit(Future<List<ChatMessage>> Function() request, String fallback) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final incoming = await request();
      if (!mounted) return;
      _draft.clear();
      setState(() => _messages = mergeMessages(_messages ?? const [], incoming));
      _toBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(error, fallback))));
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
    // Solo el adoptante responde; la fundación ve las preguntas y respuestas como mensajes
    final pending = isFoundation || messages == null ? null : pendingQuestion(messages)?.question;
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
              if (pending != null && pending.kind != 'text')
                _AnswerOptions(question: pending, sending: _sending, onAnswer: (value) => _answer(pending, value))
              else
                _Composer(
                  controller: _draft,
                  sending: _sending,
                  enabled: messages != null,
                  // Pregunta abierta pendiente: lo que se escribe es la respuesta
                  hint: pending == null ? 'Escribe un mensaje…' : 'Escribe tu respuesta…',
                  onSend: pending == null ? _send : () => _answer(pending, _draft.text.trim()),
                  onSkip: pending != null && !pending.required ? () => _answer(pending, null) : null,
                ),
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
    final question = message.question;
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
              if (question != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AdoptifySpacing.xs),
                    child: Text(
                      'Pregunta ${question.index + 1} de ${question.total}',
                      style: textTheme.labelMedium?.copyWith(color: colors.primaryText),
                    ),
                  ),
                ),
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

// Botones de respuesta para una pregunta de sí o no o de alternativas (en lugar del campo de texto)
class _AnswerOptions extends StatelessWidget {
  const _AnswerOptions({required this.question, required this.sending, required this.onAnswer});

  final QuestionInfo question;
  final bool sending;
  final ValueChanged<Object?> onAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final choices = question.kind == 'yes_no'
        ? const <(String, Object)>[('Sí', true), ('No', false)]
        : [for (final option in question.options) (option, option as Object)];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elige tu respuesta · Pregunta ${question.index + 1} de ${question.total}',
            style: textTheme.labelLarge?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AdoptifySpacing.sm),
          if (question.kind == 'yes_no')
            Row(
              children: [
                for (final (index, (label, value)) in choices.indexed) ...[
                  if (index > 0) const SizedBox(width: AdoptifySpacing.sm),
                  Expanded(
                    child: OutlinedButton(onPressed: sending ? null : () => onAnswer(value), child: Text(label)),
                  ),
                ],
              ],
            )
          else
            for (final (index, (label, value)) in choices.indexed) ...[
              if (index > 0) const SizedBox(height: AdoptifySpacing.sm),
              OutlinedButton(onPressed: sending ? null : () => onAnswer(value), child: Text(label, textAlign: TextAlign.center)),
            ],
          if (!question.required)
            TextButton(onPressed: sending ? null : () => onAnswer(null), child: const Text('Prefiero no responder')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.hint,
    required this.onSend,
    this.onSkip,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;
  // Pregunta abierta opcional: se puede saltar
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.sm, AdoptifySpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  decoration: InputDecoration(hintText: hint, counterText: ''),
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
          if (onSkip != null)
            TextButton(onPressed: sending ? null : onSkip, child: const Text('Prefiero no responder')),
        ],
      ),
    );
  }
}
