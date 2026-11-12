import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'foundation_animals_service.dart';

class FoundationAnimalsScreen extends StatefulWidget {
  const FoundationAnimalsScreen({super.key});

  @override
  State<FoundationAnimalsScreen> createState() => _FoundationAnimalsScreenState();
}

class _FoundationAnimalsScreenState extends State<FoundationAnimalsScreen> {
  Future<List<ManagedAnimal>>? _animals;
  String? _updatingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthScope es un InheritedWidget: solo se puede consultar cuando el contexto ya está listo.
    _animals ??= _load();
  }

  Future<List<ManagedAnimal>> _load() => FoundationAnimalsService(AuthScope.of(context).api).list();

  void _reload() => setState(() => _animals = _load());

  Future<void> _changeStatus(ManagedAnimal animal) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AdoptifySpacing.xl, 0, AdoptifySpacing.xl, AdoptifySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado de ${animal.name}', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AdoptifySpacing.sm),
              for (final entry in animalStatusLabels.entries)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: entry.key,
                  groupValue: animal.status,
                  title: Text(entry.value),
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (status == null || status == animal.status || !mounted) return;
    setState(() => _updatingId = '${animal.id}');
    try {
      await FoundationAnimalsService(AuthScope.of(context).api).updateStatus(animal.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado correctamente.')));
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error, 'No pudimos actualizar el estado. Inténtalo nuevamente.'))),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis animales')),
        body: ContentWidth(
          child: FutureBuilder<List<ManagedAnimal>>(
            future: _animals,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(AdoptifySpacing.xl),
                  children: [
                    MessageBox.error(message: errorMessage(snapshot.error!, 'No pudimos cargar tus animales.')),
                    const SizedBox(height: AdoptifySpacing.md),
                    OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                  ],
                );
              }
              final animals = snapshot.data ?? const <ManagedAnimal>[];
              if (animals.isEmpty) return _EmptyAnimals(onPublish: () => context.push('/fundacion/agregar'));
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.all(AdoptifySpacing.xl),
                  children: [
                    Text('Tus animales publicados', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AdoptifySpacing.xs),
                    Text('${animals.length} caso${animals.length == 1 ? '' : 's'} en gestión.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AdoptifySpacing.lg),
                    for (final animal in animals) ...[
                      _AnimalCard(
                        animal: animal,
                        updating: _updatingId == '${animal.id}',
                        onEdit: () => context.push('/fundacion/mis-animales/${animal.id}/editar', extra: animal),
                        onStatus: () => _changeStatus(animal),
                      ),
                      const SizedBox(height: AdoptifySpacing.md),
                    ],
                    const SizedBox(height: AdoptifySpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/fundacion/agregar'),
                      icon: const Icon(Icons.add),
                      label: const Text('Publicar otro animal'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class _EmptyAnimals extends StatelessWidget {
  const _EmptyAnimals({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AdoptifySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets_outlined, size: 48, color: context.colors.primaryDark),
              const SizedBox(height: AdoptifySpacing.md),
              Text('Aún no tienes animales publicados', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AdoptifySpacing.xs),
              Text('Cuando tengas un caso listo, publícalo para comenzar a encontrarle un hogar.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AdoptifySpacing.lg),
              FilledButton.icon(onPressed: onPublish, icon: const Icon(Icons.add), label: const Text('Publicar animal')),
            ],
          ),
        ),
      );
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.animal, required this.updating, required this.onEdit, required this.onStatus});

  final ManagedAnimal animal;
  final bool updating;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              height: 168,
              child: animal.photoUrl == null
                  ? ColoredBox(color: context.colors.primarySoft, child: Icon(Icons.pets, color: context.colors.primaryDark))
                  : Image.network(animal.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: context.colors.primarySoft, child: Icon(Icons.pets, color: context.colors.primaryDark))),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AdoptifySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AdoptifySpacing.xs),
                    Text(animal.summary, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AdoptifySpacing.sm),
                    _StatusChip(label: animal.statusLabel),
                    const SizedBox(height: AdoptifySpacing.md),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: updating ? null : onEdit, child: const Text('Editar'))),
                        const SizedBox(width: AdoptifySpacing.sm),
                        Expanded(child: FilledButton(onPressed: updating ? null : onStatus, child: Text(updating ? 'Guardando…' : 'Estado'))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: context.colors.primarySoft, borderRadius: BorderRadius.circular(99)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.sm, vertical: AdoptifySpacing.xs),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.primaryTextDark)),
        ),
      );
}
