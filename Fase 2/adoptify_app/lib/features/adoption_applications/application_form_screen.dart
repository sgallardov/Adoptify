import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../account/adoption_service.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';
import 'adoption_applications_service.dart';

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _message = TextEditingController();
  AdoptionProfile? _profile;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    try { _profile = await AdoptionService(AuthScope.of(context).api).fetch(); }
    catch (_) { _error = 'No pudimos cargar tu ficha de adopción.'; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final profile = _profile;
    if (profile == null || _sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      await AdoptionApplicationsService(AuthScope.of(context).api).apply(animalId: widget.animal.id, profile: profile, message: _message.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Postulación enviada a la fundación.')));
      context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error, 'No pudimos enviar tu postulación.'));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  void dispose() { _message.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Postular a adoptar')),
    body: ContentWidth(child: ListView(padding: const EdgeInsets.all(AdoptifySpacing.lg), children: [
      Text('Postulación para ${widget.animal.name}', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AdoptifySpacing.sm),
      const Text('Tu ficha solo se comparte con esta fundación al enviar la postulación. Un favorito no crea contacto.'),
      const SizedBox(height: AdoptifySpacing.lg),
      if (_loading) const Center(child: CircularProgressIndicator())
      else if (_error != null) MessageBox.error(message: _error!)
      else if (_profile == null) ...[
        const MessageBox.error(message: 'Completa primero “Quiero adoptar” en tu perfil. Así la fundación podrá evaluar tu postulación.'),
        const SizedBox(height: AdoptifySpacing.md),
        FilledButton(onPressed: () => context.go('/cuenta'), child: const Text('Completar mi ficha')),
      ] else ...[
        _ProfileSummary(profile: _profile!),
        const SizedBox(height: AdoptifySpacing.lg),
        TextField(controller: _message, minLines: 3, maxLines: 6, maxLength: 1000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Mensaje para la fundación (opcional)', hintText: 'Cuéntales por qué quieres adoptar a este animal.')),
        const SizedBox(height: AdoptifySpacing.md),
        FilledButton.icon(onPressed: _sending ? null : _submit, icon: const Icon(Icons.send_outlined), label: Text(_sending ? 'Enviando…' : 'Enviar postulación')),
      ],
    ])),
  );
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final AdoptionProfile profile;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: context.colors.primarySoft, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
    child: Padding(padding: const EdgeInsets.all(AdoptifySpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tu ficha reutilizable', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AdoptifySpacing.xs),
      Text('Vivienda: ${profile.housingType.replaceAll('_', ' ')} · Mascotas: ${profile.hasPets == 'si' ? 'Sí' : 'No'}'),
      Text('Experiencia: ${profile.experience ?? 'No indicada'} · Disponibilidad: ${profile.hoursAlone.replaceAll('_', '–')} horas'),
      TextButton(onPressed: () => context.go('/cuenta'), child: const Text('Editar mi ficha')),
    ])),
  );
}
