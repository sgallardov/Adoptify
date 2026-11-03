import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import 'match_service.dart';

// Pestaña "Match": tarjetas de mascotas ordenadas por compatibilidad con el formulario "Quiero adoptar".
// Se desliza a la derecha (me gusta) o a la izquierda (paso), o se usan los botones.
class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

enum _Status { loading, needsLogin, needsProfile, error, ready }

class _MatchScreenState extends State<MatchScreen> {
  _Status _status = _Status.loading;
  List<MatchAnimal> _cards = const [];
  final _liked = <int>{};
  int _index = 0;
  Object? _loadedFor; // usuario con el que se cargó; null si no había sesión
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La pestaña conserva su estado: se recarga al iniciar o cerrar sesión
    final user = AuthScope.of(context).user;
    if (_started && identical(user, _loadedFor)) return;
    _started = true;
    _loadedFor = user;
    _load();
  }

  Future<void> _load() async {
    final auth = AuthScope.of(context);
    if (auth.user == null) {
      setState(() => _status = _Status.needsLogin);
      return;
    }
    setState(() => _status = _Status.loading);
    try {
      final service = MatchService(auth.api);
      final cards = await service.fetch();
      final favorites = await _favoriteIds(service);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _liked..clear()..addAll(favorites);
        _index = 0;
        _status = _Status.ready;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _status = switch (error.statusCode) {
            404 => _Status.needsProfile,
            401 => _Status.needsLogin,
            _ => _Status.error,
          });
    }
  }

  // Si los favoritos no cargan, el match igual funciona
  Future<Set<int>> _favoriteIds(MatchService service) async {
    try {
      return {for (final animal in await service.fetchFavorites()) animal.id};
    } on ApiException {
      return {};
    }
  }

  void _next({required bool like}) {
    if (_index >= _cards.length) return;
    final card = _cards[_index];
    setState(() {
      if (like) _liked.add(card.id);
      _index++;
    });
    if (like) _saveFavorite(card.id);
  }

  Future<void> _saveFavorite(int id) async {
    try {
      await MatchService(AuthScope.of(context).api).addFavorite(id);
    } on ApiException {
      if (!mounted) return;
      setState(() => _liked.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pudimos guardar el favorito.')));
    }
  }

  Future<void> _openFavorites() async {
    await context.push('/favoritos');
    if (!mounted) return;
    final favorites = await _favoriteIds(MatchService(AuthScope.of(context).api));
    if (mounted) setState(() => _liked..clear()..addAll(favorites));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haz Match!'),
        // La pestaña conserva su estado: así se recarga tras editar "Quiero adoptar" o iniciar sesión
        actions: [
          if (_status == _Status.ready)
            IconButton(
              tooltip: 'Mis favoritos',
              onPressed: _openFavorites,
              icon: Badge(
                isLabelVisible: _liked.isNotEmpty,
                label: Text('${_liked.length}'),
                child: const Icon(Icons.favorite_border),
              ),
            ),
          IconButton(tooltip: 'Actualizar', onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: switch (_status) {
        _Status.loading => const Center(child: CircularProgressIndicator()),
        _Status.needsLogin => _Prompt(
            icon: Icons.favorite,
            title: 'Inicia sesión para hacer match',
            message: 'Con tu cuenta te mostramos las mascotas que mejor encajan contigo.',
            action: 'Iniciar sesión',
            onAction: () => context.push('/login'),
          ),
        _Status.needsProfile => _Prompt(
            icon: Icons.favorite_border,
            title: 'Cuéntanos qué buscas',
            message: 'Completa "Quiero adoptar" en tu perfil (es opcional) y te ordenamos las mascotas por compatibilidad.',
            action: 'Ir a mi perfil',
            onAction: () => context.go('/cuenta'),
          ),
        _Status.error => _Prompt(
            icon: Icons.cloud_off,
            title: 'No pudimos cargar tu match',
            message: 'Revisa tu conexión e inténtalo de nuevo.',
            action: 'Reintentar',
            onAction: _load,
          ),
        _Status.ready => _index >= _cards.length ? _Done(liked: _liked.length, onReload: _load) : _Deck(
            card: _cards[_index],
            remaining: _cards.length - _index,
            onPass: () => _next(like: false),
            onLike: () => _next(like: true),
          ),
      },
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.icon, required this.title, required this.message, required this.action, required this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ComingSoon(icon: icon, title: title, message: message),
          FilledButton(onPressed: onAction, child: Text(action)),
          const SizedBox(height: AdoptifySpacing.xxl),
        ],
      );
}

class _Done extends StatelessWidget {
  const _Done({required this.liked, required this.onReload});

  final int liked;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) => _Prompt(
        icon: Icons.check_circle_outline,
        title: 'Viste todas las mascotas',
        message: liked == 0 ? 'No marcaste ninguna como favorita.' : 'Marcaste $liked como favorita${liked == 1 ? '' : 's'}.',
        action: 'Volver a empezar',
        onAction: onReload,
      );
}

class _Deck extends StatelessWidget {
  const _Deck({required this.card, required this.remaining, required this.onPass, required this.onLike});

  final MatchAnimal card;
  final int remaining;
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.all(AdoptifySpacing.lg),
        child: Column(
          children: [
            Expanded(
              child: Dismissible(
                key: ValueKey(card.id),
                onDismissed: (direction) => direction == DismissDirection.startToEnd ? onLike() : onPass(),
                child: _AnimalCard(card: card),
              ),
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: 'Pasar',
                  iconSize: 32,
                  onPressed: onPass,
                  icon: Icon(Icons.close, color: colors.textMuted),
                ),
                const SizedBox(width: AdoptifySpacing.xxl),
                IconButton.filled(
                  tooltip: 'Me gusta',
                  iconSize: 32,
                  onPressed: onLike,
                  icon: const Icon(Icons.favorite),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.sm),
            Text('Quedan $remaining', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.card});

  final MatchAnimal card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final facts = [card.species, card.age, card.size, card.gender, card.energyLabel].map((f) => f[0].toUpperCase() + f.substring(1));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, box) => AnimalPhoto(url: card.photoUrl, size: box.biggest.shortestSide),
                ),
                Positioned(
                  top: AdoptifySpacing.md,
                  right: AdoptifySpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.xs),
                    decoration: BoxDecoration(color: colors.primaryDark, borderRadius: BorderRadius.circular(99)),
                    child: Text('${card.percent}% match', style: textTheme.labelLarge?.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdoptifySpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: textTheme.titleLarge),
                if (card.foundationName != null) Text(card.foundationName!, style: textTheme.bodySmall),
                const SizedBox(height: AdoptifySpacing.sm),
                Wrap(
                  spacing: AdoptifySpacing.sm,
                  runSpacing: AdoptifySpacing.xs,
                  children: [for (final fact in facts) Chip(label: Text(fact), visualDensity: VisualDensity.compact)],
                ),
                if (card.description != null) ...[
                  const SizedBox(height: AdoptifySpacing.sm),
                  Text(card.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
