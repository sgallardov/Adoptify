import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/location_service.dart';
import '../../shared/external_links.dart';
import '../../shared/map/map_controls.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/foundation_avatar.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../foundations/foundation_service.dart';
import 'clinic_service.dart';
import 'map_service.dart';

const _radiusOptions = [5, 10, 25, 50, 100];
// Sin tu ubicación, los reportes se buscan alrededor de Santiago con el radio máximo (igual que la web)
const _defaultReportsRadiusKm = 100;
// Radio de la tarjeta "avisos cerca tuyo"
const _alertsRadiusKm = 5;
// Espacio que ocupan el buscador (arriba) y el botón de reportar (abajo), para encuadrar los pines entre ellos
const _fitPadding = EdgeInsets.fromLTRB(48, 150, 72, 120);
// Zoom al tocar "Usar mi ubicación": se ven las calles alrededor de tu posición
const _locateZoom = 16.0;
// Zoom al abrir el mapa centrado en tu ubicación: se ve tu barrio y los pines cercanos
const _userZoom = 14.0;
// Las veterinarias son cientos: con el mapa más alejado que esto se amontonarían y taparían todo
const _clinicsMinZoom = 13.0;

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
  // En la vista de fundación los detalles viven bajo /fundacion (HU-L)
  bool get _isFoundationView => AuthScope.of(context).user?.isFoundation ?? false;
  String get _base => _isFoundationView ? '/fundacion' : '';

  final _mapController = MapController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final MapService _service = MapService(AuthScope.of(context).api);
  late final FoundationService _foundationService = FoundationService(
    AuthScope.of(context).api,
  );
  late final ClinicService _clinicService = ClinicService(
    AuthScope.of(context).api,
  );

  LatLng? _origin;
  int _radiusKm = 10;
  bool _locating = false;
  // Tras "Usar mi ubicación" el mapa queda centrado en ti en vez de encuadrar todos los pines,
  // hasta que cambies el radio o vuelvas a ver todas
  bool _centerOnOrigin = false;
  // Al abrir, el mapa se centra en tu ubicación (sin filtrar por radio) en vez de encuadrar todo el país
  bool _centerOnUser = false;
  // Si moviste el mapa con el dedo, deja de reencuadrarse solo cuando llegan datos nuevos
  bool _autoFit = true;
  String? _geoError;

  List<DogReport> _reports = [];
  // Para el buscador: reportes a 100 km (aunque estén fuera del radio elegido) y mascotas en adopción
  List<DogReport> _searchReports = [];
  List<Animal> _animals = [];
  bool _loading = true;
  bool _error = false;
  int _request = 0;

  // Botón de avisos: mascotas reportadas a menos de 5 km de tu ubicación; al tocarlo se despliega la lista.
  // La ubicación se pide sola al abrir el mapa; si no se obtiene, el botón invita a activarla.
  LatLng? _userPosition;
  List<DogReport>? _alerts;
  bool _alertsOpen = false;
  bool _detecting = true;
  bool _alertsLoading = false;

  // Capas visibles (botón de capas)
  bool _showReports = true;
  bool _showClinics = true;

  int? _selectedReportId;
  // Reporte recién publicado desde /reportar (llega como refreshKey): al cargar se muestra y se selecciona
  int? _newReportId;
  int? _selectedClinicId;

  // Fundaciones: no tienen pin en el mapa; se cargan para el buscador (al elegir una se abre su perfil)
  List<Foundation> _foundations = [];
  // Veterinarias para emergencias (OpenStreetMap): también pines fijos
  List<VetClinic> _clinics = [];
  // Si el zoom actual alcanza para mostrar las veterinarias (ver _clinicsMinZoom)
  bool _clinicsInView = false;
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
      _newReportId = _reportIdOf(widget.refreshKey);
      _load();
      _detectInitialLocation();
      _loadFoundations();
      _loadSearchData();
    }
  }

  // Si falla, el mapa sigue funcionando sin los pines de fundaciones
  // Si falla, el buscador sigue con lo que muestra el mapa
  Future<void> _loadSearchData() async {
    try {
      final reports = await _service.fetchNearbyReports(_userPosition ?? santiago, _defaultReportsRadiusKm);
      if (mounted) setState(() => _searchReports = reports);
    } catch (_) {}
    try {
      final animals = await _service.fetchAnimals();
      if (mounted) setState(() => _animals = [for (final a in animals) if (a.status != 'adopted') a]);
    } catch (_) {}
  }

  Future<void> _loadFoundations() async {
    try {
      final foundations = await _foundationService.fetchFoundations();
      if (mounted) setState(() => _foundations = foundations);
    } catch (_) {}
  }

  // Igual que las fundaciones: si falla, el mapa funciona sin las veterinarias
  Future<void> _loadClinics(LatLng origin, int radiusKm) async {
    try {
      final clinics = await _clinicService.fetchClinics(origin, radiusKm);
      if (mounted) setState(() => _clinics = clinics);
    } catch (_) {}
  }

  // Al abrir el mapa se pide la ubicación real para centrarlo ahí y buscar lo cercano con el radio
  // elegido. El mapa ya quedó cargado en Santiago desde _load(), así que esto solo recentra al llegar.
  // Sin permiso o sin señal, se queda en Santiago y aparece un aviso para reintentar.
  Future<void> _detectInitialLocation() async {
    try {
      final position = await currentLocation();
      if (!mounted) return;
      _centerOnUser = true;
      _setUserPosition(position);
      _fitToPoints();
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _geoError = error.message;
      });
      // Sin ubicación se encuadran las mascotas y reportes, como antes
      _fitToPoints();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _geoError = 'No pudimos obtener tu ubicación. Inténtalo nuevamente.';
      });
      _fitToPoints();
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
      final reports = await _service.fetchNearbyReports(
        position,
        _alertsRadiusKm,
      );
      if (!mounted || position != _userPosition) return;
      setState(() {
        _alerts = reports;
        _alertsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alerts = null;
        _alertsLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      _newReportId = _reportIdOf(widget.refreshKey);
      _load();
    }
  }

  static int? _reportIdOf(Object? refreshKey) => refreshKey is int ? refreshKey : null;

  // Tu reporte recién publicado se ve siempre, aunque quede fuera del radio elegido (el radio filtra
  // alrededor de tu ubicación, pero el punto del reporte se marca donde está la mascota). Se selecciona
  // y el mapa se mueve hasta él, para que veas que quedó publicado.
  Future<void> _showNewReport(int reportId, int request) async {
    var report = _reports.where((r) => r.id == reportId).firstOrNull;
    if (report == null) {
      try {
        report = await _service.fetchReport(reportId);
      } catch (_) {
        if (mounted && request == _request) _fitToPoints();
        return;
      }
      if (!mounted || request != _request) return;
    }
    final found = report;
    setState(() {
      if (!_reports.any((r) => r.id == found.id)) _reports = [..._reports, found];
      _showReports = true;
      _selectedReportId = found.id;
      _selectedClinicId = null;
      // Que un encuadre posterior (radio, ubicación) no lo saque de la vista
      _autoFit = false;
    });
    if (_mapReady) {
      final zoom = _mapController.camera.zoom;
      _mapController.move(found.position, zoom < _userZoom ? _userZoom : zoom);
    }
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


    // Las veterinarias se consultan por cercanía igual que reportes y mascotas.
    // Si fallan, el resto del mapa sigue funcionando.
    _loadClinics(origin ?? santiago, origin != null ? _radiusKm : _defaultReportsRadiusKm);

    try {
      final reports = await _service.fetchNearbyReports(
        origin ?? santiago,
        origin != null ? _radiusKm : _defaultReportsRadiusKm,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
      final newReportId = _newReportId;
      _newReportId = null;
      if (newReportId != null) {
        await _showNewReport(newReportId, request);
      } else {
        _fitToPoints();
      }
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _reports = [];
        _loading = false;
        _error = true;
      });
    }
  }

  // Encuadra el mapa para que se vean los reportes, las fundaciones y tu ubicación
  void _fitToPoints([int attempt = 0]) {
    if (!_mapReady || !mounted || !_autoFit) return;
    // Mientras se espera la ubicación no se encuadra el país entero: el mapa saltaría al llegar
    if (_detecting && _origin == null) return;
    // Al abrir la app el mapa puede no tener tamaño todavía: encuadrar así lo alejaría hasta el planeta
    // completo. Se reintenta en el siguiente cuadro (máximo 20 veces).
    final size = _mapController.camera.nonRotatedSize;
    if (size.width < 50 || size.height < 50) {
      if (attempt < 20)
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fitToPoints(attempt + 1),
        );
      return;
    }
    final origin = _origin;
    if (_centerOnOrigin && origin != null) {
      _mapController.move(origin, _locateZoom);
      return;
    }
    final user = _userPosition;
    if (_centerOnUser && _origin == null && user != null) {
      _mapController.move(user, _userZoom);
      return;
    }
    final points = [
      // HU-R: el encuadre considera los reportes; las mascotas en adopción y las fundaciones no tienen pin
      for (final report in _reports) report.position,
      ?_origin,
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: _fitPadding,
          maxZoom: 16,
        ),
      );
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _geoError = null;
    });
    try {
      final position = await currentLocation();
      if (!mounted) return;
      _setUserPosition(position);
      setState(() {
        _origin = position;
        _centerOnOrigin = true;
        _autoFit = true;
          _selectedReportId = null;
        _selectedClinicId = null;
        _locating = false;
      });
      // Se centra al tiro, sin esperar a que lleguen las mascotas y reportes del radio
      _fitToPoints();
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
      _centerOnOrigin = false;
      // "Ver todas": se encuadran todas las mascotas y reportes
      _centerOnUser = false;
      _autoFit = true;
      _selectedReportId = null;
      _selectedClinicId = null;
    });
    _load();
  }

  void _changeRadius(int? km) {
    if (km == null || km == _radiusKm) return;
    // Con otro radio se encuadran los resultados para verlos todos
    setState(() {
      _radiusKm = km;
      _centerOnOrigin = false;
      _autoFit = true;
    });
    _load();
  }

  // HU-X: elegir un resultado cierra la búsqueda, enciende su capa, centra el mapa y abre su tarjeta
  void _pickResult(_SearchHit hit) {
    _search.clear();
    _searchFocus.unfocus();
    var zoom = _mapReady ? _mapController.camera.zoom : _clinicsMinZoom;
    switch (hit.item) {
      case final Animal animal:
        // Las mascotas en adopción no tienen pin (HU-R): se abre su ficha
        context.push('$_base/animales/${animal.id}', extra: animal);
        return;
      case final DogReport report:
        setState(() {
          _showReports = true;
          // Un reporte fuera del radio elegido se agrega para que se vea su pin y su tarjeta
          if (!_reports.any((r) => r.id == report.id)) _reports = [..._reports, report];
        });
        _selectReport(report);
      case final Foundation foundation:
        // Las fundaciones no tienen pin: se abre su perfil, como desde la pestaña Fundaciones
        context.push(
          _isFoundationView ? '/fundacion/directorio/${foundation.id}' : '/fundaciones/${foundation.id}',
          extra: foundation,
        );
        return;
      case final VetClinic clinic:
        // Las veterinarias solo se dibujan con zoom cercano: se acerca lo justo para verla
        if (zoom < _clinicsMinZoom) zoom = _clinicsMinZoom;
        setState(() {
          _showClinics = true;
          _clinicsInView = true;
        });
        _selectClinic(clinic);
    }
    if (_mapReady) _mapController.move(hit.position, zoom);
  }

  // Enter en el buscador elige el primer resultado; sin resultados la lista queda abierta con el aviso
  void _pickFirstResult(String _) {
    final first = _results.firstOrNull;
    if (first != null) {
      _pickResult(first);
    } else {
      _searchFocus.requestFocus();
    }
  }

  void _selectReport(DogReport report) {
    setState(() {
      _selectedReportId = report.id;
      _selectedClinicId = null;
    });
  }

  void _selectClinic(VetClinic clinic) {
    setState(() {
      _selectedClinicId = clinic.id;
      _selectedReportId = null;
    });
  }

  Future<void> _open(Uri url) => openExternal(context, url);

  // Al volver del detalle se relee el reporte: si una fundación lo tomó o deshizo la toma, se ve al tiro
  Future<void> _openReport(DogReport report) async {
    await context.push('$_base/reportes/${report.id}', extra: report);
    try {
      final fresh = await _service.fetchReport(report.id);
      if (!mounted) return;
      List<DogReport> swap(List<DogReport> list) => [for (final item in list) item.id == fresh.id ? fresh : item];
      setState(() {
        _reports = swap(_reports);
        if (_alerts != null) _alerts = swap(_alerts!);
      });
    } catch (_) {}
  }

  void _clearSelection() {
    _searchFocus.unfocus();
    setState(() {
      _selectedReportId = null;
      _selectedClinicId = null;
    });
  }

  // HU-X: busca por palabras (todas deben aparecer, en cualquier orden y sin tildes ni mayúsculas)
  // en reportes, fundaciones y veterinarias cargados en el mapa
  List<_SearchHit> get _results {
    final words = _fold(_search.text).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    bool matches(String text) {
      final folded = _fold(text);
      return words.every(folded.contains);
    }

    final reports = {for (final r in _searchReports) r.id: r, for (final r in _reports) r.id: r}.values;
    return [
      for (final report in reports)
        if (matches(_reportSearchText(report)))
          _SearchHit(
            kind: _HitKind.report,
            title: report.summary.isEmpty ? 'Mascota reportada' : report.summary,
            subtitle: [report.careLabel, if (report.conditionLabel.isNotEmpty) report.conditionLabel].join(' · '),
            position: report.position,
            item: report,
          ),
      for (final foundation in _foundations)
        if (matches('${foundation.name} ${foundation.place}'))
          _SearchHit(
            kind: _HitKind.foundation,
            title: foundation.name,
            subtitle: foundation.place,
            position: foundation.position ?? santiago,
            item: foundation,
          ),
      for (final clinic in _clinics)
        if (matches('${clinic.name} ${clinic.place ?? ''}'))
          _SearchHit(
            kind: _HitKind.clinic,
            title: clinic.name,
            subtitle: clinic.place ?? (clinic.emergency ? 'Urgencias' : ''),
            position: clinic.position,
            item: clinic,
          ),
      for (final animal in _animals)
        if (matches(_animalSearchText(animal)))
          _SearchHit(
            kind: _HitKind.animal,
            title: animal.name,
            subtitle: [animal.summary, ?animal.foundationName].join(' · '),
            position: animal.position ?? santiago,
            item: animal,
          ),
    ].take(_maxResults).toList();
  }

  void _openLegend() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (_) => const _LegendSheet(),
    );
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
            reportsCount: _reports.length,
            showReports: _showReports,
            clinicsCount: _clinics.length,
            clinicsInView: _clinicsInView,
            showClinics: _showClinics,
            showOrigin: _origin != null,
            onReports: (value) => update(() {
              _showReports = value;
              if (!value) _selectedReportId = null;
            }),
            onClinics: (value) => update(() {
              _showClinics = value;
              if (!value) _selectedClinicId = null;
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedReport = _reports
        .where((report) => report.id == _selectedReportId)
        .firstOrNull;
    final selectedClinic = _clinics
        .where((c) => c.id == _selectedClinicId)
        .firstOrNull;
    final hasSelection =
        selectedReport != null ||
        selectedClinic != null;
    final searching = _searchFocus.hasFocus && _search.text.trim().isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          // Arriba: buscador y estado de la búsqueda
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AdoptifySpacing.lg,
                AdoptifySpacing.sm,
                AdoptifySpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchBar(
                        controller: _search,
                        focusNode: _searchFocus,
                        onSubmitted: _pickFirstResult,
                      ),
                      // La lista cuenta como parte del campo: en web, presionar el mouse sobre un resultado ya no
                      // le quita el foco al buscador (lo que cerraba la lista antes de que llegara el clic).
                      // Tocar fuera de ambos sigue cerrándola.
                      if (searching)
                        TextFieldTapRegion(
                          child: _SearchResults(results: _results, onPick: _pickResult),
                        )
                      else ...[
                        const SizedBox(height: AdoptifySpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildStatus()),
                            const SizedBox(width: AdoptifySpacing.sm),
                            // Ancho máximo: con letra grande el texto se recorta en vez de desbordar la fila
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: _AlertsButton(
                                key: const ValueKey('alerts-button'),
                                count: _alerts?.length,
                                open: _alertsOpen,
                                loading: _detecting || _alertsLoading,
                                loadingLabel: _detecting ? 'Buscando tu ubicación…' : 'Buscando avisos…',
                                hasLocation: _userPosition != null,
                                onToggle: () =>
                                    setState(() => _alertsOpen = !_alertsOpen),
                                onActivate: _locating ? null : _locate,
                                onRetry: _loadAlerts,
                              ),
                            ),
                          ],
                        ),
                        if (_alertsOpen && _alerts != null) ...[
                          const SizedBox(height: AdoptifySpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _AlertsPanel(
                              reports: _alerts!,
                              onOpen: _openReport,
                              onClose: () =>
                                  setState(() => _alertsOpen = false),
                            ),
                          ),
                        ],
                        if (_geoError != null) ...[
                          const SizedBox(height: AdoptifySpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: MessageBox.error(message: _geoError!)),
                              TextButton(
                                onPressed: _locating ? null : _locate,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Atribución de OSM, mínima, en la franja bajo el botón de reportar (las fichas quedan sobre el botón)
          Positioned(
            right: AdoptifySpacing.md,
            bottom: 0,
            child: osmAttribution(context),
          ),
          // Derecha: capas y ubicación. Suben cuando hay una ficha abierta, para no quedar debajo de ella.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            right: AdoptifySpacing.lg,
            // La ficha de veterinaria (con botones) es más alta que la de un reporte
            bottom: selectedClinic != null
                ? 340
                : (hasSelection ? 260 : 96),
            child: Column(
              children: [
                MapButton(
                  icon: Icons.info_outline,
                  tooltip: 'Leyenda del mapa',
                  onPressed: _openLegend,
                ),
                const SizedBox(height: AdoptifySpacing.md),
                MapButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Capas',
                  onPressed: _openLayers,
                ),
                const SizedBox(height: AdoptifySpacing.md),
                MapButton(
                  icon: _origin != null
                      ? Icons.my_location
                      : Icons.near_me_outlined,
                  tooltip: 'Usar mi ubicación',
                  loadingTooltip: 'Buscando tu ubicación…',
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
                    if (selectedReport != null) ...[
                      _ReportDetailCard(
                        report: selectedReport,
                        onClose: _clearSelection,
                        onOpen: () => _openReport(selectedReport),
                      ),
                      const SizedBox(height: AdoptifySpacing.md),
                    ] else if (selectedClinic != null) ...[
                      _ClinicDetailCard(
                        clinic: selectedClinic,
                        onClose: _clearSelection,
                        onDirections: () => _open(selectedClinic.directionsUrl),
                        onCall: selectedClinic.phoneUrl == null
                            ? null
                            : () => _open(selectedClinic.phoneUrl!),
                      ),
                      const SizedBox(height: AdoptifySpacing.md),
                    ],
                    // La fundación gestiona reportes, no los crea (HU-L): el botón es solo de adoptantes
                    if (!_isFoundationView) _ReportButton(onPressed: () => context.push('/reportar')),
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
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AdoptifySpacing.sm),
          Flexible(
            child: Text('Buscando reportes…', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          ),
        ],
      );
    } else if (_error) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text('No pudimos cargar los reportes.', style: muted),
          ),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    } else if (_origin == null && _reports.isNotEmpty) {
      // El conteo de reportes se reemplazó por la tarjeta de avisos
      return const SizedBox.shrink();
    } else {
      final empty = _origin != null
          ? 'No hay mascotas reportadas a menos de $_radiusKm km. Prueba con un radio mayor.'
          : 'No hay mascotas reportadas por el momento.';
      content = Wrap(
        spacing: AdoptifySpacing.sm,
        runSpacing: AdoptifySpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_reports.isEmpty) Text(empty, style: muted),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AdoptifySpacing.md,
          vertical: AdoptifySpacing.xs,
        ),
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
        // Solo se redibuja al cruzar el zoom de las veterinarias, no en cada movimiento
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) _autoFit = false;
          final inView = camera.zoom >= _clinicsMinZoom;
          if (inView != _clinicsInView) {
            setState(() {
              _clinicsInView = inView;
              if (!inView) _selectedClinicId = null;
            });
          }
        },
        onMapReady: () {
          _mapReady = true;
          // Si tu reporte recién publicado llegó antes que el mapa, se centra en él
          final selected = _reports.where((r) => r.id == _selectedReportId).firstOrNull;
          if (!_autoFit && selected != null) {
            _mapController.move(selected.position, _userZoom);
          } else {
            _fitToPoints();
          }
        },
      ),
      children: [
        const OsmTileLayer(),
        MarkerLayer(
          markers: [
            if (_showClinics && _clinicsInView)
              for (final clinic in _clinics)
                dropMarker(
                  clinic.position,
                  clinic.id == _selectedClinicId
                      ? MapPins.selectedClinic
                      : MapPins.clinic,
                  key: ValueKey('clinic-${clinic.id}'),
                  onTap: () => _selectClinic(clinic),
                ),
            // Tu ubicación: la del botón o la detectada al abrir el mapa
            if ((_origin ?? _userPosition) != null) mapMarker((_origin ?? _userPosition)!, MapPins.origin),
            // Los avisos van al final para quedar encima de todo (HU-Q): se pueden tocar aunque haya
            // muchas veterinarias o coincidan con una referencia comunal.
            if (_showReports)
              for (final report in _reports)
                mapMarker(
                  report.position,
                  MapPins.reportFor(report.species, taken: report.isTaken),
                  key: ValueKey('report-${report.id}'),
                  onTap: () => _selectReport(report),
                ),
          ],
        ),
      ],
    );
  }
}

