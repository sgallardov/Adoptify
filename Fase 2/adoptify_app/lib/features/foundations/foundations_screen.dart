import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/foundation_avatar.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';
import 'foundation_service.dart';

// Directorio público. Conserva una jerarquía simple: historias de adopción,
// métricas reales y luego las organizaciones con sus propios animales.
class FoundationsScreen extends StatefulWidget {
  const FoundationsScreen({super.key});

  @override
  State<FoundationsScreen> createState() => _FoundationsScreenState();
}

class _FoundationsScreenState extends State<FoundationsScreen> {
  late final FoundationService _service = FoundationService(
    AuthScope.of(context).api,
  );
  List<Foundation> _foundations = [];
  bool _loading = true;
  String? _error;
  bool _started = false;
  // Tu ubicación: con ella las fundaciones vienen de la más cercana a la más lejana
  LatLng? _origin;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
      _detectOrigin();
    }
  }

  // Sin mostrar errores: si no hay ubicación, la lista queda por nombre
  Future<void> _detectOrigin() async {
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      _origin = position;
      _load();
    } catch (_) {}
  }

  // Si llega una respuesta vieja (por ejemplo, la de antes de tener tu ubicación), se descarta
  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = _foundations.isEmpty;
      _error = null;
    });
    try {
      final foundations = await _service.fetchFoundations(origin: _origin);
      if (!mounted || request != _request) return;
      setState(() {
        _foundations = foundations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos cargar las fundaciones.');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fundaciones')),
    body: _body(),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _foundations.isEmpty) {
      return ContentWidth(
        child: Column(
          children: [
            Expanded(
              child: ComingSoon(
                icon: Icons.cloud_off_outlined,
                title: 'Sin conexión',
                message: _error!,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.xl),
              child: FilledButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      );
    }
    if (_foundations.isEmpty) {
      return const ComingSoon(
        icon: Icons.volunteer_activism_outlined,
        title: 'Aún no hay fundaciones',
        message:
            'Cuando se registre una fundación, la verás aquí con sus mascotas.',
      );
    }

    final stories = [
      for (final foundation in _foundations)
        for (final animal in foundation.animals)
          _AdoptionStory(foundation: foundation, animal: animal),
    ];
    final totalAnimals = stories.length;
    final communes = _foundations
        .map((foundation) => foundation.commune ?? foundation.city)
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AdoptifySpacing.lg,
          AdoptifySpacing.md,
          AdoptifySpacing.lg,
          AdoptifySpacing.xxl,
        ),
        children: [
          ContentWidth(
            child: _Metrics(
              foundations: _foundations.length,
              animals: totalAnimals,
              communes: communes,
            ),
          ),
          if (stories.isNotEmpty) ...[
            const SizedBox(height: AdoptifySpacing.xl),
            ContentWidth(
              child: Text(
                'Historias que buscan hogar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AdoptifySpacing.xs),
            ContentWidth(
              child: Text(
                'Desliza para conocer a quienes esperan una familia.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textMuted),
              ),
            ),
            const SizedBox(height: AdoptifySpacing.md),
            ContentWidth(child: _StoriesCarousel(stories: stories)),
          ],
          const SizedBox(height: AdoptifySpacing.xl),
          ContentWidth(
            child: Text(
              'Fundaciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AdoptifySpacing.xs),
          ContentWidth(
            child: Text(
              _foundations.first.distanceKm != null
                  ? 'De la más cercana a la más lejana de ti.'
                  : 'Conoce su labor y a sus animales disponibles.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textMuted),
            ),
          ),
          for (final foundation in _foundations) ...[
            const SizedBox(height: AdoptifySpacing.lg),
            ContentWidth(child: FoundationCard(foundation: foundation)),
          ],
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.foundations,
    required this.animals,
    required this.communes,
  });
  final int foundations;
  final int animals;
  final int communes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AdoptifySpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryStrong,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Row(
        children: [
          _Metric(
            value: foundations,
            label: foundations == 1 ? 'fundación' : 'fundaciones',
          ),
          _Metric(
            value: animals,
            label: animals == 1 ? 'en adopción' : 'en adopción',
          ),
          _Metric(value: communes, label: communes == 1 ? 'comuna' : 'comunas'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: context.colors.onAccent),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.colors.onAccent.withValues(alpha: 0.88),
            letterSpacing: 0,
          ),
        ),
      ],
    ),
  );
}

class _AdoptionStory {
  const _AdoptionStory({required this.foundation, required this.animal});
  final Foundation foundation;
  final Animal animal;
}

class _StoriesCarousel extends StatelessWidget {
  const _StoriesCarousel({required this.stories});
  final List<_AdoptionStory> stories;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 228,
    child: ListView.separated(
      key: const ValueKey('adoption-stories'),
      scrollDirection: Axis.horizontal,
      itemCount: stories.length,
      padding: const EdgeInsets.only(right: AdoptifySpacing.lg),
      separatorBuilder: (_, _) => const SizedBox(width: AdoptifySpacing.md),
      itemBuilder: (context, index) => _StoryCard(story: stories[index]),
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story});
  final _AdoptionStory story;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final animal = story.animal;
    return Semantics(
      button: true,
      label: 'Conocer a ${animal.name}',
      child: Material(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        child: InkWell(
          onTap: () => context.push('/animales/${animal.id}', extra: animal),
          borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          child: SizedBox(
            width: 276,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.32),
                ),
                borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AdoptifySpacing.md),
                child: Row(
                  children: [
                    AnimalPhoto(url: animal.photoUrl, size: 112),
                    const SizedBox(width: AdoptifySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'BUSCA HOGAR',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.primaryDark),
                          ),
                          const SizedBox(height: AdoptifySpacing.xs),
                          Text(
                            animal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AdoptifySpacing.xs),
                          Text(
                            animal.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AdoptifySpacing.md),
                          Text(
                            story.foundation.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.primaryText),
                          ),
                          const SizedBox(height: AdoptifySpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AdoptifySpacing.sm,
                              vertical: AdoptifySpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryStrong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Conocer',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: colors.onAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Card de organización con muestra de hasta tres casos, similar a una vitrina y no a una ficha administrativa.
class FoundationCard extends StatelessWidget {
  const FoundationCard({super.key, required this.foundation});
  final Foundation foundation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final animals = foundation.animals;
    // Colores de fondo pensados para texto blanco: se leen igual en modo claro y oscuro
    final accent = foundation.id.isEven ? colors.primaryStrong : colors.successStrong;
    return Semantics(
      button: true,
      label: 'Ver fundación ${foundation.name}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        child: InkWell(
          onTap: () =>
              context.push('/fundaciones/${foundation.id}', extra: foundation),
          borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
              boxShadow: AdoptifyShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FoundationIdentity(foundation: foundation, accent: accent),
                if (animals.isNotEmpty) _AnimalStrip(animals: animals),
                Padding(
                  padding: const EdgeInsets.all(AdoptifySpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (foundation.description != null) ...[
                        Text(
                          foundation.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AdoptifySpacing.md),
                      ],
                      Row(
                        children: [
                          _AvailabilityBadge(
                            count: animals.length,
                            accent: accent,
                          ),
                          const Spacer(),
                          Text(
                            'Ver fundación',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: colors.primaryDark),
                          ),
                          const SizedBox(width: AdoptifySpacing.xs),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: colors.primaryDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundationIdentity extends StatelessWidget {
  const _FoundationIdentity({required this.foundation, required this.accent});
  final Foundation foundation;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    // Centrado y apilado: inicial, nombre y ubicación (con la distancia si se conoce)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AdoptifyRadius.lg),
        ),
      ),
      child: Column(
        children: [
          // Foto de perfil o, sin ella, la inicial del color de la tarjeta sobre un cuadro claro
          FoundationAvatar(name: foundation.name, photoUrl: foundation.photoUrl, size: 56, color: accent),
          const SizedBox(height: AdoptifySpacing.md),
          Text.rich(
            TextSpan(
              text: foundation.name,
              children: [
                if (foundation.isVerified)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AdoptifySpacing.xs),
                      child: Tooltip(
                        message: 'Fundación verificada',
                        child: Icon(Icons.verified, size: 18, color: colors.onAccent),
                      ),
                    ),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: colors.onAccent),
          ),
          const SizedBox(height: AdoptifySpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: colors.onAccent.withValues(alpha: 0.86),
              ),
              const SizedBox(width: AdoptifySpacing.xs),
              Flexible(
                child: Text(
                  foundation.distanceKm != null
                      ? '${foundation.place} · a ${formatKm(foundation.distanceKm!)} km'
                      : foundation.place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onAccent.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimalStrip extends StatelessWidget {
  const _AnimalStrip({required this.animals});
  final List<Animal> animals;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final visible = animals.take(3).toList();
      final width = ((constraints.maxWidth - (AdoptifySpacing.sm * 2)) / 3)
          .clamp(92.0, 190.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AdoptifySpacing.lg,
          AdoptifySpacing.lg,
          AdoptifySpacing.lg,
          0,
        ),
        child: SizedBox(
          height: width + 36,
          child: Row(
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                if (index > 0) const SizedBox(width: AdoptifySpacing.sm),
                _AnimalMiniCard(animal: visible[index], size: width),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _AnimalMiniCard extends StatelessWidget {
  const _AnimalMiniCard({required this.animal, required this.size});
  final Animal animal;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimalPhoto(url: animal.photoUrl, size: size),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          animal.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.count, required this.accent});
  final int count;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AdoptifySpacing.sm,
      vertical: AdoptifySpacing.xs,
    ),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '$count ${count == 1 ? 'animal disponible' : 'animales disponibles'}',
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: context.colors.onAccent),
    ),
  );
}
