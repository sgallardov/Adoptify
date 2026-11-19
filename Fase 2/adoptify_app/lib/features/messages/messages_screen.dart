import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'messages_service.dart';

// Pestaña "Mensajes" del adoptante (HU-G2): conversaciones que le abrieron las fundaciones.
// La fundación la ve como su pestaña "Chat", con sus interesados y postulados.
// Se actualiza sola cada 15 s mientras la pestaña está a la vista.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.openWithUserId, this.openWithAnimalId});

  // Fundación: al entrar abre (o recupera) el chat con esta persona, desde "Conversar"
  final int? openWithUserId;
  // Mascota por la que se conversa: empieza el cuestionario de adopción (HU-G3)
  final int? openWithAnimalId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation>? _items;
  String? _error;
  bool _started = false;
  Timer? _timer;

  MessagesService get _service => MessagesService(AuthScope.of(context).api);
  bool get _isFoundation => AuthScope.of(context).user?.isFoundation ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _timer = Timer.periodic(conversationsPollInterval, (_) => _poll());
    _openWith(widget.openWithUserId, widget.openWithAnimalId);
  }

  @override
  void didUpdateWidget(MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openWithUserId != oldWidget.openWithUserId || widget.openWithAnimalId != oldWidget.openWithAnimalId) {
      _openWith(widget.openWithUserId, widget.openWithAnimalId);
    }
  }

  Future<void> _openWith(int? userId, int? animalId) async {
    if (userId == null) return;
    try {
      final conversation = await _service.open(userId, animalId: animalId);
      if (mounted) await _open(conversation);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error, 'No se pudo abrir la conversación.'))),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _service.fetchConversations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error, 'No pudimos cargar tus mensajes.'));
    }
  }

  // Otra pestaña a la vista: no se consulta. Un fallo del sondeo no borra lo que ya se ve.
  Future<void> _poll() async {
    if (!mounted || !TickerMode.valuesOf(context).enabled || _items == null) return;
    try {
      final items = await _service.fetchConversations();
      if (mounted) setState(() => _items = items);
    } catch (_) {}
  }

  Future<void> _open(Conversation conversation) async {
    await context.push('${_isFoundation ? '/fundacion' : ''}/mensajes/${conversation.id}', extra: conversation);
    // Al volver, la lista muestra al tiro lo que se respondió
    if (mounted) _poll();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final isFoundation = _isFoundation;
    return Scaffold(
      appBar: AppBar(title: Text(isFoundation ? 'Chat' : 'Mensajes')),
      body: _error != null && items == null
          ? ListView(children: [
              ComingSoon(icon: Icons.cloud_off, title: 'No pudimos cargar', message: _error!),
              Center(child: TextButton(onPressed: () {
                setState(() => _error = null);
                _load();
              }, child: const Text('Reintentar'))),
            ])
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [
                          ComingSoon(
                            icon: Icons.chat_bubble_outline,
                            title: isFoundation ? 'Aún no tienes conversaciones' : 'Aún no tienes mensajes',
                            message: isFoundation
                                ? 'Abre una desde los interesados de tus animales o desde las postulaciones, '
                                    'con el botón Conversar.'
                                : 'Cuando una fundación quiera conversar contigo sobre una mascota o un hogar '
                                    'temporal, la conversación aparecerá aquí.',
                          ),
                        ])
                      : ContentWidth(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AdoptifySpacing.lg),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AdoptifySpacing.md),
                            itemBuilder: (context, index) =>
                                _ConversationTile(
                                  conversation: items[index],
                                  isFoundation: isFoundation,
                                  onTap: () => _open(items[index]),
                                ),
                          ),
                        ),
                ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.isFoundation, required this.onTap});

  final Conversation conversation;
  // La fundación ve el nombre de la persona; el adoptante, el de la fundación
  final bool isFoundation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final last = conversation.lastMessage;
    final preview = last == null ? 'Sin mensajes todavía' : '${last.fromFoundation == isFoundation ? 'Tú: ' : ''}${last.body}';
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AdoptifySpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primarySoft,
                child: Icon(isFoundation ? Icons.person_outline : Icons.volunteer_activism, color: colors.primaryText),
              ),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isFoundation ? conversation.userName : conversation.foundationName, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(preview, style: textTheme.bodySmall?.copyWith(color: colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AdoptifySpacing.sm),
              Text(shortTime(conversation.lastActivity), style: textTheme.labelSmall?.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
