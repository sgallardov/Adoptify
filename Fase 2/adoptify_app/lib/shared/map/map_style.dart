import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';

// Configuración compartida de los mapas: equivalente a components/mapTiles.ts del portal

const santiago = LatLng(-33.4489, -70.6693);

// Mosaicos públicos de OpenStreetMap (mismo proveedor que la web): gratis, sin API key, con política de uso justo
const _osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// La política de OSM pide identificar la app en cada petición de mosaicos
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: _osmTiles,
      userAgentPackageName: 'cl.adoptify.adoptify_app',
      maxZoom: 19,
    );

// OpenStreetMap exige mostrar la atribución en el mapa
const osmAttribution = SimpleAttributionWidget(
  source: Text('OpenStreetMap'),
  backgroundColor: Color(0xCCFFFFFF),
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

class MapPins {
  static const animal = MapDot(color: AdoptifyColors.primary, size: 20);
  static const selectedAnimal = MapDot(color: AdoptifyColors.primaryText, size: 26);
  static const report = MapDot(color: AdoptifyColors.report, size: 18);
  static const reportPicker = MapDot(color: AdoptifyColors.report, size: 22);
  static const origin = MapDot(color: AdoptifyColors.origin, size: 16, halo: true);
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
