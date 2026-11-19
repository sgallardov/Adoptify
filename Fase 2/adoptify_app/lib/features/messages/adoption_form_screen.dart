import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'messages_service.dart';

const _maxAnswerLength = 1000;

// El adoptante responde el formulario que le envió la fundación por el chat (HU-G3).
// Se responde una sola vez: al enviar vuelve al chat con el mensaje de respuesta.
class AdoptionFormScreen extends StatefulWidget {
  const AdoptionFormScreen({super.key, required this.conversationId, required this.form});

  final int conversationId;
  final AdoptionFormRequest form;

  @override
  State<AdoptionFormScreen> createState() => _AdoptionFormScreenState();
}

class _AdoptionFormScreenState extends State<AdoptionFormScreen> {
  late final List<Object?> _answers = List.filled(widget.form.questions.length, null);
  late final List<TextEditingController> _texts = [
    for (final _ in widget.form.questions) TextEditingController(),
  ];
  final Set<int> _missing = {};
  bool _sending = false;

  @override
  void dispose() {
    for (final controller in _texts) {
      controller.dispose();
    }
    super.dispose();
  }

  Object? _answerAt(int index) {
    if (widget.form.questions[index].kind != 'text') return _answers[index];
    final text = _texts[index].text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (_sending) return;
    final answers = [for (var i = 0; i < widget.form.questions.length; i++) _answerAt(i)];
    final missing = {
      for (var i = 0; i < answers.length; i++)
        if (widget.form.questions[i].required && answers[i] == null) i,
    };
    setState(() {
      _missing
        ..clear()
        ..addAll(missing);
    });
    if (missing.isNotEmpty) return;
    setState(() => _sending = true);
    try {
      final message = await MessagesService(AuthScope.of(context).api)
          .answerForm(widget.conversationId, widget.form.id, answers);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuestas enviadas a la fundación.')));
      context.pop(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error, 'No se pudieron enviar tus respuestas. Inténtalo de nuevo.'))),
      );
    }
  }

  void _choose(int index, Object? value) => setState(() {
    _answers[index] = _answers[index] == value ? null : value;
    _missing.remove(index);
  });

  Widget _input(int index, FormQuestion question) {
    if (question.kind == 'text') {
      return TextField(
        controller: _texts[index],
        minLines: 2,
        maxLines: 5,
        maxLength: _maxAnswerLength,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_missing.remove(index)) setState(() {});
        },
        decoration: const InputDecoration(hintText: 'Escribe tu respuesta'),
      );
    }
    final choices = question.kind == 'yes_no'
        ? const <(Object, String)>[(true, 'Sí'), (false, 'No')]
        : [for (final option in question.options) (option as Object, option)];
    return Wrap(
      spacing: AdoptifySpacing.sm,
      runSpacing: AdoptifySpacing.sm,
      children: [
        for (final (value, label) in choices)
          ChoiceChip(label: Text(label), selected: _answers[index] == value, onSelected: (_) => _choose(index, value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final questions = widget.form.questions;
    return Scaffold(
      appBar: AppBar(title: const Text('Formulario de adopción')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AdoptifySpacing.lg),
          children: [
            Text(
              'La fundación quiere conocerte. Las preguntas con * son obligatorias y, una vez enviadas, '
              'tus respuestas no se pueden cambiar.',
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
            for (var i = 0; i < questions.length; i++) ...[
              const SizedBox(height: AdoptifySpacing.xl),
              Text('${questions[i].label}${questions[i].required ? ' *' : ''}', style: textTheme.titleSmall),
              const SizedBox(height: AdoptifySpacing.sm),
              _input(i, questions[i]),
              if (_missing.contains(i))
                Padding(
                  padding: const EdgeInsets.only(top: AdoptifySpacing.xs),
                  child: Text('Responde esta pregunta.', style: textTheme.bodySmall?.copyWith(color: colors.reportText)),
                ),
            ],
            const SizedBox(height: AdoptifySpacing.xl),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Enviando…' : 'Enviar respuestas'),
            ),
          ],
        ),
      ),
    );
  }
}
