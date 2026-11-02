import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location_service.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'map_service.dart';

const _radiusOptions = [5, 10, 25, 50, 100];
// Sin tu ubicación, los reportes se buscan alrededor de Santiago con el radio máximo (igual que la web)
const _defaultReportsRadiusKm = 100;
// Espacio que ocupan el buscador (arriba) y el botón de reportar (abajo), para encuadrar los pines entre ellos
const _fitPadding = EdgeInsets.fromLTRB(48, 150, 72, 120);

// Mapa de mascotas disponibles y perros reportados a pantalla completa: equivalente a la vista /usuario del portal.
// Encima flotan el buscador, los botones de capas y ubicación, y el botón para reportar.
class MapScreen extends StatefulWidget {
  // Cambia cuando se crea un reporte desde la app, para volver a cargar los datos
  const MapScreen({super.key, this.refreshKey});

  final Object? refreshKey;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
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

  // Capas visibles (botón de capas)
  bool _showAnimals = true;
  bool _showReports = true;

  int? _selectedAnimalId;
  int? _selectedReportId;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _searchFocus.addListener(() => setState(() {}));
  }

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
    _search.dispose();
    _searchFocus.dispose();
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
      _mapController.fitCamera(CameraFit.coordinates(coordinates: points, padding: _fitPadding, maxZoom: 16));
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
      _showAnimals = true;
    });
    if (animal.position != null && _mapReady) {
      _mapController.move(animal.position!, _mapController.camera.zoom);
    }
  }

  // Elegir un resultado del buscador: se cierra la búsqueda y se muestra la mascota en el mapa
  void _pickResult(Animal animal) {
    _search.clear();
    _searchFocus.unfocus();
    _selectAnimal(animal);
  }

  void _selectReport(DogReport report) {
    setState(() {
      _selectedReportId = report.id;
      _selectedAnimalId = null;
    });
  }

  void _clearSelection() {
    _searchFocus.unfocus();
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

  List<Animal> get _results {
    final query = _fold(_search.text.trim());
    if (query.isEmpty) return const [];
    return _animals
        .where((animal) => _fold('${animal.name} ${animal.species} ${animal.foundationName ?? ''}').contains(query))
        .take(5)
        .toList();
  }

  void _openLayers() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return _LayersSheet(
            animalsCount: _animals.length,
            reportsCount: _reports.length,
            showAnimals: _showAnimals,
            showReports: _showReports,
            showOrigin: _origin != null,
            onAnimals: (value) => update(() {
              _showAnimals = value;
              if (!value) _selectedAnimalId = null;
            }),
            onReports: (value) => update(() {
              _showReports = value;
              if (!value) _selectedReportId = null;
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAnimal = _animals.where((animal) => animal.id == _selectedAnimalId).firstOrNull;
    final selectedReport = _reports.where((report) => report.id == _selectedReportId).firstOrNull;
    final searching = _searchFocus.hasFocus && _search.text.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          // Arriba: buscador y estado de la búsqueda
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchBar(controller: _search, focusNode: _searchFocus),
                      if (searching)
                        _SearchResults(results: _results, onPick: _pickResult)
                      else ...[
                        const SizedBox(height: AdoptifySpacing.sm),
                        _buildStatus(),
                        if (_geoError != null) ...[
                          const SizedBox(height: AdoptifySpacing.sm),
                          MessageBox.error(message: _geoError!),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Derecha: capas y ubicación. Suben cuando hay una ficha abierta, para no quedar debajo de ella.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            right: AdoptifySpacing.lg,
            bottom: selectedAnimal != null || selectedReport != null ? 260 : 96,
            child: Column(
              children: [
                _MapButton(icon: Icons.layers_outlined, tooltip: 'Capas', onPressed: _openLayers),
                const SizedBox(height: AdoptifySpacing.md),
                _MapButton(
                  icon: _origin != null ? Icons.my_location : Icons.near_me_outlined,
                  tooltip: 'Usar mi ubicación',
                  active: _origin != null,
                  loading: _locating,
                  onPressed: _locating ? null : _locate,
                ),
              ],
            ),
          ),
          // Abajo: ficha de lo seleccionado y botón para reportar
          Positioned(
            left: AdoptifySpacing.lg,
            right: AdoptifySpacing.lg,
            bottom: AdoptifySpacing.lg,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedAnimal != null || selectedReport != null) ...[
                      selectedAnimal != null
                          ? _AnimalDetailCard(animal: selectedAnimal, onClose: _clearSelection)
                          : _ReportDetailCard(report: selectedReport!, onClose: _clearSelection),
                      const SizedBox(height: AdoptifySpacing.md),
                    ],
                    _ReportButton(onPressed: () => context.push('/reportar')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Chip bajo el buscador: cuántas mascotas hay, el radio y cómo volver a ver todas
  Widget _buildStatus() {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: context.colors.text);
    final Widget content;
    if (_loading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AdoptifySpacing.sm),
          Text('Buscando mascotas…', style: muted),
        ],
      );
    } else if (_error) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text('No pudimos cargar las mascotas.', style: muted)),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    } else {
      final empty = _origin != null
          ? 'No hay mascotas disponibles a menos de $_radiusKm km. Prueba con un radio mayor.'
          : 'No hay mascotas disponibles por el momento.';
      content = Wrap(
        spacing: AdoptifySpacing.sm,
        runSpacing: AdoptifySpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(_animals.isEmpty ? empty : _summary, style: muted),
          if (_origin != null) ...[
            _RadiusSelector(value: _radiusKm, onChanged: _changeRadius),
            TextButton.icon(
              onPressed: _clearLocation,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Ver todas'),
            ),
          ],
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.xs),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: _surface(context, radius: 99),
        child: content,
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        backgroundColor: context.colors.muted,
        initialCenter: santiago,
        initialZoom: 11,
        onTap: (_, _) => _clearSelection(),
        onMapReady: () {
          _mapReady = true;
          _fitToPoints();
        },
      ),
      children: [
        const OsmTileLayer(),
        MarkerLayer(
          markers: [
            if (_origin != null) mapMarker(_origin!, MapPins.origin),
            if (_showReports)
              for (final report in _reports)
                mapMarker(
                  report.position,
                  MapPins.report,
                  key: ValueKey('report-${report.id}'),
                  onTap: () => _selectReport(report),
                ),
            // Las mascotas van al final para quedar sobre los reportes; la seleccionada, encima de todas
            if (_showAnimals) ...[
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
          ],
        ),
        // La atribución de OSM va arriba a la derecha, bajo el buscador: abajo la taparían el botón y las fichas
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 112, right: AdoptifySpacing.lg),
          child: osmAttribution(context, alignment: Alignment.topRight),
        ),
      ],
    );
  }
}

