import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location_service.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/adoptify_logo.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'map_service.dart';

const _radiusOptions = [5, 10, 25, 50, 100];
// Sin tu ubicación, los reportes se buscan alrededor de Santiago con el radio máximo (igual que la web)
const _defaultReportsRadiusKm = 100;

// Mapa de mascotas disponibles y perros reportados: equivalente a la vista /usuario del portal
class MapScreen extends StatefulWidget {
  // Cambia cuando se crea un reporte desde la app, para volver a cargar los datos
  const MapScreen({super.key, this.refreshKey});

  final Object? refreshKey;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  late final MapService _service = MapService(AuthScope.of(context).api);

  LatLng? _origin;
  int _radiusKm = 10;
  bool _locating = false;
  String? _geoError;

  List<Animal> _animals = [];
  List<DogReport> _reports = [];
  bool _loading = true;
  bool _error = false;
  int _request = 0;

  int? _selectedAnimalId;
  int? _selectedReportId;
  bool _mapReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_request == 0) _load();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Carga mascotas y reportes para la búsqueda actual. Si llega una respuesta vieja, se descarta.
  Future<void> _load() async {
    final request = ++_request;
    final origin = _origin;
    setState(() {
      _loading = true;
      _error = false;
    });

    // Si fallan los reportes, el mapa sigue funcionando sin ellos
    _service
        .fetchNearbyReports(origin ?? santiago, origin != null ? _radiusKm : _defaultReportsRadiusKm)
        .then((reports) {
      if (mounted && request == _request) setState(() => _reports = reports);
    }).catchError((_) {
      if (mounted && request == _request) setState(() => _reports = []);
    });

    try {
      final animals = origin != null
          ? await _service.fetchNearbyAnimals(origin, _radiusKm)
          : await _service.fetchAvailableAnimals();
      if (!mounted || request != _request) return;
      setState(() {
        _animals = animals;
        _loading = false;
      });
      _fitToPoints();
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _animals = [];
        _loading = false;
        _error = true;
      });
    }
  }

  // Encuadra el mapa para que se vean todas las mascotas y tu ubicación
  void _fitToPoints([int attempt = 0]) {
    if (!_mapReady || !mounted) return;
    // Al abrir la app el mapa puede no tener tamaño todavía: encuadrar así lo alejaría hasta el planeta
    // completo. Se reintenta en el siguiente cuadro (máximo 20 veces).
    final size = _mapController.camera.nonRotatedSize;
    if (size.width < 50 || size.height < 50) {
      if (attempt < 20) WidgetsBinding.instance.addPostFrameCallback((_) => _fitToPoints(attempt + 1));
      return;
    }
    final points = [
      for (final animal in _animals)
        if (animal.position != null) animal.position!,
      ?_origin,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(60), maxZoom: 16),
      );
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _geoError = null;
    });
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() {
        _origin = position;
        _selectedAnimalId = null;
        _selectedReportId = null;
        _locating = false;
      });
      _load();
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _geoError = error.message;
        _locating = false;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      _origin = null;
      _selectedAnimalId = null;
      _selectedReportId = null;
    });
    _load();
  }

  void _changeRadius(int? km) {
    if (km == null || km == _radiusKm) return;
    setState(() => _radiusKm = km);
    _load();
  }

  void _selectAnimal(Animal animal) {
    setState(() {
      _selectedAnimalId = animal.id;
      _selectedReportId = null;
    });
    if (animal.position != null && _mapReady) {
      _mapController.move(animal.position!, _mapController.camera.zoom);
    }
  }

  void _selectReport(DogReport report) {
    setState(() {
      _selectedReportId = report.id;
      _selectedAnimalId = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedAnimalId = null;
      _selectedReportId = null;
    });
  }

  String get _summary {
    final count = _animals.length;
    final noun = count == 1 ? 'mascota disponible' : 'mascotas disponibles';
    return _origin != null ? '$count $noun a menos de $_radiusKm km' : '$count $noun';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedAnimal = _animals.where((animal) => animal.id == _selectedAnimalId).firstOrNull;
    final selectedReport = _reports.where((report) => report.id == _selectedReportId).firstOrNull;

    return Scaffold(
      // El mapa es la pantalla principal: el header lleva el logo, centrado
      appBar: AppBar(title: const AdoptifyLogo(compact: true)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, 0, AdoptifySpacing.lg, AdoptifySpacing.md),
            child: Wrap(
              spacing: AdoptifySpacing.md,
              runSpacing: AdoptifySpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_origin != null) ...[
                  _RadiusSelector(value: _radiusKm, onChanged: _changeRadius),
                  OutlinedButton.icon(
                    onPressed: _clearLocation,
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Ver todas'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _locating ? null : _locate,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location, size: 20),
                    label: const Text('Usar mi ubicación'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                if (!_loading && !_error)
                  Text(_summary, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted)),
              ],
            ),
          ),
          if (_geoError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, 0, AdoptifySpacing.lg, AdoptifySpacing.md),
              child: MessageBox.error(message: _geoError!),
            ),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                Positioned(
                  left: AdoptifySpacing.md,
                  top: AdoptifySpacing.md,
                  child: _Legend(reportsCount: _reports.length, showOrigin: _origin != null),
                ),
                if (selectedAnimal != null || selectedReport != null)
                  Positioned(
                    left: AdoptifySpacing.md,
                    right: AdoptifySpacing.md,
                    bottom: AdoptifySpacing.md,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: selectedAnimal != null
                            ? _AnimalDetailCard(animal: selectedAnimal, onClose: _clearSelection)
                            : _ReportDetailCard(report: selectedReport!, onClose: _clearSelection),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 132, child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: santiago,
        initialZoom: 11,
        onTap: (_, _) => _clearSelection(),
        onMapReady: () {
          _mapReady = true;
          _fitToPoints();
        },
      ),
      children: [
        osmTileLayer(),
        MarkerLayer(
          markers: [
            if (_origin != null) mapMarker(_origin!, MapPins.origin),
            for (final report in _reports)
              mapMarker(
                report.position,
                MapPins.report,
                key: ValueKey('report-${report.id}'),
                onTap: () => _selectReport(report),
              ),
            // Las mascotas van al final para quedar sobre los reportes; la seleccionada, encima de todas
            for (final animal in _animals)
              if (animal.position != null && animal.id != _selectedAnimalId)
                mapMarker(
                  animal.position!,
                  MapPins.animal,
                  key: ValueKey('animal-${animal.id}'),
                  onTap: () => _selectAnimal(animal),
                ),
            for (final animal in _animals)
              if (animal.position != null && animal.id == _selectedAnimalId)
                mapMarker(
                  animal.position!,
                  MapPins.selectedAnimal,
                  key: ValueKey('animal-${animal.id}'),
                  onTap: () => _selectAnimal(animal),
                ),
          ],
        ),
        osmAttribution,
      ],
    );
  }

  Widget _buildList() {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No pudimos cargar las mascotas.', style: muted),
            const SizedBox(height: AdoptifySpacing.xs),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_animals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.xl),
          child: Text(
            _origin != null
                ? 'No hay mascotas disponibles a menos de $_radiusKm km. Prueba con un radio mayor.'
                : 'No hay mascotas disponibles por el momento.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AdoptifySpacing.md),
      itemCount: _animals.length,
      separatorBuilder: (_, _) => const SizedBox(width: AdoptifySpacing.md),
      itemBuilder: (context, index) {
        final animal = _animals[index];
        return _AnimalCard(
          animal: animal,
          selected: animal.id == _selectedAnimalId,
          onTap: () => _selectAnimal(animal),
        );
      },
    );
  }
}

