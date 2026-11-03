import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'match_service.dart';

// Mascotas marcadas con el corazón en el match, con opción de quitarlas
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<MatchAnimal>? _items;
  String? _error;
  bool _started = false;

  MatchService get _service => MatchService(AuthScope.of(context).api);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.fetchFavorites();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(error, 'No pudimos cargar tus favoritos.'));
    }
  }

  Future<void> _remove(MatchAnimal animal) async {
    try {
      await _service.removeFavorite(animal.id);
      if (mounted) setState(() => _items = [for (final item in _items!) if (item.id != animal.id) item]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(error, 'No pudimos quitarlo.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: _error != null
          ? ComingSoon(icon: Icons.cloud_off, title: 'No pudimos cargar', message: _error!)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const ComingSoon(
                      icon: Icons.favorite_border,
                      title: 'Aún no tienes favoritos',
                      message: 'Toca el corazón en una tarjeta del match para guardarla aquí.',
                    )
                  : ContentWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AdoptifySpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AdoptifySpacing.md),
                        itemBuilder: (context, index) =>
                            _FavoriteTile(animal: items[index], onRemove: () => _remove(items[index])),
                      ),
                    ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.animal, required this.onRemove});

  final MatchAnimal animal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Row(
        children: [
          AnimalPhoto(url: animal.photoUrl, size: 64),
          const SizedBox(width: AdoptifySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(animal.name, style: textTheme.titleMedium),
                Text('${animal.species} · ${animal.age} · ${animal.size}', style: textTheme.bodySmall),
                Text('${animal.percent}% match', style: textTheme.labelMedium?.copyWith(color: colors.primaryText)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar de favoritos',
            onPressed: onRemove,
            icon: Icon(Icons.favorite, color: colors.primaryDark),
          ),
        ],
      ),
    );
  }
}
