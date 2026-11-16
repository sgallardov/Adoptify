import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'foundation_animals_service.dart';

class ApplicationCandidatesScreen extends StatefulWidget {
  const ApplicationCandidatesScreen({super.key, this.animalId});
  final int? animalId;
  @override State<ApplicationCandidatesScreen> createState() => _ApplicationCandidatesScreenState();
}

class _ApplicationCandidatesScreenState extends State<ApplicationCandidatesScreen> {
  Future<List<FoundationApplication>>? _future;
  @override void didChangeDependencies() { super.didChangeDependencies(); _future ??= _load(); }
  Future<List<FoundationApplication>> _load() async {
    final all = await FoundationAnimalsService(AuthScope.of(context).api).applications();
    return widget.animalId == null ? all : all.where((item) => item.animalId == widget.animalId).toList();
  }
  Future<void> _status(FoundationApplication item, String status) async {
    try {
      await FoundationAnimalsService(AuthScope.of(context).api).updateApplicationStatus(item.id, status);
      if (!mounted) return; setState(() => _future = _load());
      if (status == 'invited_to_chat') context.push('/fundacion/chat?user_id=${item.userId}&animal_id=${item.animalId}');
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(error, 'No pudimos actualizar la postulación.')))); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Postulaciones')), body: ContentWidth(child: FutureBuilder<List<FoundationApplication>>(
    future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: OutlinedButton(onPressed: () => setState(() => _future = _load()), child: const Text('Reintentar')));
      final items = snapshot.data ?? const <FoundationApplication>[];
      if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(AdoptifySpacing.xl), child: MessageBox.error(message: 'Aún no hay postulaciones para este animal. Los likes son solo interés general.')));
      return ListView(padding: const EdgeInsets.all(AdoptifySpacing.lg), children: [
        for (final item in items) Card(child: Padding(padding: const EdgeInsets.all(AdoptifySpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.fullName, style: Theme.of(context).textTheme.titleMedium),
          Text('${item.animalName} · ${item.statusLabel}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AdoptifySpacing.sm),
          Text('Vivienda: ${item.housingType.replaceAll('_', ' ')} · Mascotas: ${item.hasPets} · Experiencia: ${item.experience ?? 'No indicada'}'),
          if (item.message != null) Padding(padding: const EdgeInsets.only(top: AdoptifySpacing.sm), child: Text('“${item.message}”')),
          const SizedBox(height: AdoptifySpacing.md),
          if (item.canAct) Wrap(spacing: AdoptifySpacing.sm, runSpacing: AdoptifySpacing.sm, children: [
            OutlinedButton(onPressed: () => _status(item, 'reviewing'), child: const Text('Revisar')),
            FilledButton.icon(onPressed: () => _status(item, 'invited_to_chat'), icon: const Icon(Icons.chat_outlined), label: const Text('Invitar a conversar')),
          ]),
        ]))),
      ]);
    },
  )));
}
