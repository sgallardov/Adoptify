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
  // Copia editable de la lista cargada: al cambiar un estado la tarjeta salta de pestaña sin recargar (HU-Y)
  List<ManagedAnimal>? _items;
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
    _items = animals;
    return _AnimalsOverview(animals: animals, interested: interested);
  }

  Future<void> _reload() async {
    setState(() {
      _items = null;
      _animals = _load();
    });
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
              for (final status in animalStatusOptions(animal.status))
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: status,
                  groupValue: animal.status,
                  title: Text(animalStatusLabels[status] ?? status),
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                ),
              if (animal.status != 'adopted' && animal.status != 'follow_up')
                Padding(
                  padding: const EdgeInsets.only(top: AdoptifySpacing.xs),
                  child: Text(
                    'Seguimiento se activa cuando el animal ya está adoptado.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${animal.name} ahora está en ${animalStatusLabels[status] ?? status}.')),
      );
      // La tarjeta se mueve de pestaña al instante, sin volver a pedir la lista
      setState(() => _items = [
            for (final item in _items ?? const <ManagedAnimal>[])
              if (item.id == animal.id) item.copyWith(status: status) else item,
          ]);
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
  Widget build(BuildContext context) => DefaultTabController(
        length: animalStatusTabs.length,
        child: Scaffold(
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
                final animals = _items ?? overview?.animals ?? const <ManagedAnimal>[];
                if (animals.isEmpty) return _EmptyAnimals(onPublish: () => context.push('/fundacion/agregar'));
                // Cada animal aparece en una sola pestaña: la de su estado actual (HU-Y)
                final byStatus = <String, List<ManagedAnimal>>{
                  for (final status in animalStatusTabs)
                    status: [for (final animal in animals) if (animal.status == status) animal],
                };
                return Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        for (final status in animalStatusTabs)
                          Tab(
                            key: ValueKey('tab-$status'),
                            text: '${animalStatusTabLabels[status]} (${byStatus[status]!.length})',
                          ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final status in animalStatusTabs)
                            _StatusTab(
                              status: status,
                              animals: byStatus[status]!,
                              overview: overview,
                              updatingId: _updatingId,
                              onReload: _reload,
                              onEdit: (animal) => context.push('/fundacion/mis-animales/${animal.id}/editar', extra: animal),
                              onStatus: _changeStatus,
                              onInterested: (animal) => context.push('/fundacion/interesados?animal_id=${animal.id}'),
                              onApplications: (animal) => context.push('/fundacion/postulaciones?animal_id=${animal.id}'),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

/// Contenido de una pestaña: los animales de ese estado o el mensaje de la pestaña vacía.
class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.status,
    required this.animals,
    required this.overview,
    required this.updatingId,
    required this.onReload,
    required this.onEdit,
    required this.onStatus,
    required this.onInterested,
    required this.onApplications,
  });

  final String status;
  final List<ManagedAnimal> animals;
  final _AnimalsOverview? overview;
  final String? updatingId;
  final Future<void> Function() onReload;
  final void Function(ManagedAnimal) onEdit;
  final void Function(ManagedAnimal) onStatus;
  final void Function(ManagedAnimal) onInterested;
  final void Function(ManagedAnimal) onApplications;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onReload,
        child: ListView(
          padding: const EdgeInsets.all(AdoptifySpacing.xl),
          children: [
            if (animals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AdoptifySpacing.xl),
                child: Column(
                  children: [
                    Icon(Icons.pets_outlined, size: 40, color: context.colors.primaryDark),
                    const SizedBox(height: AdoptifySpacing.md),
                    Text(
                      animalStatusEmptyMessages[status] ?? 'Esta pestaña no tiene animales.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                '${animals.length} ${animals.length == 1 ? 'animal' : 'animales'} en ${animalStatusTabLabels[status]}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AdoptifySpacing.lg),
              for (final animal in animals) ...[
                _AnimalCard(
                  animal: animal,
                  updating: updatingId == '${animal.id}',
                  onEdit: () => onEdit(animal),
                  onStatus: () => onStatus(animal),
                  interestCount: overview?.interestCount(animal.id) ?? 0,
                  onInterested: () => onInterested(animal),
                  onApplications: () => onApplications(animal),
                ),
                const SizedBox(height: AdoptifySpacing.md),
              ],
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
    required this.onApplications,
  });

  final ManagedAnimal animal;
  final bool updating;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final int interestCount;
  final VoidCallback onInterested;
  final VoidCallback onApplications;

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
                      key: ValueKey('interested-${animal.id}'),
                      onPressed: onInterested,
                      icon: const Icon(Icons.favorite_outline, size: 18),
                      label: Text('$interestCount ${interestCount == 1 ? 'interesado' : 'interesados'}'),
                    ),
                    TextButton.icon(
                      onPressed: onApplications,
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Ver postulaciones'),
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
