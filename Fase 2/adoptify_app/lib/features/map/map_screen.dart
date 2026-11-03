import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location_service.dart';
import '../../shared/map/map_controls.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'map_service.dart';

const _radiusOptions = [5, 10, 25, 50, 100];
// Sin tu ubicación, los reportes se buscan alrededor de Santiago con el radio máximo (igual que la web)
const _defaultReportsRadiusKm = 100;
// Radio de la tarjeta "avisos cerca tuyo"
const _alertsRadiusKm = 5;
// Espacio que ocupan el buscador (arriba) y el botón de reportar (abajo), para encuadrar los pines entre ellos
const _fitPadding = EdgeInsets.fromLTRB(48, 150, 72, 120);

// Mapa de mascotas disponibles y reportadas a pantalla completa: equivalente a la vista /usuario del portal.
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

  // Tarjeta de avisos: mascotas reportadas a menos de 5 km de tu ubicación.
  // La ubicación se pide sola al abrir el mapa; si no se obtiene, la tarjeta invita a activarla.
  LatLng? _userPosition;
  int? _alertsNearby;
  bool _detecting = true;
  bool _alertsLoading = false;

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
    if (_request == 0) {
      _load();
      _detectUser();
    }
  }

  // Ubicación para la tarjeta de avisos, sin mostrar errores: si falla, la tarjeta ofrece activarla
  Future<void> _detectUser() async {
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      _setUserPosition(position);
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  void _setUserPosition(LatLng position) {
    setState(() {
      _userPosition = position;
      _detecting = false;
    });
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final position = _userPosition;
    if (position == null) return;
    setState(() => _alertsLoading = true);
    try {
      final reports = await _service.fetchNearbyReports(position, _alertsRadiusKm);
      if (!mounted || position != _userPosition) return;
      setState(() {
        _alertsNearby = reports.length;
        _alertsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alertsNearby = null;
        _alertsLoading = false;
      });
    }
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
      if (mounted && request == _request) {
        setState(() => _reports = reports);
        _fitToPoints();
      }
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
      for (final report in _reports) report.position,
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
      _setUserPosition(position);
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildStatus()),
                            const SizedBox(width: AdoptifySpacing.sm),
                            Column(
                              children: [
                                _AlertsCard(
                                  count: _alertsNearby,
                                  loading: _detecting || _alertsLoading,
                                  hasLocation: _userPosition != null,
                                  onActivate: _locating ? null : _locate,
                                  onRetry: _loadAlerts,
                                ),
                                const SizedBox(height: AdoptifySpacing.sm),
                                _MatchButton(onPressed: () => context.push('/match')),
                              ],
                            ),
                          ],
                        ),
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
          // Atribución de OSM, mínima, en la franja bajo el botón de reportar (las fichas quedan sobre el botón)
          Positioned(right: AdoptifySpacing.md, bottom: 0, child: osmAttribution(context)),
          // Derecha: capas y ubicación. Suben cuando hay una ficha abierta, para no quedar debajo de ella.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            right: AdoptifySpacing.lg,
            bottom: selectedAnimal != null || selectedReport != null ? 260 : 96,
            child: Column(
              children: [
                MapButton(icon: Icons.layers_outlined, tooltip: 'Capas', onPressed: _openLayers),
                const SizedBox(height: AdoptifySpacing.md),
                MapButton(
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
                          ? _AnimalDetailCard(
                              animal: selectedAnimal,
                              onClose: _clearSelection,
                              onOpen: () => context.push('/animales/${selectedAnimal.id}', extra: selectedAnimal),
                            )
                          : _ReportDetailCard(
                              report: selectedReport!,
                              onClose: _clearSelection,
                              onOpen: () => context.push('/reportes/${selectedReport.id}', extra: selectedReport),
                            ),
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
    } else if (_origin == null && _animals.isNotEmpty) {
      // El conteo de mascotas se reemplazó por la tarjeta de avisos
      return const SizedBox.shrink();
    } else {
      final empty = _origin != null
          ? 'No hay mascotas disponibles a menos de $_radiusKm km. Prueba con un radio mayor.'
          : 'No hay mascotas disponibles por el momento.';
      content = Wrap(
        spacing: AdoptifySpacing.sm,
        runSpacing: AdoptifySpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_animals.isEmpty) Text(empty, style: muted),
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
        decoration: mapSurface(context, radius: 99),
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
            // Un aviso de rescate debe poder tocarse incluso si coincide con una referencia comunal.
            if (_showReports)
              for (final report in _reports)
                mapMarker(
                  report.position,
                  MapPins.report,
                  key: ValueKey('report-${report.id}'),
                  onTap: () => _selectReport(report),
                ),
          ],
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

// Acceso al match de adopción: botón circular bajo la tarjeta de avisos.
// Degradado de la marca (naranja → rojo de reportes) para que destaque sobre el mapa.
class _MatchButton extends StatelessWidget {
  const _MatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Haz Match: mascotas en adopción según tus gustos',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.report],
          ),
          boxShadow: [
            BoxShadow(color: colors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withValues(alpha: 0.2),
            child: SizedBox.square(
              dimension: 80,
              // Margen interno para que el texto no toque el borde curvo del círculo
              child: Padding(
                padding: const EdgeInsets.all(AdoptifySpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, size: 18, color: Colors.white),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Haz Match!',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
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

// Superficie común de lo que flota sobre el mapa: mismo borde y sombra sutil
// Cuadrado con una huella y cuántas mascotas reportadas hay a menos de 5 km de ti
class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.count,
    required this.loading,
    required this.hasLocation,
    required this.onActivate,
    required this.onRetry,
  });

  final int? count;
  final bool loading;
  final bool hasLocation;
  final VoidCallback? onActivate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final List<Widget> lines;
    VoidCallback? onTap;
    if (loading) {
      lines = [const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))];
    } else if (hasLocation && count != null) {
      lines = [
        Text('x$count ${count == 1 ? 'aviso' : 'avisos'}', style: textTheme.titleSmall),
        Text('cerca tuyo', style: textTheme.bodySmall),
      ];
    } else if (hasLocation) {
      // No se pudieron consultar los avisos: tocar la tarjeta reintenta
      lines = [
        Text('Sin conexión', style: textTheme.labelMedium),
        Text('Reintentar', style: textTheme.bodySmall?.copyWith(color: colors.primaryDark)),
      ];
      onTap = onRetry;
    } else {
      lines = [
        Text('Activa tu', style: textTheme.labelMedium),
        Text('ubicación', style: textTheme.labelMedium),
      ];
      onTap = onActivate;
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: hasLocation && count != null ? '$count avisos a menos de $_alertsRadiusKm km' : null,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          child: Container(
            width: 104,
            padding: const EdgeInsets.all(AdoptifySpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
              border: Border.all(color: colors.border),
              boxShadow: AdoptifyShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: colors.primarySoft, shape: BoxShape.circle),
                  child: Icon(Icons.pets, size: 20, color: colors.primaryDark),
                ),
                const SizedBox(height: AdoptifySpacing.xs),
                ...lines,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: mapSurface(context, radius: AdoptifyRadius.md),
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
      decoration: mapSurface(context, radius: AdoptifyRadius.md),
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
                        [animal.publicZone, animal.summary, ?animal.foundationName].join(' · '),
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

// Acción principal del mapa: el mismo rojo del botón "Reportar mascota" de la web
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
              title: Text('Adopción · zonas aproximadas ($animalsCount)', style: textTheme.bodyMedium),
            ),
            SwitchListTile(
              value: showReports,
              onChanged: onReports,
              secondary: dot(colors.report),
              title: Text('Mascotas reportadas ($reportsCount)', style: textTheme.bodyMedium),
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

// Ficha que aparece al tocar un pin: reemplaza los popups del mapa web.
// Tocar la ficha (menos el botón de cerrar) abre la pantalla completa con la foto grande y todo el detalle.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children, required this.onClose, required this.onOpen, this.leading});

  final List<Widget> children;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.md, AdoptifySpacing.xs, AdoptifySpacing.lg),
      decoration: mapSurface(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AdoptifySpacing.md)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 20), tooltip: 'Cerrar'),
        ],
      ),
    );
  }
}

