import 'package:adoptify_app/features/map/map_service.dart';
import 'package:adoptify_app/shared/map/map_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'fake_api.dart';
import 'map_test.dart' show openMap;
import 'package:adoptify_app/core/location_service.dart';

// HU-Z: la app y el portal muestran los mismos reportes porque piden /reports/nearby con el mismo
// criterio. Acá se prueba el criterio de la app; su gemelo en el portal es tests/reportArea.test.mjs.
void main() {
  group('criterio común de búsqueda de reportes', () {
    test('es el mismo que el del portal (src/services/reportArea.ts)', () {
      expect(reportRadiusOptions, [5, 10, 25, 50, 100]);
      expect(defaultReportRadiusKm, 10);
      expect(noLocationReportRadiusKm, 100);
      expect(santiago, const LatLng(-33.4489, -70.6693));
      expect(reportRadiusOptions, contains(defaultReportRadiusKm));
    });

    test('con ubicación busca ahí con el radio elegido', () {
      final area = reportSearchArea(const LatLng(-33.45, -70.65), 25);
      expect(area.origin, const LatLng(-33.45, -70.65));
      expect(area.radiusKm, 25);
    });

    test('sin radio usa el radio por defecto, igual que el portal', () {
      final area = reportSearchArea(const LatLng(-36.82, -73.05));
      expect(area.origin, const LatLng(-36.82, -73.05));
      expect(area.radiusKm, defaultReportRadiusKm);
    });

    test('sin ubicación busca en Santiago con el radio máximo, aunque se haya elegido otro', () {
      for (final area in [reportSearchArea(null), reportSearchArea(null, 5)]) {
        expect(area.origin, santiago);
        expect(area.radiusKm, noLocationReportRadiusKm);
      }
    });
  });

  group('el mapa pide lo mismo que el portal', () {
    setUp(() => LocationService.instance = FakeLocation());
    tearDown(() => LocationService.instance = LocationService());

    testWidgets('con ubicación busca a 10 km de ti: los mismos parámetros que la sede de la fundación', (tester) async {
      const posicion = LatLng(-33.4378, -70.6505);
      LocationService.instance = FakeLocation(position: posicion);
      final api = FakeApi();
      await openMap(tester, api);

      // La última búsqueda del mapa (el buscador y los avisos usan sus propios radios, 100 y 5 km)
      final consultas = api.requests
          .where((request) => request.url.path == '/reports/nearby')
          .map((request) => request.url.queryParameters)
          .where((query) => query['radius_km'] == '$defaultReportRadiusKm')
          .toList();
      expect(consultas, isNotEmpty, reason: 'el mapa debe buscar con el radio por defecto');
      // Igual que el portal con reportSearchArea(sede): lat, lng y radius_km del mismo criterio
      final area = reportSearchArea(posicion);
      expect(double.parse(consultas.last['lat']!), closeTo(area.origin.latitude, 0.0001));
      expect(double.parse(consultas.last['lng']!), closeTo(area.origin.longitude, 0.0001));
      expect(consultas.last['radius_km'], '${area.radiusKm}');
    });
  });
}
