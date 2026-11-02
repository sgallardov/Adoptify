import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';
import 'foundation_service.dart';

// Fundaciones registradas y las mascotas que cada una tiene en adopción
class FoundationsScreen extends StatefulWidget {
  const FoundationsScreen({super.key});

  @override
  State<FoundationsScreen> createState() => _FoundationsScreenState();
}

class _FoundationsScreenState extends State<FoundationsScreen> {
  late final FoundationService _service = FoundationService(AuthScope.of(context).api);

  List<Foundation> _foundations = [];
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _foundations.isEmpty;
      _error = null;
    });
    try {
      final foundations = await _service.fetchFoundations();
      if (!mounted) return;
      setState(() {
        _foundations = foundations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos cargar las fundaciones.');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fundaciones')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _foundations.isEmpty) {
      return ContentWidth(
        child: Column(
          children: [
            Expanded(
              child: ComingSoon(icon: Icons.cloud_off_outlined, title: 'Sin conexión', message: _error!),
            ),
            Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.xl),
              child: FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ),
          ],
        ),
      );
    }
    if (_foundations.isEmpty) {
      return const ComingSoon(
        icon: Icons.volunteer_activism_outlined,
        title: 'Aún no hay fundaciones',
        message: 'Cuando se registre una fundación, la verás aquí con sus mascotas.',
      );
    }
    final total = _foundations.fold<int>(0, (sum, foundation) => sum + foundation.animals.length);
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, AdoptifySpacing.xl),
        children: [
          ContentWidth(
            child: Text(
              '${_foundations.length} ${_foundations.length == 1 ? 'fundación' : 'fundaciones'} · '
              '$total ${total == 1 ? 'mascota' : 'mascotas'} en adopción',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
            ),
          ),
          for (final foundation in _foundations) ...[
            const SizedBox(height: AdoptifySpacing.lg),
            ContentWidth(child: _FoundationCard(foundation: foundation)),
          ],
        ],
      ),
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({required this.foundation});

  final Foundation foundation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final animals = foundation.animals;

    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: colors.primarySoft, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
                child: Icon(Icons.volunteer_activism, color: colors.primaryDark),
              ),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(foundation.name, style: textTheme.titleMedium)),
                        if (foundation.isVerified) ...[
                          const SizedBox(width: AdoptifySpacing.xs),
                          Tooltip(
                            message: 'Fundación verificada',
                            child: Icon(Icons.verified, size: 18, color: colors.primary),
                          ),
                        ],
                      ],
                    ),
                    Text(foundation.place, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (foundation.description != null) ...[
            const SizedBox(height: AdoptifySpacing.md),
            Text(foundation.description!, style: textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AdoptifySpacing.md),
          Wrap(
            spacing: AdoptifySpacing.lg,
            runSpacing: AdoptifySpacing.xs,
            children: [
              if (foundation.phone != null) _Contact(icon: Icons.phone_outlined, text: foundation.phone!),
              _Contact(icon: Icons.mail_outline, text: foundation.email),
              if (foundation.address != null) _Contact(icon: Icons.place_outlined, text: foundation.address!),
            ],
          ),
          const SizedBox(height: AdoptifySpacing.lg),
          Text('En adopción (${animals.length})', style: textTheme.titleSmall),
          const SizedBox(height: AdoptifySpacing.sm),
          if (animals.isEmpty)
            Text('Por ahora no tiene mascotas en adopción.', style: textTheme.bodySmall)
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: animals.length,
                separatorBuilder: (_, _) => const SizedBox(width: AdoptifySpacing.md),
                itemBuilder: (context, index) => _AnimalTile(animal: animals[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.colors.textMuted),
        const SizedBox(width: AdoptifySpacing.xs),
        Flexible(child: SelectableText(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

// Mascota dentro de la tarjeta de su fundación
class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimalPhoto(url: animal.photoUrl, size: 112),
          const SizedBox(height: AdoptifySpacing.xs),
          Text(animal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
          Text(
            '${capitalize(animal.species)} · ${animal.age}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
