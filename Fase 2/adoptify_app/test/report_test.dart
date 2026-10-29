import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';

Future<void> openReport(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reportar'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('sin sesión pide iniciar sesión para reportar', (tester) async {
    await openReport(tester, FakeApi());

    expect(find.text('Inicia sesión para reportar. Tu nombre y tus datos no se publican.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Hola de nuevo'), findsOneWidget);
  });

  testWidgets('valida el punto y la descripción antes de enviar', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Enviar reporte'));
    expect(find.text('Marca en el mapa dónde está el perro.'), findsOneWidget);

    await tapVisible(tester, find.text('Usar mi ubicación'));
    expect(find.text('Punto marcado. Toca otro lugar del mapa para moverlo.'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'corto');
    await tapVisible(tester, find.text('Enviar reporte'));
    expect(find.text('Describe al perro con al menos 10 caracteres.'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path == '/reports'), isEmpty);
  });

  testWidgets('envía el reporte y vuelve al mapa con el nuevo pin', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Usar mi ubicación'));
    await tester.enterText(find.byType(TextField), 'Perrita negra asustada bajo un auto');
    await tapVisible(tester, find.text('Enviar reporte'));

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports');
    expect(post.headers['Authorization'], 'Bearer $validToken');
    expect(jsonDecode(post.body), {
      'latitude': -33.4378,
      'longitude': -70.6505,
      'description': 'Perrita negra asustada bajo un auto',
    });
    expect(find.text('¡Gracias! Tu reporte quedó publicado en el mapa.'), findsOneWidget);
    // Quedó en la pestaña Mapa y el nuevo reporte aparece en el mapa
    expect(find.text('Perros reportados (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-2')), findsOneWidget);
  });

  testWidgets('muestra el mensaje si no hay conexión al enviar', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Usar mi ubicación'));
    await tester.enterText(find.byType(TextField), 'Perro grande herido en la plaza');
    api.offline = true;
    await tapVisible(tester, find.text('Enviar reporte'));

    expect(find.text('No pudimos conectar con el servidor. Inténtalo nuevamente.'), findsOneWidget);
  });
}
