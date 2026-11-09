import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// Path de latlong2 chocaría con el Path de Flutter que dibuja el pin de fundación
import 'package:latlong2/latlong.dart' hide Path;

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

// La licencia de OpenStreetMap exige mostrar "© OpenStreetMap" sobre el mapa: se deja lo más discreta posible
Widget osmAttribution(BuildContext context, {Alignment alignment = Alignment.bottomRight}) => Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(AdoptifySpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.xs),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AdoptifyRadius.sm),
        ),
        child: Text(
          '© OpenStreetMap',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
        ),
      ),
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
  // Reporte según la especie: perro y gato llevan su huella en blanco sobre el mismo rojo; "otro" es el punto
  static Widget reportFor(String? species) => switch (species) {
        'perro' => const ReportPin(paw: Icon(Icons.pets, size: 16, color: Colors.white)),
        'gato' => const ReportPin(paw: CustomPaint(size: Size.square(16), painter: CatPawPainter(Colors.white))),
        _ => report,
      };

  // Más grandes que los puntos de mascotas (20) y reportes (18) para que las sedes se noten
  static const foundation = DropPin(width: 46, kind: DropKind.foundation);
  static const selectedFoundation = DropPin(width: 56, kind: DropKind.foundation);
  // Veterinarias: mismo tamaño que las fundaciones, gota roja con una cruz roja sobre blanco
  static const clinic = DropPin(width: 46, kind: DropKind.clinic);
  static const selectedClinic = DropPin(width: 56, kind: DropKind.clinic);
}

// Reporte de un perro o un gato: círculo rojo de reportes con borde blanco y la huella de la especie adentro
class ReportPin extends StatelessWidget {
  const ReportPin({super.key, required this.paw});

  final Widget paw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdoptifyColors.light.report,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: paw,
    );
  }
}

// Manito de gato: almohadilla de tres lóbulos y cuatro dedos redondos y juntos, distinta de la huella
// de perro (Icons.pets, dedos alargados)
class CatPawPainter extends CustomPainter {
  const CatPawPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    // Almohadilla: óvalo arriba y tres lóbulos abajo
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.64), width: w * 0.56, height: h * 0.32), paint);
    for (final x in [0.34, 0.5, 0.66]) {
      canvas.drawCircle(Offset(w * x, h * 0.76), w * 0.15, paint);
    }
    // Dedos
    for (final toe in const [Offset(0.17, 0.4), Offset(0.37, 0.2), Offset(0.63, 0.2), Offset(0.83, 0.4)]) {
      canvas.drawCircle(Offset(w * toe.dx, h * toe.dy), w * 0.12, paint);
    }
  }

  @override
  bool shouldRepaint(CatPawPainter oldDelegate) => oldDelegate.color != color;
}

// Pin de gota: con una huella marca la sede de una fundación y con una cruz roja, una veterinaria. Se distingue de los puntos de
// mascotas y reportes, y su punta queda justo sobre la ubicación (ver dropMarker).
enum DropKind { foundation, clinic }

class DropPin extends StatelessWidget {
  const DropPin({super.key, required this.width, required this.kind});

  final double width;
  final DropKind kind;

  double get height => width * 1.3;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      DropKind.foundation => AdoptifyColors.light.foundation,
      DropKind.clinic => AdoptifyColors.light.report,
    };
    final onColor = AdoptifyColors.light.onAccent;
    final symbol = width * 0.4;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DropPainter(color: color, border: onColor),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.only(top: width * 0.17),
            width: width * 0.66,
            height: width * 0.66,
            decoration: BoxDecoration(color: onColor, shape: BoxShape.circle),
            child: switch (kind) {
              DropKind.foundation => Icon(Icons.pets, size: symbol, color: color),
              DropKind.clinic => Center(
                  child: CustomPaint(size: Size.square(symbol), painter: _CrossPainter(color)),
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  const _DropPainter({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    // Círculo arriba y dos tangentes que bajan hasta la punta
    final path = Path()
      ..moveTo(radius, size.height)
      ..lineTo(radius - radius * 0.72, radius + radius * 0.7)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 2.36, 4.71, false)
      ..lineTo(radius, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_DropPainter oldDelegate) => oldDelegate.color != color || oldDelegate.border != border;
}

// Cruz de emergencia: dos barras gruesas con las puntas redondeadas
class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bar = size.width * 0.34;
    final radius = Radius.circular(bar * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH((size.width - bar) / 2, 0, bar, size.height), radius),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, (size.height - bar) / 2, size.width, bar), radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}

// Marcador de gota (fundaciones y veterinarias): la punta apunta al lugar (el pin queda sobre el punto)
Marker dropMarker(LatLng point, DropPin pin, {Key? key, VoidCallback? onTap}) => Marker(
      key: key,
      point: point,
      width: pin.width + 10,
      height: pin.height,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: pin),
      ),
    );

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