const _maxResults = 10;

String _animalSearchText(Animal animal) => [
      animal.name,
      animal.species,
      animal.size,
      animal.statusLabel,
      'adopcion',
      ?animal.breed,
      ?animal.gender,
      ?animal.foundationName,
      ?animal.commune,
      ?animal.description,
    ].join(' ');

// Todo lo que se puede buscar de un reporte: valores y sus etiquetas en español
String _reportSearchText(DogReport report) => [
      report.summary,
      report.careLabel,
      report.statusLabel,
      report.conditionLabel,
      ?report.species,
      ?report.size,
      ?report.features,
      ...report.conditions,
      ...report.behaviors,
      report.description,
    ].join(' ');

enum _HitKind {
  report('Reporte'),
  animal('En adopción'),
  foundation('Fundación'),
  clinic('Veterinaria');

  const _HitKind(this.label);
  final String label;
}

// Un resultado del buscador: su tipo, lo que se muestra y el elemento del mapa al que lleva
class _SearchHit {
  const _SearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.position,
    required this.item,
  });

  final _HitKind kind;
  final String title;
  final String subtitle;
  final LatLng position;
  final Object item;
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
// Botón chico con una huella y cuántas mascotas reportadas hay a menos de 5 km de ti. Al tocarlo se despliega la lista.
class _AlertsButton extends StatelessWidget {
  const _AlertsButton({
    super.key,
    required this.count,
    required this.open,
    required this.loading,
    required this.loadingLabel,
    required this.hasLocation,
    required this.onToggle,
    required this.onActivate,
    required this.onRetry,
  });

