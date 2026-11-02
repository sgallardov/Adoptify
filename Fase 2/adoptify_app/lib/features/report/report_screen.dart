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
import '../../shared/map/map_controls.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';

const _minDescription = 10;
const _maxDescription = 1000;
const _maxFeatures = 300;
const _maxWeightKg = 150;

// Reportar una mascota abandonada: equivalente a /reportar del portal.
// Primero se elige el punto en un mapa a pantalla completa y después se completan los demás pasos.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (!auth.loading && auth.user != null) return const _ReportForm();
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar mascota')),
      body: auth.loading ? const Center(child: CircularProgressIndicator()) : const _LoginRequired(),
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
              title: 'Reportar una mascota',
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
  final _color = TextEditingController();
  final _weight = TextEditingController();
  final _features = TextEditingController();
  final _description = TextEditingController();
  // Controla el mapa a pantalla completa; se crea uno nuevo cada vez que se vuelve a elegir el punto
  MapController _mapController = MapController();
  bool _mapReady = false;

  // Paso 1 (mapa a pantalla completa) hasta confirmar el punto; después, el formulario
  bool _pickingLocation = true;
  LatLng? _position;
  String? _species;
  String? _size;
  String? _condition;
  String? _behavior;
  bool _locating = false;
  bool _sending = false;
  String? _error;
  // Errores por campo (mismas claves que la API), como en el formulario web
  Map<String, String> _fieldErrors = {};

  // Foto opcional: se sube apenas se elige, para avisar enseguida si no sirve
  PickedPhoto? _photo;
  String? _photoUrl;
  bool _uploading = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    // Lo habitual es reportar donde uno está: se marca tu ubicación de partida, sin mostrar errores
    _locating = true;
    _locate(silent: true);
  }

  @override
  void dispose() {
    _color.dispose();
    _weight.dispose();
    _features.dispose();
    _description.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _place(LatLng position, {bool follow = false}) {
    setState(() => _position = position);
    // Al usar el GPS, el mapa se centra en el punto (igual que FollowValue en la web).
    // Si el mapa aún no está listo, lo centra onMapReady.
    if (follow && _mapReady) {
      _mapController.move(position, math.max(_mapController.camera.zoom, 16));
    }
  }

  void _onMapReady() {
    _mapReady = true;
    final position = _position;
    if (position != null) _mapController.move(position, math.max(_mapController.camera.zoom, 16));
  }

  Future<void> _locate({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _locating = true;
        _error = null;
      });
    }
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() => _locating = false);
      // Si la persona ya marcó un punto a mano mientras esperaba el GPS, no se lo cambiamos
      if (!silent || _position == null) _place(position, follow: true);
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = '${error.message} Toca el mapa para marcar el punto.';
        _locating = false;
      });
    }
  }

  void _confirmLocation() => setState(() {
        _pickingLocation = false;
        _error = null;
      });

  // Vuelve al mapa a pantalla completa conservando lo que ya se escribió
  void _changeLocation() {
    FocusScope.of(context).unfocus();
    _mapController.dispose();
    setState(() {
      _mapController = MapController();
      _mapReady = false;
      _pickingLocation = true;
      _error = null;
    });
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

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field)) setState(() => _fieldErrors.remove(field));
  }

  // Peso con coma o punto decimal; null si viene vacío
  double? get _weightKg {
    final text = _weight.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  Map<String, String> _validate() {
    final weight = _weightKg;
    return {
      if (_species == null) 'species': 'Selecciona el tipo de animal.',
      if (_size == null) 'size': 'Selecciona el tamaño.',
      if (_color.text.trim().length < 2) 'color': 'Indica el color (por ejemplo, café o negro con blanco).',
      if (_weight.text.trim().isNotEmpty && (weight == null || weight <= 0 || weight > _maxWeightKg))
        'weight_kg': 'Indica un peso aproximado entre 0 y $_maxWeightKg kg.',
      if (_condition == null) 'condition': 'Selecciona cómo se encuentra.',
      if (_description.text.trim().length < _minDescription)
        'description': 'Cuéntanos la situación con al menos $_minDescription caracteres.',
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        _error = 'Revisa los campos indicados antes de enviar.';
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final features = _features.text.trim();
      final report = await MapService(AuthScope.of(context).api).createReport(
        NewReport(
          position: _position!,
          species: _species!,
          size: _size!,
          color: _color.text.trim(),
          condition: _condition!,
          description: _description.text.trim(),
          weightKg: _weightKg,
          features: features.isEmpty ? null : features,
          behavior: _behavior,
          photoUrl: _photoUrl,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('¡Gracias! Tu reporte quedó publicado en el mapa.')));
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
    // Desde el formulario, "volver" regresa al mapa para cambiar el punto; desde el mapa, sale del reporte
    return PopScope(
      canPop: _pickingLocation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _changeLocation();
      },
      child: _pickingLocation
          ? _buildPicker(context)
          : Scaffold(appBar: AppBar(title: const Text('Reportar mascota')), body: _buildForm(context)),
    );
  }

  // Paso 1: mapa a pantalla completa para marcar dónde está la mascota
  Widget _buildPicker(BuildContext context) {
    final position = _position;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                backgroundColor: context.colors.muted,
                initialCenter: position ?? santiago,
                initialZoom: position == null ? 12 : 16,
                onTap: (_, point) => _place(point),
                onMapReady: _onMapReady,
              ),
              children: [
                const OsmTileLayer(),
                if (position != null)
                  MarkerLayer(markers: [mapMarker(position, MapPins.reportPicker, key: const ValueKey('picker'))]),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MapButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AdoptifySpacing.sm),
                      Expanded(child: _PickerHint(marked: position != null)),
                    ],
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MapButton(
                      icon: Icons.my_location,
                      tooltip: 'Usar mi ubicación',
                      loading: _locating,
                      onPressed: _locating ? null : _locate,
                    ),
                  ),
                  const SizedBox(height: AdoptifySpacing.md),
                  if (_error != null) ...[MessageBox.error(message: _error!), const SizedBox(height: AdoptifySpacing.md)],
                  FilledButton.icon(
                    onPressed: position == null ? null : _confirmLocation,
                    icon: const Icon(Icons.check, size: 22),
                    label: const Text('Confirmar ubicación'),
                    style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.fromHeight(56))),
                  ),
                  osmAttribution(context, alignment: Alignment.centerRight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pasos 2 a 5, con el punto ya elegido
  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: context.colors.textMuted);
    final position = _position!;

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
              'AYUDA A UNA MASCOTA',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(color: context.colors.primaryDark),
            ),
            const SizedBox(height: AdoptifySpacing.xs),
            Text('Reportar mascota', textAlign: TextAlign.center, style: textTheme.headlineSmall),
            const SizedBox(height: AdoptifySpacing.sm),
            Text(
              'Cuéntanos cómo es y cómo está. Las fundaciones cercanas podrán verlo. '
              'Los campos con * son obligatorios.',
              textAlign: TextAlign.center,
              style: muted,
            ),
            const SizedBox(height: AdoptifySpacing.xl),
            _Section(
              title: '1. ¿Dónde está? *',
              children: [
                // Vista previa del punto elegido; se cambia volviendo al mapa a pantalla completa
                Container(
                  height: 140,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
                  ),
                  child: IgnorePointer(
                    child: FlutterMap(
                      key: ValueKey(position),
                      options: MapOptions(
                        backgroundColor: context.colors.muted,
                        initialCenter: position,
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        const OsmTileLayer(),
                        MarkerLayer(markers: [mapMarker(position, MapPins.reportPicker, key: const ValueKey('picker'))]),
                        osmAttribution(context),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AdoptifySpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _sending ? null : _changeLocation,
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
                    label: const Text('Cambiar ubicación'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            _Section(
              title: '2. ¿Cómo es?',
              children: [
                _Choices(
                  label: 'Tipo de animal *',
                  options: reportSpecies,
                  value: _species,
                  error: _fieldErrors['species'],
                  onSelected: (value) => setState(() {
                    _species = value;
                    _fieldErrors.remove('species');
                  }),
                ),
                const SizedBox(height: AdoptifySpacing.lg),
                _Choices(
                  label: 'Tamaño *',
                  options: reportSizes,
                  value: _size,
                  error: _fieldErrors['size'],
                  onSelected: (value) => setState(() {
                    _size = value;
                    _fieldErrors.remove('size');
                  }),
                ),
                const SizedBox(height: AdoptifySpacing.lg),
                TextField(
                  key: const ValueKey('report-color'),
                  controller: _color,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _clearError('color'),
                  decoration: InputDecoration(
                    labelText: 'Color *',
                    hintText: 'Ej.: café con blanco',
                    errorText: _fieldErrors['color'],
                    errorMaxLines: 2,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AdoptifySpacing.md),
                TextField(
                  key: const ValueKey('report-weight'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => _clearError('weight_kg'),
                  decoration: InputDecoration(
                    labelText: 'Peso aproximado (opcional)',
                    hintText: 'Ej.: 12',
                    suffixText: 'kg',
                    errorText: _fieldErrors['weight_kg'],
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: AdoptifySpacing.md),
                TextField(
                  key: const ValueKey('report-features'),
                  controller: _features,
                  maxLength: _maxFeatures,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Características (opcional)',
                    hintText: 'Ej.: collar rojo sin placa, mancha en un ojo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            _Section(
              title: '3. ¿Cómo está?',
              children: [
                _Choices(
                  label: 'Estado *',
                  options: reportConditions,
                  value: _condition,
                  error: _fieldErrors['condition'],
                  onSelected: (value) => setState(() {
                    _condition = value;
                    _fieldErrors.remove('condition');
                  }),
                ),
                const SizedBox(height: AdoptifySpacing.lg),
                // Opcional: tocar de nuevo la opción elegida la desmarca
                _Choices(
                  label: 'Comportamiento al acercarse (opcional)',
                  options: reportBehaviors,
                  value: _behavior,
                  optional: true,
                  onSelected: (value) => setState(() => _behavior = value),
                ),
              ],
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            _Section(
              title: '4. Comentarios *',
              children: [
                TextField(
                  key: const ValueKey('report-comments'),
                  controller: _description,
                  maxLines: 4,
                  maxLength: _maxDescription,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _clearError('description'),
                  decoration: InputDecoration(
                    hintText:
                        'Cuéntanos la situación: desde cuándo lo ves, si alguien lo cuida, si está en un lugar peligroso…',
                    hintMaxLines: 3,
                    errorText: _fieldErrors['description'],
                    errorMaxLines: 2,
                  ),
                ),
                const SizedBox(height: AdoptifySpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AdoptifySpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.muted,
                    borderRadius: BorderRadius.circular(AdoptifyRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: context.colors.textMuted),
                      const SizedBox(width: AdoptifySpacing.sm),
                      Expanded(
                        child: Text(
                          'El reporte muestra la ubicación, los datos de la mascota, tus comentarios y la foto. '
                          'Tu nombre y tus datos no se publican.',
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
              title: '5. Foto (opcional)',
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
                  semanticLabel: 'Foto de la mascota',
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: context.colors.muted,
                    child: Icon(Icons.image_outlined, color: context.colors.placeholder),
                  ),
                ),
                if (uploading)
                  ColoredBox(
                    color: context.colors.text.withValues(alpha: 0.45),
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
              color: uploading ? context.colors.textMuted : context.colors.success,
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

// Indicación sobre el mapa a pantalla completa
class _PickerHint extends StatelessWidget {
  const _PickerHint({required this.marked});

  final bool marked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg, vertical: AdoptifySpacing.md),
      decoration: mapSurface(context, radius: AdoptifyRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿Dónde está la mascota?', style: textTheme.titleSmall),
          Text(
            marked ? 'Punto marcado. Toca otro lugar para moverlo.' : 'Toca el mapa para marcar el punto.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// Opciones como chips: se eligen de un toque. Si es opcional, tocar la elegida la desmarca.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.error,
    this.optional = false,
  });

  final String label;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String?> onSelected;
  final String? error;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AdoptifySpacing.sm),
        Wrap(
          spacing: AdoptifySpacing.sm,
          runSpacing: AdoptifySpacing.sm,
          children: [
            for (final MapEntry(key: option, value: text) in options.entries)
              ChoiceChip(
                label: Text(text),
                selected: value == option,
                onSelected: (selected) {
                  if (selected) {
                    onSelected(option);
                  } else if (optional) {
                    onSelected(null);
                  }
                },
              ),
          ],
        ),
        _FieldError(error),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AdoptifySpacing.sm),
      child: Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.reportText)),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: context.colors.border),
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
