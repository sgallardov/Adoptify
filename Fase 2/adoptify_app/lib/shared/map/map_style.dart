import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';

// Configuración compartida de los mapas: equivalente a components/mapTiles.ts del portal

const santiago = LatLng(-33.4489, -70.6693);

// Mosaicos públicos de OpenStreetMap (mismo proveedor que la web): gratis, sin API key, con política de uso justo
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

// La política de OSM pide identificar la app en cada petición de mosaicos.
// En modo oscuro se invierten los colores de los mismos mosaicos (sin cambiar de proveedor).
TileLayer osmTileLayer(BuildContext context) => TileLayer(
      urlTemplate: _osmTiles,
      userAgentPackageName: 'cl.adoptify.adoptify_app',
      maxZoom: 19,
      tileBuilder: _isDark(context) ? darkModeTileBuilder : null,
    );

// OpenStreetMap exige mostrar la atribución en el mapa
Widget osmAttribution(BuildContext context) => SimpleAttributionWidget(
      source: const Text('OpenStreetMap'),
      backgroundColor: context.colors.surface.withValues(alpha: 0.8),
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
