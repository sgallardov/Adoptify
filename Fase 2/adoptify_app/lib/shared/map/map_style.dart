import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';

// Configuración compartida de los mapas: equivalente a components/mapTiles.ts del portal

const santiago = LatLng(-33.4489, -70.6693);

// Mosaicos públicos de OpenStreetMap (mismo proveedor que la web): gratis, sin API key, con política de uso justo
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// Capa de mosaicos de OpenStreetMap. La política de OSM pide identificar la app en cada petición.
// En modo oscuro se invierten los colores de los mismos mosaicos (sin cambiar de proveedor).
class OsmTileLayer extends StatefulWidget {
  const OsmTileLayer({super.key});

  @override
  State<OsmTileLayer> createState() => _OsmTileLayerState();
}

class _OsmTileLayerState extends State<OsmTileLayer> {
  // Si un mosaico falla (por ejemplo, sin red), flutter_map tampoco lo vuelve a pedir hasta que se mueve
  // el mapa. Se recarga la capa a los pocos segundos, con un máximo de intentos.
  static const _maxRetries = 5;
  final _reset = StreamController<void>.broadcast();
  Timer? _retry;
  int _retries = 0;
  // Un solo proveedor (y su cliente HTTP) para toda la vida de la capa, en vez de uno nuevo en cada build.
  // TileLayer lo libera al eliminarse.
  final _provider = NetworkTileProvider();

  // Al abrir, el mapa nace sin tamaño y luego se encuadra en los pines: durante ese primer segundo el zoom
  // oscila y flutter_map crea y descarta tandas de mosaicos, y algunos quedaban "cargando" para siempre hasta
  // mover el mapa. La capa se crea recién cuando el mapa tiene tamaño y lleva un momento quieto: una sola carga.
  bool _ready = false;
  Timer? _settle;
  StreamSubscription<MapEvent>? _events;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _events ??= MapController.of(context).mapEventStream.listen((_) => _waitUntilStill());
    _waitUntilStill();
  }

  void _waitUntilStill() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _ready) return;
      final size = MapController.of(context).camera.nonRotatedSize;
      if (size.width < 50 || size.height < 50) return _waitUntilStill();
      _events?.cancel();
      setState(() => _ready = true);
    });
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (_retry != null || _retries >= _maxRetries) return;
    _retry = Timer(const Duration(seconds: 3), () {
      _retry = null;
      _retries++;
      if (mounted) _reset.add(null);
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    _settle?.cancel();
    _events?.cancel();
    _reset.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return TileLayer(
      urlTemplate: _osmTiles,
      userAgentPackageName: 'cl.adoptify.adoptify_app',
      maxZoom: 19,
      tileBuilder: Theme.of(context).brightness == Brightness.dark ? darkModeTileBuilder : null,
      reset: _reset.stream,
      errorTileCallback: _onTileError,
      // Los mosaicos con error se descartan para que el siguiente intento los pida de nuevo
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      tileProvider: _provider,
    );
  }
}

// OpenStreetMap exige mostrar la atribución en el mapa
Widget osmAttribution(BuildContext context, {Alignment alignment = Alignment.bottomRight}) =>
    SimpleAttributionWidget(
      source: const Text('OpenStreetMap'),
      backgroundColor: context.colors.surface.withValues(alpha: 0.8),
      alignment: alignment,
    );

// Pin redondo con borde blanco, igual a dotIcon() del portal
class MapDot extends StatelessWidget {
  const MapDot({super.key, required this.color, required this.size, this.halo = false});

  final Color color;
  final double size;
  final bool halo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          const BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
          if (halo) BoxShadow(color: color.withValues(alpha: 0.25), spreadRadius: 6),
        ],
      ),
    );
  }
}

// Los pines usan los mismos colores en modo claro y oscuro, igual que en la web
class MapPins {
  static final animal = MapDot(color: AdoptifyColors.light.primary, size: 20);
  static final selectedAnimal = MapDot(color: AdoptifyColors.light.primaryText, size: 26);
  static final report = MapDot(color: AdoptifyColors.light.report, size: 18);
  static final reportPicker = MapDot(color: AdoptifyColors.light.report, size: 22);
  static final origin = MapDot(color: AdoptifyColors.dark.origin, size: 16, halo: true);
}

// Marcador centrado en el punto. El área táctil es más grande que el pin para tocarlo fácil con el dedo.
Marker mapMarker(LatLng point, Widget pin, {Key? key, VoidCallback? onTap}) => Marker(
      key: key,
      point: point,
      width: 44,
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: pin),
      ),
    );