// Superficie blanca común: mismo radio, borde y sombra sutil en todo el mapa
BoxDecoration _surface({Color border = AdoptifyColors.border, double width = 1}) => BoxDecoration(
  color: AdoptifyColors.surface,
  borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
  border: Border.all(color: border, width: width),
  boxShadow: AdoptifyShadows.soft,
);

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Radio', style: textTheme.titleSmall),
        const SizedBox(width: AdoptifySpacing.sm),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md),
          decoration: BoxDecoration(
            color: AdoptifyColors.surface,
            borderRadius: BorderRadius.circular(AdoptifyRadius.md),
            border: Border.all(color: AdoptifyColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              onChanged: onChanged,
              style: textTheme.bodyMedium,
              borderRadius: BorderRadius.circular(AdoptifyRadius.md),
              focusColor: Colors.transparent,
              items: [for (final km in _radiusOptions) DropdownMenuItem(value: km, child: Text('$km km'))],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.reportsCount, required this.showOrigin});

  final int reportsCount;
  final bool showOrigin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        border: Border.all(color: AdoptifyColors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LegendItem(color: AdoptifyColors.primary, label: 'Mascotas en adopción'),
          _LegendItem(color: AdoptifyColors.report, label: 'Perros reportados ($reportsCount)'),
          if (showOrigin) const _LegendItem(color: AdoptifyColors.origin, label: 'Tu ubicación'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AdoptifySpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AnimalPhoto extends StatelessWidget {
  const _AnimalPhoto({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.pets, color: AdoptifyColors.placeholder);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdoptifyRadius.md),
      child: Container(
        width: size,
        height: size,
        color: AdoptifyColors.muted,
        child: url == null ? fallback : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.animal, required this.selected, required this.onTap});

  final Animal animal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AdoptifyRadius.lg);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 264,
        decoration: _surface(
          border: selected ? AdoptifyColors.primary : AdoptifyColors.border,
          width: selected ? 2 : 1,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.md - 2),
              child: Row(
                children: [
                  _AnimalPhoto(url: animal.photoUrl, size: 64),
                  const SizedBox(width: AdoptifySpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                animal.name,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (animal.distanceKm != null) _Pill('${formatKm(animal.distanceKm!)} km'),
                          ],
                        ),
                        const SizedBox(height: AdoptifySpacing.xs),
                        Text(animal.summary, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
                        if (animal.foundationName != null)
                          Text(
                            animal.foundationName!,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: AdoptifyColors.placeholder),
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
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.sm, vertical: 3),
      decoration: BoxDecoration(color: AdoptifyColors.primarySoft, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdoptifyColors.primaryText, letterSpacing: 0),
      ),
    );
  }
}

