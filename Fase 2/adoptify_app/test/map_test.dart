import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/shared/map/map_controls.dart';

import 'fake_api.dart';

Future<void> openMap(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mapa'));
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('sin ubicación muestra solo las mascotas disponibles y los reportes', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-8')), findsNothing);
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
    expect(markers.singleWhere((m) => m.key == const ValueKey('report-1')).point, const LatLng(-33.44, -70.66));
    expect(markers.singleWhere((m) => m.key == const ValueKey('animal-7')).point, const LatLng(-33.46, -70.60));
    // Sin ubicación, los reportes se buscan alrededor de Santiago a 100 km
    final reportsRequest = api.requests.firstWhere((r) => r.url.path == '/reports/nearby');
    expect(reportsRequest.url.queryParameters['radius_km'], '100');
  });

  testWidgets('la tarjeta muestra los avisos a menos de 5 km de tu ubicación', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    expect(find.text('x1 aviso'), findsOneWidget);
    expect(find.text('cerca tuyo'), findsOneWidget);
    final alerts = api.requests.lastWhere((r) => r.url.path == '/reports/nearby');
    expect(alerts.url.queryParameters, {'lat': '-33.4378', 'lng': '-70.6505', 'radius_km': '5'});
  });

  testWidgets('sin permiso de ubicación la tarjeta invita a activarla', (tester) async {
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    await openMap(tester, FakeApi());

    expect(find.text('Activa tu'), findsOneWidget);
    expect(find.text('ubicación'), findsOneWidget);
    // Al abrir no se muestra el error: solo si la persona toca la tarjeta o el botón
    expect(find.text('No diste permiso para usar tu ubicación.'), findsNothing);

    await tapAndSettle(tester, find.text('Activa tu'));
    expect(find.text('No diste permiso para usar tu ubicación.'), findsOneWidget);
  });

  testWidgets('tocar una mascota o un reporte muestra su ficha', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    expect(find.text('Mascota reportada'), findsOneWidget);
    expect(find.text('Perro · Mediano · Café · ~12,5 kg'), findsOneWidget);
    expect(find.text('Estado: Herido, Desnutrido · Asustado'), findsOneWidget);
    expect(find.text('“Perro café con collar rojo cerca del paradero”'), findsOneWidget);
    expect(find.text('Reportado · 28-10-2026'), findsOneWidget);
    expect(find.text('A 2,5 km'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Cerrar'));
    expect(find.text('Mascota reportada'), findsNothing);

    await tapAndSettle(tester, find.byKey(const ValueKey('animal-7')));
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Fundación Patitas'), findsOneWidget);
  });

  testWidgets('tocar la ficha de un reporte abre el detalle a pantalla completa', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    await tapAndSettle(tester, find.text('“Perro café con collar rojo cerca del paradero”').first);

    // Solo están en el detalle, no en la ficha sobre el mapa
    expect(find.text('Comentarios'), findsOneWidget);
    expect(find.text('Ubicación'), findsOneWidget);
    expect(find.text('Reportado · 28-10-2026'), findsWidgets);

    // Coordenadas para copiar y pegar en otra app de rutas (con punto, no con coma).
    // El canal del portapapeles no responde solo en los tests: se simula para que no se quede esperando.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    expect(find.text('-33.44000, -70.66000'), findsOneWidget);
    final copyButton = find.byTooltip('Copiar ubicación');
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    // pumpAndSettle agotaría la duración del SnackBar y lo dejaría cerrado: se pumpea solo lo justo
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ubicación copiada'), findsOneWidget);

    final backButton = find.byTooltip('Volver');
    await tester.ensureVisible(backButton);
    await tapAndSettle(tester, backButton);
    expect(find.text('Comentarios'), findsNothing);
    expect(find.text('Mascota reportada'), findsOneWidget);
  });

  Finder counter(String key, String value) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(value));

  Future<void> openReportDetail(WidgetTester tester, FakeApi api) async {
    await openMap(tester, api);
    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    await tapAndSettle(tester, find.text('“Perro café con collar rojo cerca del paradero”').first);
  }

  testWidgets('el detalle del reporte muestra los me enteré y los comentarios anónimos', (tester) async {
    final api = FakeApi();
    await openReportDetail(tester, api);

    expect(counter('likes-counter', '2'), findsOneWidget);
    expect(counter('comments-counter', '1'), findsOneWidget);
    expect(find.text('Anónimo'), findsOneWidget);
    expect(find.text('Lo vi hace un rato cerca del paradero'), findsOneWidget);

    // Sin sesión no se puede marcar ni comentar: lleva a iniciar sesión
    expect(find.text('Inicia sesión para comentar'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('likes-counter')));
    await tapAndSettle(tester, find.byKey(const ValueKey('likes-counter')));
    expect(find.text('Hola de nuevo'), findsOneWidget);
  });

  testWidgets('con sesión se marca me enteré y se comenta de forma anónima', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReportDetail(tester, api);

    final likes = find.byKey(const ValueKey('likes-counter'));
    await tester.ensureVisible(likes);
    await tapAndSettle(tester, likes);
    expect(counter('likes-counter', '3'), findsOneWidget);
    expect(api.requests.last.method, 'PUT');
    await tapAndSettle(tester, likes);
    expect(counter('likes-counter', '2'), findsOneWidget);
    expect(api.requests.last.method, 'DELETE');

    await tester.enterText(find.byKey(const ValueKey('comment-field')), '  Voy en camino con una correa ');
    await tester.pump();
    await tapAndSettle(tester, find.byTooltip('Enviar'));
    expect(find.text('Voy en camino con una correa'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(counter('comments-counter', '2'), findsOneWidget);
    expect(jsonDecode(api.requests.last.body), {'body': 'Voy en camino con una correa'});
  });

  testWidgets('tocar la ficha de una mascota abre el detalle a pantalla completa', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('animal-7')));
    await tapAndSettle(tester, find.text('Luna').first);

    expect(find.text('Zona aproximada: Ñuñoa'), findsWidgets);
    expect(find.byTooltip('Copiar ubicación'), findsNothing);
    expect(find.text('Fundación Patitas'), findsWidgets);

    await tapAndSettle(tester, find.byTooltip('Volver'));
    expect(find.text('Ubicación'), findsNothing);
  });

  testWidgets('tocar la foto del detalle la abre completa y con zoom', (tester) async {
    final api = FakeApi();
    api.reports[0]['photo_url'] = 'http://api/uploads/foto.png';
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    await tapAndSettle(tester, find.text('“Perro café con collar rojo cerca del paradero”').first);
    expect(find.text('Comentarios'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('hero-photo')));
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tapAndSettle(tester, find.widgetWithIcon(MapButton, Icons.close));
    expect(find.byType(InteractiveViewer), findsNothing);
    // Sigue en el detalle, no volvió hasta el mapa
    expect(find.text('Comentarios'), findsOneWidget);
  });

  testWidgets('el buscador encuentra mascotas por nombre o fundación y las muestra en el mapa', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tester.enterText(find.byType(TextField), 'patitas');
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);

    await tapAndSettle(tester, find.text('Luna'));
    // Se cierra la búsqueda y aparece la ficha de la mascota
    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Lúná');
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'gato');
    await tester.pumpAndSettle();
    expect(find.text('No encontramos mascotas con ese nombre.'), findsOneWidget);
  });

  testWidgets('las capas muestran la leyenda y permiten ocultar los reportes', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Capas'));
    expect(find.text('Adopción · zonas aproximadas (1)'), findsOneWidget);
    expect(find.text('Mascotas reportadas (1)'), findsOneWidget);

    await tapAndSettle(tester, find.text('Mascotas reportadas (1)'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-1')), findsNothing);
    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
  });

  testWidgets('con tu ubicación busca por cercanía y muestra la distancia', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Usar mi ubicación'));

    final nearby = api.requests.lastWhere((r) => r.url.path == '/animals/nearby');
    expect(nearby.url.queryParameters, {'lat': '-33.4378', 'lng': '-70.6505', 'radius_km': '10'});
    expect(find.text('Radio 10 km'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('animal-7')));
    expect(find.text('Dentro de tu radio de búsqueda'), findsOneWidget);

    await tapAndSettle(tester, find.text('Ver todas'));
    expect(find.text('Ver todas'), findsNothing);
    expect(api.requests.last.url.path, isNot('/animals/nearby'));
  });

  testWidgets('muestra el error de ubicación sin romper el mapa', (tester) async {
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Usar mi ubicación'));

    expect(find.text('No diste permiso para usar tu ubicación.'), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
  });

  testWidgets('si la API falla permite reintentar', (tester) async {
    final api = FakeApi()..animalsFail = true;
    await openMap(tester, api);

    expect(find.text('No pudimos cargar las mascotas.'), findsOneWidget);

    api.animalsFail = false;
    await tapAndSettle(tester, find.text('Reintentar'));
    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
  });
}
