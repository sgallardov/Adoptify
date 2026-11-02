import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../shared/map/map_controls.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/content_width.dart';
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
                    if (animal.distanceKm != null) ...[
                      const SizedBox(height: AdoptifySpacing.sm),
                      Text(
                        'A ${formatKm(animal.distanceKm!)} km de ti',
                        style: textTheme.labelLarge?.copyWith(color: colors.primaryDark),
                      ),
                    ],
                    if (animal.position != null) ...[
                      const SizedBox(height: AdoptifySpacing.xl),
                      Text('Ubicación', style: textTheme.titleSmall),
                      const SizedBox(height: AdoptifySpacing.sm),
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

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report});

  final DogReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    return Scaffold(
      body: SingleChildScrollView(
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
                    Text('Mascota reportada', style: textTheme.headlineSmall?.copyWith(color: colors.reportText)),
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
                    Text('Ubicación', style: textTheme.titleSmall),
                    const SizedBox(height: AdoptifySpacing.sm),
                    _MiniMap(position: report.position, pin: MapPins.report),
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
