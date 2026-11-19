import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/shared/map/map_controls.dart';

import 'fake_api.dart';

// Arreglos del mapa: buscador en web, permiso de ubicación sin respuesta y leyenda

Future<void> openMap(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
}

// Sin respuesta al permiso hay un indicador girando: pumpAndSettle no terminaría, se avanza a mano
Future<void> openMapWaiting(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Escritorio se comporta como la web: el campo pierde el foco al presionar el mouse fuera de él
final _platforms = TargetPlatformVariant(const {TargetPlatform.android, TargetPlatform.linux});

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  group('buscador', () {
    testWidgets('tocar un resultado cierra la lista, limpia el buscador y abre la ficha', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'patitas');
      await tester.pumpAndSettle();

      // Como un clic real: entre presionar y soltar se dibuja un cuadro. Antes, en web, el campo perdía el foco
      // al presionar, la lista desaparecía en ese cuadro y el clic ya no llegaba al resultado.
      final press = await tester.startGesture(tester.getCenter(find.widgetWithText(ListTile, 'Fundación Patitas')));
      await tester.pump(const Duration(milliseconds: 80));
      await press.up();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Fundación Patitas'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      // Ficha de la fundación abierta en el mapa
      expect(find.text('Rescatamos perros y gatos de la calle.'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
    }, variant: _platforms);

    testWidgets('Enter elige el primer resultado', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'patit');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Fundación Patitas'), findsNothing);
      expect(find.text('Rescatamos perros y gatos de la calle.'), findsOneWidget);
    });

    // HU-X: búsqueda por palabras en reportes, fundaciones y veterinarias
    testWidgets('busca por palabras en cualquier orden, sin tildes, y muestra el tipo', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'HERIDO perro cafe');
      await tester.pumpAndSettle();
      expect(find.textContaining('Perro · Mediano · Café'), findsOneWidget);
      expect(find.textContaining('Reporte ·'), findsOneWidget);

      // Una palabra que no está en el reporte lo descarta
      await tester.enterText(find.byType(TextField), 'perro negro herido');
      await tester.pumpAndSettle();
      expect(find.textContaining('Reporte ·'), findsNothing);
      expect(find.text('No encontramos reportes, mascotas, fundaciones ni veterinarias con esas palabras.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'grecia nunoa');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Clínica Urgencias Vet'), findsOneWidget);
      expect(find.textContaining('Veterinaria ·'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'patitas');
      await tester.pumpAndSettle();
      expect(find.textContaining('Fundación ·'), findsWidgets);
    });

    testWidgets('perro muestra los reportes y las mascotas en adopción de esa especie', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'perro');
      await tester.pumpAndSettle();
      expect(find.textContaining('Reporte ·'), findsOneWidget);
      // Luna está disponible; Rocky ya fue adoptado y no aparece
      expect(find.widgetWithText(ListTile, 'Luna'), findsOneWidget);
      expect(find.textContaining('En adopción ·'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Rocky'), findsNothing);

      // Tocar la mascota abre su ficha
      await tester.tap(find.widgetWithText(ListTile, 'Luna'));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('elegir un reporte o una veterinaria centra el mapa y abre su tarjeta', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'collar rojo');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Reporte ·'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar'), findsOneWidget);
      expect(find.textContaining('Perro café con collar rojo'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'urgencias vet');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      // Tarjeta de la veterinaria (antes de elegirla no se veía: falta zoom) y su pin en el mapa
      expect(find.text('Clínica Urgencias Vet'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
      final keys = [for (final layer in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer))) for (final m in layer.markers) m.key];
      expect(keys, contains(const ValueKey('clinic-1')));
    });

    testWidgets('tocar fuera del buscador y de la lista la cierra', (tester) async {
      await openMap(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'patitas');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Fundación Patitas'), findsOneWidget);

      // Un punto del mapa lejos de los pines y de los botones
      await tester.tapAt(tester.getTopLeft(find.byType(FlutterMap)) + const Offset(30, 420));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Fundación Patitas'), findsNothing);
      expect(find.text('Rescatamos perros y gatos de la calle.'), findsNothing);
    }, variant: _platforms);
  });

  group('permiso de ubicación', () {
    testWidgets('mientras espera lo dice, y sin respuesta deja de cargar y ofrece activarla', (tester) async {
      LocationService.instance = FakeLocation(hang: true);
      await openMapWaiting(tester, FakeApi());

      expect(find.text('Buscando tu ubicación…'), findsOneWidget);
      expect(find.text('Activar ubicación'), findsNothing);

      await tester.pump(locationTimeout);
      await tester.pumpAndSettle();
      expect(find.text('Buscando tu ubicación…'), findsNothing);
      expect(find.text('Activar ubicación'), findsOneWidget);
      expect(find.text(permissionTimeoutMessage), findsOneWidget);
      // El mapa sigue funcionando: el reporte se ve igual
      expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
    });

    testWidgets('el botón de ubicación explica la espera y vuelve a estar disponible', (tester) async {
      await openMap(tester, FakeApi());
      LocationService.instance = FakeLocation(hang: true);
      await tester.tap(find.byTooltip('Usar mi ubicación'));
      await tester.pump();

      final waiting = tester.widget<MapButton>(find.byWidgetPredicate((w) => w is MapButton && w.loading));
      expect(waiting.loadingTooltip, 'Buscando tu ubicación…');
      expect(find.byTooltip('Buscando tu ubicación…'), findsOneWidget);

      await tester.pump(locationTimeout);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is MapButton && w.loading), findsNothing);
      expect(find.text(permissionTimeoutMessage), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('en Reportar tampoco queda cargando para siempre', (tester) async {
      await openMap(tester, FakeApi());
      LocationService.instance = FakeLocation(hang: true);
      await tester.tap(find.text('Reportar mascota'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('Buscando tu ubicación…'), findsOneWidget);
      expect(find.byTooltip('Buscando tu ubicación…'), findsOneWidget);

      await tester.pump(locationTimeout);
      await tester.pumpAndSettle();
      expect(find.textContaining('Buscando tu ubicación…'), findsNothing);
      expect(find.text('Toca el mapa para marcar el punto.'), findsOneWidget);
      expect(find.byTooltip('Usar mi ubicación'), findsOneWidget);
    });
  });

  group('leyenda', () {
    testWidgets('la leyenda se abre con un toque desde el mapa', (tester) async {
      await openMap(tester, FakeApi());
      await tester.tap(find.byTooltip('Leyenda del mapa'));
      await tester.pumpAndSettle();

      final legend = find.byKey(const ValueKey('map-legend'));
      expect(find.text('Qué significa cada pin'), findsOneWidget);
      for (final item in ['Perro reportado', 'Gato reportado', 'Fundación', 'Veterinaria']) {
        expect(find.descendant(of: legend, matching: find.text(item)), findsOneWidget);
      }
      // HU-R: el mapa ya no muestra mascotas en adopción
      expect(find.text('Mascota en adopción'), findsNothing);
    });
  });
}