// Ficha que aparece al tocar un pin: reemplaza los popups del mapa web
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children, required this.onClose, this.leading});

  final List<Widget> children;
  final VoidCallback onClose;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.md, AdoptifySpacing.xs, AdoptifySpacing.lg),
      decoration: _surface(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AdoptifySpacing.md)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 20), tooltip: 'Cerrar'),
        ],
      ),
    );
  }
}

class _AnimalDetailCard extends StatelessWidget {
  const _AnimalDetailCard({required this.animal, required this.onClose});

  final Animal animal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DetailCard(
      onClose: onClose,
      leading: _AnimalPhoto(url: animal.photoUrl, size: 72),
      children: [
        Text(animal.name, style: textTheme.titleMedium),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(animal.summary, style: textTheme.bodyMedium),
        if (animal.foundationName != null)
          Text(animal.foundationName!, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted)),
        if (animal.distanceKm != null) ...[
          const SizedBox(height: AdoptifySpacing.xs),
          Text(
            'A ${formatKm(animal.distanceKm!)} km de ti',
            style: textTheme.labelLarge?.copyWith(color: AdoptifyColors.primaryDark),
          ),
        ],
      ],
    );
  }
}

class _ReportDetailCard extends StatelessWidget {
  const _ReportDetailCard({required this.report, required this.onClose});

  final DogReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DetailCard(
      onClose: onClose,
      children: [
        Text('Perro reportado', style: textTheme.titleMedium?.copyWith(color: AdoptifyColors.reportText)),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(report.description, style: textTheme.bodyMedium),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          '${report.statusLabel} · ${formatDate(report.createdAt)}',
          style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted),
        ),
        if (report.distanceKm != null)
          Text(
            'A ${formatKm(report.distanceKm!)} km',
            style: textTheme.labelLarge?.copyWith(color: AdoptifyColors.reportText),
          ),
      ],
    );
  }
}