// Búsqueda sin distinguir mayúsculas ni tildes
String _fold(String text) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

// Superficie común de lo que flota sobre el mapa: mismo borde y sombra sutil
BoxDecoration _surface(BuildContext context, {double radius = AdoptifyRadius.lg}) => BoxDecoration(
  color: context.colors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: context.colors.border),
  boxShadow: AdoptifyShadows.soft,
);

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _surface(context, radius: AdoptifyRadius.md),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar mascota o fundación',
          prefixIcon: Icon(Icons.search, color: context.colors.textMuted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: controller.clear,
                ),
          // El borde lo pone la tarjeta; el campo solo marca el foco
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdoptifyRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onPick});

  final List<Animal> results;
  final ValueChanged<Animal> onPick;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AdoptifySpacing.sm),
      clipBehavior: Clip.antiAlias,
      decoration: _surface(context, radius: AdoptifyRadius.md),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.lg),
              child: Text('No encontramos mascotas con ese nombre.', style: textTheme.bodyMedium),
            )
          : Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final animal in results)
                    ListTile(
                      leading: AnimalPhoto(url: animal.photoUrl, size: 40),
                      title: Text(animal.name, style: textTheme.titleSmall),
                      subtitle: Text(
                        [animal.summary, ?animal.foundationName].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                      onTap: () => onPick(animal),
                    ),
                ],
              ),
            ),
    );
  }
}

// Botón redondo flotante (capas, ubicación), como los controles de un mapa
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: active ? colors.primary : colors.surface,
          shape: CircleBorder(side: BorderSide(color: active ? colors.primary : colors.border)),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 22, color: active ? Colors.white : colors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Acción principal del mapa: el mismo rojo del botón "Reportar perro" de la web
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_location_alt, size: 22),
      label: const Text('Reportar mascota'),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)
              ? colors.reportStrong
              : colors.report,
        ),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdoptifyRadius.lg)),
        ),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(colors.report.withValues(alpha: 0.4)),
      ),
    );
  }
}

// Capas del mapa: leyenda de colores y qué mostrar
class _LayersSheet extends StatelessWidget {
  const _LayersSheet({
    required this.animalsCount,
    required this.reportsCount,
    required this.showAnimals,
    required this.showReports,
    required this.showOrigin,
    required this.onAnimals,
    required this.onReports,
  });

  final int animalsCount;
  final int reportsCount;
  final bool showAnimals;
  final bool showReports;
  final bool showOrigin;
  final ValueChanged<bool> onAnimals;
  final ValueChanged<bool> onReports;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    Widget dot(Color color) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AdoptifySpacing.sm, 0, AdoptifySpacing.sm, AdoptifySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg),
              child: Text('Capas del mapa', style: textTheme.titleMedium),
            ),
            SwitchListTile(
              value: showAnimals,
              onChanged: onAnimals,
              secondary: dot(colors.primary),
              title: Text('Mascotas en adopción ($animalsCount)', style: textTheme.bodyMedium),
            ),
            SwitchListTile(
              value: showReports,
              onChanged: onReports,
              secondary: dot(colors.report),
              title: Text('Perros reportados ($reportsCount)', style: textTheme.bodyMedium),
            ),
            if (showOrigin)
              ListTile(
                leading: dot(colors.origin),
                title: Text('Tu ubicación', style: textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        onChanged: onChanged,
        isDense: true,
        style: textTheme.labelLarge,
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        focusColor: Colors.transparent,
        items: [for (final km in _radiusOptions) DropdownMenuItem(value: km, child: Text('Radio $km km'))],
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
      decoration: _surface(context),
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
      leading: AnimalPhoto(url: animal.photoUrl, size: 72),
      children: [
        Text(animal.name, style: textTheme.titleMedium),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(animal.summary, style: textTheme.bodyMedium),
        if (animal.foundationName != null)
          Text(animal.foundationName!, style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted)),
        if (animal.distanceKm != null) ...[
          const SizedBox(height: AdoptifySpacing.xs),
          Text(
            'A ${formatKm(animal.distanceKm!)} km de ti',
            style: textTheme.labelLarge?.copyWith(color: context.colors.primaryDark),
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
      leading: report.photoUrl == null ? null : AnimalPhoto(url: report.photoUrl, size: 72),
      children: [
        Text('Perro reportado', style: textTheme.titleMedium?.copyWith(color: context.colors.reportText)),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(report.description, style: textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          '${report.statusLabel} · ${formatDate(report.createdAt)}',
          style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
        ),
        if (report.distanceKm != null)
          Text(
            'A ${formatKm(report.distanceKm!)} km',
            style: textTheme.labelLarge?.copyWith(color: context.colors.reportText),
          ),
      ],
    );
  }
}