class _AnimalDetailCard extends StatelessWidget {
  const _AnimalDetailCard({required this.animal, required this.onClose, required this.onOpen});

  final Animal animal;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DetailCard(
      onClose: onClose,
      onOpen: onOpen,
      leading: AnimalPhoto(url: animal.photoUrl, size: 72),
      children: [
        Text(animal.name, style: textTheme.titleMedium),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(animal.summary, style: textTheme.bodyMedium),
        if (animal.foundationName != null)
          Text(animal.foundationName!, style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted)),
        Text(animal.publicZone),
        if (animal.withinRadius) ...[
          const SizedBox(height: AdoptifySpacing.xs),
          Text(
            'Dentro de tu radio de búsqueda',
            style: textTheme.labelLarge?.copyWith(color: context.colors.primaryDark),
          ),
        ],
      ],
    );
  }
}

class _ReportDetailCard extends StatelessWidget {
  const _ReportDetailCard({required this.report, required this.onClose, required this.onOpen});

  final DogReport report;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DetailCard(
      onClose: onClose,
      onOpen: onOpen,
      leading: report.photoUrl == null ? null : AnimalPhoto(url: report.photoUrl, size: 72),
      children: [
        Text('Mascota reportada', style: textTheme.titleMedium?.copyWith(color: context.colors.reportText)),
        const SizedBox(height: AdoptifySpacing.xs),
        if (report.summary.isNotEmpty) Text(report.summary, style: textTheme.titleSmall),
        if (report.conditionLabel.isNotEmpty) Text('Estado: ${report.conditionLabel}', style: textTheme.bodyMedium),
        if (report.features != null)
          Text(report.features!, style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(
          '“${report.description}”',
          style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
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