  final int? count;
  final bool open;
  final bool loading;
  // Texto junto al indicador de carga: dice qué se está esperando
  final String loadingLabel;
  final bool hasLocation;
  final VoidCallback onToggle;
  final VoidCallback? onActivate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final Widget content;
    VoidCallback? onTap;
    String? label;
    if (loading) {
      label = loadingLabel;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AdoptifySpacing.sm),
          Flexible(
            child: Text(loadingLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.labelMedium),
          ),
        ],
      );
    } else if (hasLocation && count != null) {
      label =
          '$count ${count == 1 ? 'aviso' : 'avisos'} a menos de $_alertsRadiusKm km';
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 18, color: colors.primaryDark),
          const SizedBox(width: AdoptifySpacing.xs),
          Text('$count', style: textTheme.titleSmall),
          Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: colors.textMuted,
          ),
        ],
      );
      onTap = onToggle;
    } else if (hasLocation) {
      // No se pudieron consultar los avisos: tocar el botón reintenta
      content = Text(
        'Reintentar',
        style: textTheme.labelMedium?.copyWith(color: colors.primaryDark),
      );
      onTap = onRetry;
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location, size: 16, color: colors.primaryDark),
          const SizedBox(width: AdoptifySpacing.xs),
          Flexible(
            child: Text('Activar ubicación', maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.labelMedium),
          ),
        ],
      );
      onTap = onActivate;
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: colors.border),
              boxShadow: AdoptifyShadows.soft,
            ),
            // widthFactor 1: la píldora mide lo justo de su contenido, no el ancho máximo que se le permite
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

