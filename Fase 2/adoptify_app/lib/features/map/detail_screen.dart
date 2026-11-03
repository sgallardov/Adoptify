import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/map/map_controls.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import 'map_service.dart';

// Ficha completa de una mascota o un reporte, a pantalla completa: se abre al tocar la tarjeta
// que aparece sobre el mapa al tocar un pin. Mismo recorrido que "Reportar mascota": pantalla
// completa fuera de la barra inferior, con un botón para volver.

class AnimalDetailScreen extends StatelessWidget {
  const AnimalDetailScreen({super.key, required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailHero(photoUrl: animal.photoUrl),
            Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.lg),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: textTheme.headlineSmall),
                    const SizedBox(height: AdoptifySpacing.sm),
                    _StatusChip(label: animal.statusLabel, background: colors.primarySoft, foreground: colors.primaryTextDark),
                    const SizedBox(height: AdoptifySpacing.md),
                    Text(animal.summary, style: textTheme.bodyLarge),
                    if (animal.foundationName != null) ...[
                      const SizedBox(height: AdoptifySpacing.sm),
                      _IconLine(icon: Icons.home_work_outlined, text: animal.foundationName!),
                    ],
                    Text(animal.publicZone),
                    if (animal.withinRadius) ...[
                      const SizedBox(height: AdoptifySpacing.sm),
                      Text(
                        'Dentro de tu radio de búsqueda',
                        style: textTheme.labelLarge?.copyWith(color: colors.primaryDark),
                      ),
                    ],
                    if (animal.position != null) ...[
                      const SizedBox(height: AdoptifySpacing.xl),
                      _MiniMap(position: animal.position!, pin: MapPins.animal),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// El reporte suma "me enteré" (corazón) y comentarios anónimos entre vecinos, con sus contadores
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.report});

  final DogReport report;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late final MapService _service = MapService(AuthScope.of(context).api);
  final _comment = TextEditingController();
  final _commentsKey = GlobalKey();

  List<ReportComment>? _comments;
  ReportLikes? _likes;
  bool _socialError = false;
  bool _sending = false;
  bool _liking = false;
  bool _started = false;
  AppUser? _user;

  DogReport get report => widget.report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se recarga también al iniciar o cerrar sesión: cambian "Tú" en los comentarios y tu corazón
    final user = AuthScope.of(context).user;
    if (!_started || user != _user) {
      _started = true;
      _user = user;
      _loadSocial();
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadSocial() async {
    setState(() => _socialError = false);
    try {
      final comments = _service.fetchComments(report.id);
      final likes = _service.fetchLikes(report.id);
      final results = (await comments, await likes);
      if (!mounted) return;
      setState(() {
        _comments = results.$1;
        _likes = results.$2;
      });
    } catch (_) {
      if (mounted) setState(() => _socialError = true);
    }
  }

  Future<void> _toggleLike() async {
    final likes = _likes;
    if (likes == null || _liking) return;
    // Igual que reportar: marcar requiere cuenta, para contar una vez por persona
    if (_user == null) {
      context.push('/login');
      return;
    }
    setState(() => _liking = true);
    try {
      final updated = await _service.setLiked(report.id, !likes.liked);
      if (mounted) setState(() => _likes = updated);
    } catch (error) {
      _showError(errorMessage(error, 'No pudimos guardar tu me enteré.'));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _send() async {
    final body = _comment.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await _service.addComment(report.id, body);
      if (!mounted) return;
      _comment.clear();
      setState(() => _comments = [...?_comments, comment]);
    } catch (error) {
      _showError(errorMessage(error, 'No pudimos enviar tu comentario.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Tocar el contador de comentarios baja hasta la conversación
  void _showComments() {
    final target = _commentsKey.currentContext;
    if (target != null) Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailHero(photoUrl: report.photoUrl),
                  Padding(
                    padding: const EdgeInsets.all(AdoptifySpacing.lg),
                    child: ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Mascota reportada',
                                  style: textTheme.headlineSmall?.copyWith(color: colors.reportText),
                                ),
                              ),
                              // Me enteré y comentarios: arriba, a la derecha del título
                              _SocialCounters(
                                likes: _likes,
                                comments: _comments,
                                liking: _liking,
                                onLike: _toggleLike,
                                onComments: _showComments,
                              ),
                            ],
                          ),
                          const SizedBox(height: AdoptifySpacing.sm),
                          _StatusChip(label: report.statusLabel, background: colors.primarySoft, foreground: colors.reportText),
                          const SizedBox(height: AdoptifySpacing.md),
                          if (report.summary.isNotEmpty) Text(report.summary, style: textTheme.titleMedium),
                          if (report.conditionLabel.isNotEmpty) ...[
                            const SizedBox(height: AdoptifySpacing.xs),
                            Text('Estado: ${report.conditionLabel}', style: textTheme.bodyLarge),
                          ],
                          if (report.features != null) ...[
                            const SizedBox(height: AdoptifySpacing.xs),
                            Text(report.features!, style: textTheme.bodyLarge),
                          ],
                          const SizedBox(height: AdoptifySpacing.lg),
                          Text('Comentarios', style: textTheme.titleSmall),
                          const SizedBox(height: AdoptifySpacing.xs),
                          Text(
                            '“${report.description}”',
                            style: textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: AdoptifySpacing.lg),
                          _IconLine(icon: Icons.schedule, text: 'Reportado · ${formatDate(report.createdAt)}'),
                          if (report.distanceKm != null) ...[
                            const SizedBox(height: AdoptifySpacing.sm),
                            Text(
                              'A ${formatKm(report.distanceKm!)} km',
                              style: textTheme.labelLarge?.copyWith(color: colors.reportText),
                            ),
                          ],
                          const SizedBox(height: AdoptifySpacing.xl),
                          const Text('Último avistamiento'),
                          _LocationSection(position: report.position, pin: MapPins.report),
                          const SizedBox(height: AdoptifySpacing.lg),
                          _CommentsSection(
                            key: _commentsKey,
                            comments: _comments,
                            error: _socialError,
                            onRetry: _loadSocial,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CommentComposer(
            controller: _comment,
            loggedIn: _user != null,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// Conversación anónima entre vecinos, al final del detalle
class _CommentsSection extends StatelessWidget {
  const _CommentsSection({super.key, required this.comments, required this.error, required this.onRetry});

  final List<ReportComment>? comments;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: colors.textMuted);
    final list = comments;

    final Widget body;
    if (error) {
      body = Row(
        children: [
          Expanded(child: Text('No pudimos cargar los comentarios.', style: muted)),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    } else if (list == null) {
      body = const Padding(
        padding: EdgeInsets.all(AdoptifySpacing.lg),
        child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AdoptifySpacing.md),
        child: Text('Aún no hay comentarios. Si lo viste o vas en camino, avísales a los demás.', style: muted),
      );
    } else {
      body = Column(children: [for (final comment in list) _CommentTile(comment: comment)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: AdoptifySpacing.md),
        Text('Comentarios de vecinos', style: textTheme.titleSmall),
        body,
      ],
    );
  }
}

// Contadores de "me enteré" y comentarios, a la derecha del título del reporte
class _SocialCounters extends StatelessWidget {
  const _SocialCounters({
    required this.likes,
    required this.comments,
    required this.liking,
    required this.onLike,
    required this.onComments,
  });

  final ReportLikes? likes;
  final List<ReportComment>? comments;
  final bool liking;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final liked = likes?.liked ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Counter(
          key: const ValueKey('likes-counter'),
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? colors.report : colors.textMuted,
          count: likes?.count,
          tooltip: liked ? 'Quitar me enteré' : 'Me enteré',
          onTap: likes == null || liking ? null : onLike,
        ),
        const SizedBox(width: AdoptifySpacing.md),
        _Counter(
          key: const ValueKey('comments-counter'),
          icon: Icons.chat_bubble_outline,
          color: colors.textMuted,
          count: comments?.length,
          tooltip: 'Ver comentarios',
          onTap: onComments,
        ),
      ],
    );
  }
}

// Ícono con su número al lado, como "♡ 6   💬 26"
class _Counter extends StatelessWidget {
  const _Counter({super.key, required this.icon, required this.color, required this.count, required this.tooltip, this.onTap});

  final IconData icon;
  final Color color;
  final int? count;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.xs, vertical: AdoptifySpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: AdoptifySpacing.sm),
          Text(count?.toString() ?? '–', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.textMuted)),
        ],
      ),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? Semantics(label: tooltip, child: content)
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AdoptifyRadius.sm), child: content),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ReportComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdoptifySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: comment.isMine ? colors.primarySoft : colors.muted,
            child: Icon(Icons.person, size: 20, color: comment.isMine ? colors.primaryDark : colors.placeholder),
          ),
          const SizedBox(width: AdoptifySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.isMine ? 'Tú' : 'Anónimo', style: textTheme.titleSmall),
                Text(formatDateTime(comment.createdAt), style: textTheme.bodySmall?.copyWith(color: colors.textMuted)),
                const SizedBox(height: AdoptifySpacing.xs),
                Text(comment.body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Barra fija abajo para escribir, como en un chat. Sin sesión invita a iniciarla.
class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.loggedIn,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loggedIn;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.sm, AdoptifySpacing.sm),
          child: !loggedIn
              ? OutlinedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Inicia sesión para comentar'),
                )
              : ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('comment-field'),
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un comentario anónimo…',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AdoptifySpacing.xs),
                      sending
                          ? const Padding(
                              padding: EdgeInsets.all(AdoptifySpacing.md),
                              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : IconButton(
                              onPressed: controller.text.trim().isEmpty ? null : onSend,
                              icon: Icon(Icons.send, color: controller.text.trim().isEmpty ? colors.placeholder : colors.primary),
                              tooltip: 'Enviar',
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// Foto grande arriba (o una huella si no hay foto) con el botón de volver flotando encima.
// Si hay foto, tocarla abre la misma imagen sin recortar y con zoom.
class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: context.colors.muted,
      alignment: Alignment.center,
      child: Icon(Icons.pets, size: 64, color: context.colors.placeholder),
    );
    final url = photoUrl;
    final photo = url == null ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url == null
              ? photo
              : GestureDetector(
                  key: const ValueKey('hero-photo'),
                  onTap: () => _openPhoto(context, url),
                  child: Semantics(button: true, label: 'Ver foto completa', child: photo),
                ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.lg),
              child: Align(
                alignment: Alignment.topLeft,
                child: MapButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
          // Pista de que la foto se puede ampliar
          if (url != null)
            Positioned(
              right: AdoptifySpacing.lg,
              bottom: AdoptifySpacing.lg,
              child: IgnorePointer(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(AdoptifySpacing.sm),
                    child: Icon(Icons.zoom_in, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Abre la foto a pantalla completa, sin recortar y con zoom (pellizcar o doble toque).
void _openPhoto(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => _PhotoViewer(url: url),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.url});

  final String url;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _transformation = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _onDoubleTap() {
    final matrix = _transformation.value;
    if (matrix != Matrix4.identity()) {
      _transformation.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    _transformation.value = Matrix4.identity()
      ..translateByDouble(-position.dx * 2, -position.dy * 2, 0, 1)
      ..scaleByDouble(3.0, 3.0, 3.0, 1);
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) => _doubleTapDetails = details,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformation,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.pets, size: 64, color: Colors.white38),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.lg),
              child: Align(
                alignment: Alignment.topRight,
                child: MapButton(
                  icon: Icons.close,
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.xs),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground)),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.textMuted),
        const SizedBox(width: AdoptifySpacing.xs),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textMuted))),
      ],
    );
  }
}

// Título "Ubicación" + coordenadas para copiar + mapa chico, igual en el detalle de animal y de reporte
class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.position, required this.pin});

  final LatLng position;
  final Widget pin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AdoptifySpacing.xs),
        _Coordinates(position: position),
        const SizedBox(height: AdoptifySpacing.sm),
        _MiniMap(position: position, pin: pin),
      ],
    );
  }
}

// Coordenadas en texto plano y sutil, para copiar y pegar en otra app de rutas (Google Maps, Waze, etc.).
// Van con punto decimal (no con coma como el resto de la app) porque así las reconocen esas apps.
class _Coordinates extends StatelessWidget {
  const _Coordinates({required this.position});

  final LatLng position;

  String get _text => '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación copiada')));
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted);
    return Row(
      children: [
        Expanded(child: SelectableText(_text, style: style)),
        IconButton(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_outlined, size: 16),
          tooltip: 'Copiar ubicación',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// Mapa chico y fijo (sin gestos propios) con el pin exacto. Tocarlo vuelve al mapa, que ya lo muestra.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.position, required this.pin});

  final LatLng position;
  final Widget pin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver al mapa',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          child: Container(
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [const OsmTileLayer(), MarkerLayer(markers: [mapMarker(position, pin)])],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
