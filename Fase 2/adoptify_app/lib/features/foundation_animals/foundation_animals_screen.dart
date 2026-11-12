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
  Future<_AnimalsOverview>? _animals;
  String? _updatingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthScope es un InheritedWidget: solo se puede consultar cuando el contexto ya está listo.
    _animals ??= _load();
  }

  Future<_AnimalsOverview> _load() async {
    final service = FoundationAnimalsService(AuthScope.of(context).api);
    final animals = await service.list();
    final interested = await service.interested();
    return _AnimalsOverview(animals: animals, interested: interested);
  }

  Future<void> _reload() async {
    setState(() => _animals = _load());
    await _animals;
  }

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
          child: FutureBuilder<_AnimalsOverview>(
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
              final overview = snapshot.data;
              final animals = overview?.animals ?? const <ManagedAnimal>[];
              if (animals.isEmpty) return _EmptyAnimals(onPublish: () => context.push('/fundacion/agregar'));
              return RefreshIndicator(
                onRefresh: _reload,
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
                        interestCount: overview?.interestCount(animal.id) ?? 0,
                        onInterested: () => context.push('/fundacion/interesados?animal_id=${animal.id}'),
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
  const _AnimalCard({
    required this.animal,
    required this.updating,
    required this.onEdit,
    required this.onStatus,
    required this.interestCount,
    required this.onInterested,
  });

  final ManagedAnimal animal;
  final bool updating;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final int interestCount;
  final VoidCallback onInterested;

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
                    const SizedBox(height: AdoptifySpacing.xs),
                    TextButton.icon(
                      onPressed: onInterested,
                      icon: const Icon(Icons.favorite_outline, size: 18),
                      label: Text(interestCount == 0 ? 'Aún sin interesados' : '$interestCount interesado${interestCount == 1 ? '' : 's'}'),
                    ),
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

class _AnimalsOverview {
  const _AnimalsOverview({required this.animals, required this.interested});

  final List<ManagedAnimal> animals;
  final List<AnimalInterested> interested;

  int interestCount(int animalId) {
    for (final group in interested) {
      if (group.animalId == animalId) return group.interested.length;
    }
    return 0;
  }
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