// Lista desplegable de los avisos cercanos: cada fila abre el detalle del reporte. Alto limitado para no tapar el mapa.
class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.reports,
    required this.onOpen,
    required this.onClose,
  });

  final List<DogReport> reports;
  final ValueChanged<DogReport> onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;
    return Container(
      key: const ValueKey('alerts-panel'),
      width: 320,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: mapSurface(context, radius: AdoptifyRadius.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdoptifySpacing.lg,
              AdoptifySpacing.md,
              AdoptifySpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Avisos a menos de $_alertsRadiusKm km',
                    style: textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar avisos',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdoptifySpacing.lg,
                0,
                AdoptifySpacing.lg,
                AdoptifySpacing.lg,
              ),
              child: Text(
                'No hay mascotas reportadas cerca de ti.',
                style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AdoptifySpacing.sm),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return InkWell(
                    key: ValueKey('alert-${report.id}'),
                    onTap: () => onOpen(report),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdoptifySpacing.lg,
                        vertical: AdoptifySpacing.sm,
                      ),
                      child: Row(
                        children: [
                          AnimalPhoto(url: report.photoUrl, size: 48),
                          const SizedBox(width: AdoptifySpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.summary.isEmpty
                                      ? 'Mascota reportada'
                                      : report.summary,
                                  style: textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  [
                                    report.seenOnly ? 'Una fundación ya lo vio' : report.careLabel,
                                    if (report.distanceKm != null)
                                      'a ${formatKm(report.distanceKm!)} km',
                                  ].join(' · '),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colors.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: mapSurface(context, radius: AdoptifyRadius.md),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        // Tocar fuera del campo y de la lista (TextFieldTapRegion) cierra la búsqueda en web y en el teléfono
        onTapOutside: (_) => focusNode.unfocus(),
        decoration: InputDecoration(
          hintText: 'Buscar perro, gato, fundación, veterinaria…',
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

  final List<_SearchHit> results;
  final ValueChanged<_SearchHit> onPick;

  Widget _leading(BuildContext context, _SearchHit hit) => SizedBox.square(
        dimension: 40,
        child: Center(
          child: switch (hit.item) {
            final DogReport report => MapPins.reportFor(report.species, taken: report.isTaken),
            final Animal animal => AnimalPhoto(url: animal.photoUrl, size: 40),
            final Foundation foundation => FoundationAvatar(
                name: foundation.name,
                photoUrl: foundation.photoUrl,
                size: 40,
                color: context.colors.foundation,
              ),
            _ => Icon(Icons.local_hospital, color: context.colors.reportText),
          },
        ),
      );

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
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'No encontramos reportes, mascotas, fundaciones ni veterinarias con esas palabras.',
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          : Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final hit in results)
                      ListTile(
                        leading: _leading(context, hit),
                        title: Text(hit.title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          hit.subtitle.isEmpty ? hit.kind.label : '${hit.kind.label} · ${hit.subtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                        onTap: () => onPick(hit),
                      ),
                  ],
                ),
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
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)
              ? colors.reportStrong
              : colors.report,
        ),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          ),
        ),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(
          colors.report.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// Capas del mapa: leyenda de colores y qué mostrar
class _LayersSheet extends StatelessWidget {
  const _LayersSheet({
    required this.reportsCount,
    required this.showReports,
    required this.clinicsCount,
    required this.showClinics,
    required this.clinicsInView,
    required this.showOrigin,
    required this.onReports,
    required this.onClinics,
  });

  final int reportsCount;
  final bool showReports;
  final int clinicsCount;
  final bool showClinics;
  final bool clinicsInView;
  final bool showOrigin;
  final ValueChanged<bool> onReports;
  final ValueChanged<bool> onClinics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    Widget dot(Color color) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    // Con varias capas no cabe en pantallas bajas: se desplaza en vez de cortarse
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AdoptifySpacing.sm,
          0,
          AdoptifySpacing.sm,
          AdoptifySpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdoptifySpacing.lg,
              ),
              child: Text('Capas del mapa', style: textTheme.titleMedium),
            ),
            SwitchListTile(
              value: showReports,
              onChanged: onReports,
              secondary: dot(colors.report),
              title: Text(
                'Mascotas reportadas ($reportsCount)',
                style: textTheme.bodyMedium,
              ),
            ),
            SwitchListTile(
              value: showClinics,
              onChanged: onClinics,
              secondary: Icon(
                Icons.local_hospital,
                size: 18,
                color: colors.report,
              ),
              title: Text(
                'Veterinarias ($clinicsCount)',
                style: textTheme.bodyMedium,
              ),
              subtitle: showClinics && !clinicsInView
                  ? Text(
                      'Acerca el mapa para verlas',
                      style: textTheme.bodySmall,
                    )
                  : null,
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
        items: [
          for (final km in _radiusOptions)
            DropdownMenuItem(value: km, child: Text('Radio $km km')),
        ],
      ),
    );
  }
}

