import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'foundation_animals_service.dart';

class InterestedAnimalsScreen extends StatefulWidget {
  const InterestedAnimalsScreen({super.key, this.animalId});

  final int? animalId;

  @override
  State<InterestedAnimalsScreen> createState() => _InterestedAnimalsScreenState();
}

class _InterestedAnimalsScreenState extends State<InterestedAnimalsScreen> {
  Future<List<AnimalInterested>>? _groups;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _groups ??= _load();
  }

  Future<List<AnimalInterested>> _load() => FoundationAnimalsService(AuthScope.of(context).api).interested();

  void _reload() => setState(() => _groups = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Personas interesadas')),
        body: ContentWidth(
          child: FutureBuilder<List<AnimalInterested>>(
            future: _groups,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(AdoptifySpacing.xl),
                  children: [
                    MessageBox.error(message: errorMessage(snapshot.error!, 'No pudimos cargar las personas interesadas.')),
                    const SizedBox(height: AdoptifySpacing.md),
                    OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
                  ],
                );
              }
              final allGroups = snapshot.data ?? const <AnimalInterested>[];
              final groups = widget.animalId == null
                  ? allGroups
                  : allGroups.where((group) => group.animalId == widget.animalId).toList();
              if (groups.isEmpty) return const _NoAnimals();
              return ListView(
                padding: const EdgeInsets.all(AdoptifySpacing.xl),
                children: [
                  Text(
                    widget.animalId == null ? 'Interesados en tus animales' : 'Personas interesadas',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AdoptifySpacing.xs),
                  Text('Un like no inicia un chat. Tú decides cuándo contactar a una persona.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AdoptifySpacing.xl),
                  for (final group in groups) ...[_InterestedGroup(group: group), const SizedBox(height: AdoptifySpacing.lg)],
                ],
              );
            },
          ),
        ),
      );
}

class _NoAnimals extends StatelessWidget {
  const _NoAnimals();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AdoptifySpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.pets_outlined, size: 48, color: context.colors.primaryDark),
            const SizedBox(height: AdoptifySpacing.md),
            Text('Aún no tienes animales publicados', style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}

class _InterestedGroup extends StatelessWidget {
  const _InterestedGroup({required this.group});

  final AnimalInterested group;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AdoptifySpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.animalName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdoptifySpacing.xs),
            Text(group.interested.isEmpty ? 'Aún no tiene likes.' : '${group.interested.length} persona${group.interested.length == 1 ? '' : 's'} interesada${group.interested.length == 1 ? '' : 's'}.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AdoptifySpacing.md),
            if (group.interested.isEmpty)
              Text('Cuando alguien marque a ${group.animalName} con un corazón, aparecerá aquí.', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final person in group.interested) ...[
                _InterestedPerson(person: person, animalId: group.animalId),
                const SizedBox(height: AdoptifySpacing.sm),
              ],
          ]),
        ),
      );
}

class _InterestedPerson extends StatelessWidget {
  const _InterestedPerson({required this.person, required this.animalId});

  final InterestedPerson person;
  final int animalId;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatMediumDate(person.favoritedAt);
    return DecoratedBox(
      decoration: BoxDecoration(color: context.colors.primarySoft, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(AdoptifySpacing.md),
        child: Row(children: [
          CircleAvatar(backgroundColor: context.colors.surface, foregroundColor: context.colors.primaryDark, child: const Icon(Icons.person_outline)),
          const SizedBox(width: AdoptifySpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(person.fullName, style: Theme.of(context).textTheme.titleSmall), Text('Marcó favorito el $date', style: Theme.of(context).textTheme.bodySmall)])),
          TextButton(
            onPressed: () => context.push('/fundacion/chat?user_id=${person.userId}&animal_id=$animalId'),
            child: const Text('Iniciar conversación'),
          ),
        ]),
      ),
    );
  }
}
