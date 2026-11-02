import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/photo_service.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';

const _minDescription = 10;
const _maxDescription = 1000;

// Formulario para reportar un perro abandonado: equivalente a /reportar del portal
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar mascota')),
      body: auth.loading
          ? const Center(child: CircularProgressIndicator())
          : auth.user == null
          ? const _LoginRequired()
          : const _ReportForm(),
    );
  }
}

// Igual que en la web, reportar requiere una cuenta (POST /reports pide token)
class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: Column(
        children: [
          const Expanded(
            child: ComingSoon(
              icon: Icons.add_location_alt,
              title: 'Reportar un perro abandonado',
              message: 'Inicia sesión para reportar. Tu nombre y tus datos no se publican.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdoptifySpacing.xl),
            child: FilledButton(onPressed: () => context.push('/login'), child: const Text('Iniciar sesión')),
          ),
        ],
      ),
    );
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _description = TextEditingController();
  final _mapController = MapController();

  LatLng? _position;
  bool _locating = false;
  bool _sending = false;
  String? _error;

  // Foto opcional: se sube apenas se elige, para avisar enseguida si no sirve
  PickedPhoto? _photo;
  String? _photoUrl;
  bool _uploading = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _place(LatLng position, {bool follow = false}) {
    setState(() => _position = position);
    // Al usar el GPS, el mapa se centra en el punto (igual que FollowValue en la web)
    if (follow) {
      _mapController.move(position, math.max(_mapController.camera.zoom, 16));
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() => _locating = false);
      _place(position, follow: true);
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '${error.message} Marca el punto en el mapa.';
        _locating = false;
      });
    }
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    final api = AuthScope.of(context).api;
    final PickedPhoto? photo;
    try {
      photo = await PhotoService.instance.pick(source);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _photoError = source == PhotoSource.camera
          ? 'No pudimos abrir la cámara. Revisa el permiso o elige una foto de la galería.'
          : 'No pudimos abrir la galería. Inténtalo nuevamente.');
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _photoUrl = null;
      _uploading = true;
      _photoError = null;
    });
    try {
      final url = await MapService(api).uploadPhoto(photo);
      if (!mounted || _photo != photo) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted || _photo != photo) return;
      setState(() {
        _photo = null;
        _uploading = false;
        _photoError = errorMessage(error, 'No se pudo subir la foto. Inténtalo nuevamente.');
      });
    }
  }

  void _removePhoto() => setState(() {
        _photo = null;
        _photoUrl = null;
        _uploading = false;
        _photoError = null;
      });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final position = _position;
    final description = _description.text.trim();
    if (position == null) {
      setState(() => _error = 'Marca en el mapa dónde está el perro.');
      return;
    }
    if (description.length < _minDescription) {
      setState(() => _error = 'Describe al perro con al menos $_minDescription caracteres.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final report = await MapService(AuthScope.of(context).api)
          .createReport(position, description, photoUrl: _photoUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('¡Gracias! Tu reporte quedó publicado en el mapa.')));
      setState(() {
        _sending = false;
        _position = null;
        _description.clear();
        _photo = null;
        _photoUrl = null;
      });
      // El id del reporte hace que el mapa vuelva a cargar los datos
      context.go('/mapa', extra: report.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No se pudo enviar el reporte. Inténtalo nuevamente.');
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AdoptifySpacing.lg,
        AdoptifySpacing.sm,
        AdoptifySpacing.lg,
        AdoptifySpacing.xxl,
      ),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado centrado
            Text(
              'AYUDA A UN PERRO',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(color: AdoptifyColors.primaryDark),
            ),
            const SizedBox(height: AdoptifySpacing.xs),
            Text('Reportar perro abandonado', textAlign: TextAlign.center, style: textTheme.headlineSmall),
            const SizedBox(height: AdoptifySpacing.sm),
            Text(
              'Marca en el mapa dónde viste al perro y cuéntanos cómo está. Las fundaciones cercanas podrán verlo.',
              textAlign: TextAlign.center,
              style: muted,
            ),
            const SizedBox(height: AdoptifySpacing.xl),
            _Section(
              title: '1. ¿Dónde está el perro?',
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _locate,
                      icon: _locating
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 20),
                      label: const Text('Usar mi ubicación'),
                    ),
                    const SizedBox(width: AdoptifySpacing.md),
                    Expanded(
                      child: Text(
                        _position != null
                            ? 'Punto marcado. Toca otro lugar del mapa para moverlo.'
                            : 'O toca el mapa para marcar el lugar.',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AdoptifySpacing.md),
                Container(
                  height: 320,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: AdoptifyColors.border),
                    borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: santiago, initialZoom: 12, onTap: (_, point) => _place(point)),
                    children: [
                      osmTileLayer(),
                      if (_position != null)
                        MarkerLayer(
                          markers: [mapMarker(_position!, MapPins.reportPicker, key: const ValueKey('picker'))],
                        ),
                      osmAttribution,
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            _Section(
              title: '2. Describe al perro y su estado',
              children: [
                TextField(
                  controller: _description,
                  maxLines: 4,
                  maxLength: _maxDescription,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'Ej.: perro mediano café, con collar rojo, parece herido de una pata. Está cerca del paradero.',
                    hintMaxLines: 3,
                  ),
                ),
                const SizedBox(height: AdoptifySpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AdoptifySpacing.md),
                  decoration: BoxDecoration(
                    color: AdoptifyColors.muted,
                    borderRadius: BorderRadius.circular(AdoptifyRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AdoptifyColors.textMuted),
                      const SizedBox(width: AdoptifySpacing.sm),
                      Expanded(
                        child: Text(
                          'El reporte muestra solo la ubicación del perro, la descripción y la foto. Tu nombre y tus datos no se publican.',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            _Section(
              title: '3. Foto del perro (opcional)',
              children: [
                if (_photo == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPhoto(PhotoSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined, size: 20),
                          label: const Text('Tomar foto'),
                        ),
                      ),
                      const SizedBox(width: AdoptifySpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPhoto(PhotoSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 20),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AdoptifySpacing.sm),
                  Text('Una foto ayuda a reconocerlo. JPG o PNG, hasta 5 MB.', style: textTheme.bodySmall),
                ] else
                  _PhotoPreview(photo: _photo!, uploading: _uploading, onRemove: _removePhoto),
                if (_photoError != null) ...[
                  const SizedBox(height: AdoptifySpacing.md),
                  MessageBox.error(message: _photoError!),
                ],
              ],
            ),
            if (_error != null) ...[const SizedBox(height: AdoptifySpacing.lg), MessageBox.error(message: _error!)],
            const SizedBox(height: AdoptifySpacing.xl),
            FilledButton.icon(
              onPressed: _sending || _uploading ? null : _submit,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 20),
              label: Text(_sending ? 'Enviando…' : 'Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }
}

// Vista previa de la foto elegida, con su estado de subida y el botón para quitarla
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photo, required this.uploading, required this.onRemove});

  final PickedPhoto photo;
  final bool uploading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AdoptifyRadius.md),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  photo.bytes,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto del perro',
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AdoptifyColors.muted,
                    child: Icon(Icons.image_outlined, color: AdoptifyColors.placeholder),
                  ),
                ),
                if (uploading)
                  ColoredBox(
                    color: AdoptifyColors.text.withValues(alpha: 0.45),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AdoptifySpacing.sm),
        Row(
          children: [
            Icon(
              uploading ? Icons.cloud_upload_outlined : Icons.check_circle,
              size: 18,
              color: uploading ? AdoptifyColors.textMuted : AdoptifyColors.success,
            ),
            const SizedBox(width: AdoptifySpacing.xs),
            Expanded(child: Text(uploading ? 'Subiendo foto…' : 'Foto lista', style: textTheme.bodySmall)),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Quitar foto'),
            ),
          ],
        ),
      ],
    );
  }
}

// Bloque del formulario: tarjeta blanca con título, mismo borde y sombra que el resto de la app
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: AdoptifyColors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: AdoptifyColors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AdoptifySpacing.md),
          ...children,
        ],
      ),
    );
  }
}