// Ficha que aparece al tocar un pin: reemplaza los popups del mapa web.
// Tocar la ficha (menos el botón de cerrar) abre la pantalla completa con la foto grande y todo el detalle.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.children,
    required this.onClose,
    required this.onOpen,
    this.leading,
  });

  final List<Widget> children;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdoptifySpacing.lg,
        AdoptifySpacing.md,
        AdoptifySpacing.xs,
        AdoptifySpacing.lg,
      ),
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
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AdoptifySpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

// Qué significa cada pin, con los mismos dibujos del mapa. Se abre con el botón de información.
class _LegendSheet extends StatelessWidget {
  const _LegendSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(Widget pin, String title, String detail) => ListTile(
      leading: SizedBox(width: 48, child: Center(child: pin)),
      title: Text(title, style: textTheme.bodyMedium),
      subtitle: Text(detail, style: textTheme.bodySmall),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AdoptifySpacing.lg),
        child: Column(
          key: const ValueKey('map-legend'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.xl),
              child: Text('Qué significa cada pin', style: textTheme.titleMedium),
            ),
            row(MapPins.reportFor('perro'), 'Perro reportado', 'Un vecino lo vio en ese lugar.'),
            row(MapPins.reportFor('gato'), 'Gato reportado', 'Un vecino lo vio en ese lugar.'),
            row(MapPins.reportFor(null), 'Otra mascota reportada', 'Conejos, aves y otras especies.'),
            row(MapPins.reportFor('perro', taken: true), 'Caso tomado', 'Una fundación ya está atendiendo a esta mascota.'),
            row(MapPins.clinic, 'Veterinaria', 'Aparecen al acercar el mapa. Crece al tocarla.'),
            row(MapPins.origin, 'Tu ubicación', 'Solo si diste permiso para usarla.'),
          ],
        ),
      ),
    );
  }
}

