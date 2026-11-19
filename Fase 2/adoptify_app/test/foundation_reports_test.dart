import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';

const _reportText = '“Perro café con collar rojo cerca del paradero”';

final _follow = find.byKey(const ValueKey('follow-report'));
final _take = find.byKey(const ValueKey('take-report'));
final _untake = find.byKey(const ValueKey('untake-report'));

// Ruta visible, también cuando se abrió con push (routeInformationProvider solo refleja go)
String _path(WidgetTester tester) {
  final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
  return router.routerDelegate.currentConfiguration.last.matchedLocation;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Abre la app y entra al mapa desde la pestaña Mapa; con `report` abre además el detalle del reporte 1
Future<void> _open(WidgetTester tester, FakeApi api, {bool report = false}) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Mapa'));
  if (report) {
    await _tap(tester, find.byKey(const ValueKey('report-1')));
    await _tap(tester, find.text(_reportText).first);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.instance = FakeLocation();
  });
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('la barra de fundación tiene Inicio, Mapa, Chat y Perfil, en ese orden', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi(asFoundation: true).auth));
    await tester.pumpAndSettle();

    final xs = [for (final label in ['Inicio', 'Mapa', 'Chat', 'Perfil']) tester.getCenter(find.text(label).last).dx];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(find.text('Fundaciones'), findsNothing);
    expect(find.text('Conecta'), findsNothing);
  });

  testWidgets('la pestaña Mapa muestra reportes y animales, sin el botón Reportar mascota', (tester) async {
    // Sin ubicación el mapa encuadra todas las mascotas y reportes
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    await _open(tester, FakeApi(asFoundation: true));

    expect(_path(tester), '/fundacion/mapa');
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-7')), findsOneWidget);
    expect(find.byTooltip('Capas'), findsOneWidget);
    expect(find.text('Reportar mascota'), findsNothing);
  });

  testWidgets('la fundación abre el reporte dentro de su área y vuelve al mapa', (tester) async {
    await _open(tester, FakeApi(asFoundation: true), report: true);

    expect(_path(tester), '/fundacion/reportes/1');
    expect(find.text('Mascota reportada'), findsOneWidget);
    await _tap(tester, find.byTooltip('Volver'));
    expect(_path(tester), '/fundacion/mapa');
  });

  testWidgets('la fundación puede seguir, tomar y deshacer la toma', (tester) async {
    final api = FakeApi(asFoundation: true);
    await _open(tester, api, report: true);

    expect(_follow, findsOneWidget);
    expect(_take, findsOneWidget);
    expect(_untake, findsNothing);

    await _tap(tester, _follow);
    expect(api.requests.any((r) => r.method == 'POST' && r.url.path == '/reports/1/seen'), isTrue);
    expect(find.text('Marcaste el reporte para seguimiento.'), findsOneWidget);

    await _tap(tester, _take);
    expect(api.requests.any((r) => r.method == 'PUT' && r.url.path == '/reports/1/taken'), isTrue);
    expect(find.text('En rescate'), findsOneWidget);
    expect(find.text('Fundación Patitas tomó este caso'), findsOneWidget);
    expect(_take, findsNothing);
    expect(_untake, findsOneWidget);

    await _tap(tester, _untake);
    expect(api.requests.any((r) => r.method == 'DELETE' && r.url.path == '/reports/1/taken'), isTrue);
    expect(find.text('Reportado'), findsOneWidget);
    expect(_take, findsOneWidget);
    expect(_untake, findsNothing);
  });

  testWidgets('si otra fundación ya lo tomó, muestra el aviso y la pantalla sigue entera', (tester) async {
    final api = FakeApi(asFoundation: true);
    await _open(tester, api, report: true);

    // Mientras la pantalla estaba abierta, otra fundación tomó el caso
    api.reports[0] = {
      ...api.reports[0],
      'status': 'in_rescue',
      'taken_by_foundation_id': 2,
      'foundation_name': 'Refugio Sin Casos',
    };
    await _tap(tester, _take);

    expect(find.text('Otra fundación ya tomó este reporte.'), findsOneWidget);
    expect(find.text('Refugio Sin Casos tomó este caso'), findsOneWidget);
    expect(_take, findsNothing);
    // El caso no es suyo: no puede deshacerlo, pero sí seguirlo
    expect(_untake, findsNothing);
    expect(_follow, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si el caso es de otra fundación no ofrece tomarlo ni deshacerlo', (tester) async {
    final api = FakeApi(asFoundation: true);
    api.reports[0] = {
      ...api.reports[0],
      'status': 'in_rescue',
      'taken_by_foundation_id': 2,
      'foundation_name': 'Refugio Sin Casos',
    };
    await _open(tester, api, report: true);

    expect(_take, findsNothing);
    expect(_untake, findsNothing);
    expect(_follow, findsOneWidget);
  });

  testWidgets('el caso propio muestra Deshacer toma', (tester) async {
    final api = FakeApi(asFoundation: true);
    api.reports[0] = {
      ...api.reports[0],
      'status': 'in_rescue',
      'taken_by_foundation_id': 1,
      'foundation_name': 'Fundación Patitas',
    };
    await _open(tester, api, report: true);

    expect(_untake, findsOneWidget);
    expect(_take, findsNothing);
  });

  testWidgets('un reporte resuelto no muestra acciones', (tester) async {
    final api = FakeApi(asFoundation: true);
    api.reports[0] = {...api.reports[0], 'status': 'resolved'};
    await _open(tester, api, report: true);

    expect(find.text('Mascota reportada'), findsOneWidget);
    expect(_follow, findsNothing);
    expect(_take, findsNothing);
    expect(_untake, findsNothing);
  });

  testWidgets('una cuenta de usuario nunca ve las acciones y conserva el botón de reportar', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Mapa'));
    expect(find.text('Reportar mascota'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('report-1')));
    await _tap(tester, find.text(_reportText).first);
    expect(find.text('Mascota reportada'), findsOneWidget);
    expect(_follow, findsNothing);
    expect(_take, findsNothing);
    expect(_untake, findsNothing);
  });
}
