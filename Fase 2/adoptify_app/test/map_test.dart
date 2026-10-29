import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';

Future<void> openMap(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mapa'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('sin ubicación muestra solo las mascotas disponibles y los reportes', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Rocky'), findsNothing);
    expect(find.text('1 mascota disponible'), findsOneWidget);
    expect(find.text('Perros reportados (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
    // Sin ubicación, los reportes se buscan alrededor de Santiago a 100 km
    final reportsRequest = api.requests.firstWhere((r) => r.url.path == '/reports/nearby');
    expect(reportsRequest.url.queryParameters['radius_km'], '100');
  });

  testWidgets('tocar una mascota o un reporte muestra su ficha', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tester.tap(find.byKey(const ValueKey('report-1')));
    await tester.pumpAndSettle();
    expect(find.text('Perro reportado'), findsOneWidget);
    expect(find.text('Perro café con collar rojo cerca del paradero'), findsOneWidget);
    expect(find.text('Reportado · 28-10-2026'), findsOneWidget);
    expect(find.text('A 2,5 km'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Perro reportado'), findsNothing);

    // La ficha de la mascota muestra su fundación (además de la tarjeta de la lista)
    await tester.tap(find.text('Luna'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsNWidgets(2));
  });

  testWidgets('con tu ubicación busca por cercanía y muestra la distancia', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    final nearby = api.requests.lastWhere((r) => r.url.path == '/animals/nearby');
    expect(nearby.url.queryParameters, {'lat': '-33.4378', 'lng': '-70.6505', 'radius_km': '10'});
    expect(find.text('1 mascota disponible a menos de 10 km'), findsOneWidget);
    expect(find.text('1,25 km'), findsOneWidget);
    expect(find.text('Tu ubicación'), findsOneWidget);

    await tester.tap(find.text('Ver todas'));
    await tester.pumpAndSettle();
    expect(find.text('1 mascota disponible'), findsOneWidget);
    expect(find.text('Usar mi ubicación'), findsOneWidget);
  });

  testWidgets('muestra el error de ubicación sin romper el mapa', (tester) async {
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    await openMap(tester, api);

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('No diste permiso para usar tu ubicación.'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
  });

  testWidgets('si la API falla permite reintentar', (tester) async {
    final api = FakeApi()..animalsFail = true;
    await openMap(tester, api);

    expect(find.text('No pudimos cargar las mascotas.'), findsOneWidget);

    api.animalsFail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
  });
}