// Ficha al tocar una veterinaria: nombre, dirección, si atiende urgencias y cómo llegar o llamar
class _ClinicDetailCard extends StatelessWidget {
  const _ClinicDetailCard({
    required this.clinic,
    required this.onClose,
    required this.onDirections,
    this.onCall,
  });

  final VetClinic clinic;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdoptifySpacing.lg,
        AdoptifySpacing.md,
        AdoptifySpacing.xs,
        AdoptifySpacing.lg,
      ),
      decoration: mapSurface(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_hospital, size: 20, color: colors.report),
                    const SizedBox(width: AdoptifySpacing.xs),
                    Text(
                      'Veterinaria',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.reportText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AdoptifySpacing.xs),
                Text(clinic.name, style: textTheme.titleMedium),
                if (clinic.place != null)
                  Text(
                    clinic.place!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                if (clinic.emergency) ...[
                  const SizedBox(height: AdoptifySpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdoptifySpacing.sm,
                      vertical: AdoptifySpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.reportStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Urgencias 24 h',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onAccent,
                      ),
                    ),
                  ),
                ] else if (clinic.openingHours != null) ...[
                  const SizedBox(height: AdoptifySpacing.xs),
                  Text(
                    'Horario: ${clinic.openingHours}',
                    style: textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AdoptifySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onDirections,
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Cómo llegar'),
                      ),
                    ),
                    if (onCall != null) ...[
                      const SizedBox(width: AdoptifySpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCall,
                          icon: const Icon(Icons.call_outlined, size: 18),
                          label: const Text('Llamar'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AdoptifySpacing.sm),
                // Datos de OpenStreetMap: pueden estar incompletos o desactualizados
                Text(
                  'Datos de OpenStreetMap. Confirma por teléfono antes de ir.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

class _ReportDetailCard extends StatelessWidget {
  const _ReportDetailCard({
    required this.report,
    required this.onClose,
    required this.onOpen,
  });

  final DogReport report;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _DetailCard(
      onClose: onClose,
      onOpen: onOpen,
      leading: report.photoUrl == null
          ? null
          : AnimalPhoto(url: report.photoUrl, size: 72),
      children: [
        Text(
          'Mascota reportada',
          style: textTheme.titleMedium?.copyWith(
            color: context.colors.reportText,
          ),
        ),
        const SizedBox(height: AdoptifySpacing.xs),
        if (report.summary.isNotEmpty)
          Text(report.summary, style: textTheme.titleSmall),
        if (report.conditionLabel.isNotEmpty)
          Text('Estado: ${report.conditionLabel}', style: textTheme.bodyMedium),
        if (report.features != null)
          Text(
            report.features!,
            style: textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          '“${report.description}”',
          style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AdoptifySpacing.xs),
        if (report.isTaken || report.seenOnly)
          Text(
            report.isTaken ? report.careLabel : 'Una fundación ya lo vio',
            style: textTheme.labelLarge?.copyWith(color: context.colors.success),
          ),
        Text(
          '${report.isTaken ? 'Reportado' : report.statusLabel} · ${formatDate(report.createdAt)}',
          style: textTheme.bodyMedium?.copyWith(
            color: context.colors.textMuted,
          ),
        ),
        if (report.distanceKm != null)
          Text(
            'A ${formatKm(report.distanceKm!)} km',
            style: textTheme.labelLarge?.copyWith(
              color: context.colors.reportText,
            ),
          ),
      ],
    );
  }
}
