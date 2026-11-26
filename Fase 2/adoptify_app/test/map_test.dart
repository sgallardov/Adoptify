import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/shared/map/map_controls.dart';
import 'package:adoptify_app/shared/map/map_style.dart';

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

  testWidgets(
    'sin ubicación muestra los reportes y no las mascotas en adopción',
    (tester) async {
    // Sin permiso de ubicación el mapa encuadra todas las mascotas y reportes (con ubicación se centra en ti)
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
      final api = FakeApi();
      await openMap(tester, api);

      // HU-R: las mascotas en adopción se ven en Fundaciones y Match, no en el mapa
      expect(find.byKey(const ValueKey('animal-7')), findsNothing);
      // HU-X: /animals solo se pide para el buscador; el mapa no dibuja pines de mascotas en adopción
      final markerKeys = [for (final layer in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer))) for (final m in layer.markers) '${m.key}'];
      expect(markerKeys.where((k) => k.contains('animal')), isEmpty);
      expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(
        markers.singleWhere((m) => m.key == const ValueKey('report-1')).point,
        const LatLng(-33.44, -70.66),
      );
      // Sin ubicación, los reportes se buscan alrededor de Santiago a 100 km
      final reportsRequest = api.requests.firstWhere(
        (r) => r.url.path == '/reports/nearby',
      );
      expect(reportsRequest.url.queryParameters['radius_km'], '100');
    },
  );

  testWidgets(
    'el botón muestra cuántos avisos hay a menos de 5 km de tu ubicación',
    (tester) async {
      final api = FakeApi();
      await openMap(tester, api);

      expect(find.byKey(const ValueKey('alerts-button')), findsOneWidget);
      // Cerrado: solo el botón chico, sin la lista
      expect(find.byKey(const ValueKey('alerts-panel')), findsNothing);
      final alerts = api.requests.lastWhere(
        (r) =>
            r.url.path == '/reports/nearby' &&
            r.url.queryParameters['radius_km'] == '5',
      );
      expect(alerts.url.queryParameters, {
        'lat': '-33.4378',
        'lng': '-70.6505',
        'radius_km': '5',
      });
    },
  );

  testWidgets(
    'tocar el botón despliega la lista y cada aviso abre su detalle',
    (tester) async {
      await openMap(tester, FakeApi());

      await tapAndSettle(tester, find.byKey(const ValueKey('alerts-button')));
      expect(find.byKey(const ValueKey('alerts-panel')), findsOneWidget);
      expect(find.text('Avisos a menos de 5 km'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('alerts-panel')),
          matching: find.text('Perro · Mediano · Café · ~12,5 kg'),
        ),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.byKey(const ValueKey('alert-1')));
      expect(find.text('Lo que contó quien reportó'), findsOneWidget);
    },
  );

  testWidgets('la lista de avisos se cierra con la x', (tester) async {
    await openMap(tester, FakeApi());

    await tapAndSettle(tester, find.byKey(const ValueKey('alerts-button')));
    await tapAndSettle(tester, find.byTooltip('Cerrar avisos'));
    expect(find.byKey(const ValueKey('alerts-panel')), findsNothing);
  });

  testWidgets('sin permiso de ubicación el botón invita a activarla', (
    tester,
  ) async {
    LocationService.instance = FakeLocation(
      error: 'No diste permiso para usar tu ubicación.',
    );
    await openMap(tester, FakeApi());

    expect(find.text('Activar ubicación'), findsOneWidget);
    // Al no obtenerse la ubicación al abrir, ya aparece el aviso con opción de reintentar
    expect(
      find.text('No diste permiso para usar tu ubicación.'),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.text('Activar ubicación'));
    expect(
      find.text('No diste permiso para usar tu ubicación.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'sin señal al abrir el mapa queda como siempre, con aviso para reintentar',
    (tester) async {
      LocationService.instance = FakeLocation(
        error: 'No pudimos obtener tu ubicación. Inténtalo nuevamente.',
      );
      final api = FakeApi();
      await openMap(tester, api);

      // Sigue como hoy: centrado en Santiago, buscando con el radio de respaldo
      final reportsRequest = api.requests.firstWhere(
        (r) => r.url.path == '/reports/nearby',
      );
      expect(reportsRequest.url.queryParameters['radius_km'], '100');
      expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
      expect(
        find.text('No pudimos obtener tu ubicación. Inténtalo nuevamente.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // El botón de retry vuelve a pedir la ubicación y, si funciona, se centra igual que "Usar mi ubicación"
      LocationService.instance = FakeLocation();
      await tapAndSettle(tester, find.text('Reintentar'));
      expect(
        find.text('No pudimos obtener tu ubicación. Inténtalo nuevamente.'),
        findsNothing,
      );
      expect(find.text('Radio 10 km'), findsOneWidget);
    },
  );

  testWidgets('tocar un reporte muestra su ficha', (
    tester,
  ) async {
    // Sin permiso de ubicación el mapa encuadra todas las mascotas y reportes (con ubicación se centra en ti)
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    expect(find.text('Mascota reportada'), findsOneWidget);
    expect(find.text('Perro · Mediano · Café · ~12,5 kg'), findsOneWidget);
    expect(find.text('Estado: Herido, Desnutrido · Asustado'), findsOneWidget);
    expect(
      find.text('“Perro café con collar rojo cerca del paradero”'),
      findsOneWidget,
    );
    expect(find.text('Reportado · 28-10-2026'), findsOneWidget);
    expect(find.text('A 2,5 km'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Cerrar'));
    expect(find.text('Mascota reportada'), findsNothing);
  });

  testWidgets(
    'tocar la ficha de un reporte abre el detalle a pantalla completa',
    (tester) async {
      final api = FakeApi();
      await openMap(tester, api);

      await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
      await tapAndSettle(
        tester,
        find.text('“Perro café con collar rojo cerca del paradero”').first,
      );

      // Solo están en el detalle, no en la ficha sobre el mapa
      expect(find.text('Lo que contó quien reportó'), findsOneWidget);
      expect(find.text('Último avistamiento'), findsOneWidget);
      expect(find.text('Reportado · 28-10-2026'), findsWidgets);
      // El reporte sí conserva su mini mapa: la ubicación sirve para el rescate
      expect(find.byType(FlutterMap), findsOneWidget);

      // Coordenadas para copiar y pegar en otra app de rutas (con punto, no con coma).
      // El canal del portapapeles no responde solo en los tests: se simula para que no se quede esperando.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
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
      expect(find.text('Lo que contó quien reportó'), findsNothing);
      expect(find.text('Mascota reportada'), findsOneWidget);
    },
  );

  Finder counter(String key, String value) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.text(value),
  );

  Future<void> openReportDetail(WidgetTester tester, FakeApi api) async {
    await openMap(tester, api);
    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    await tapAndSettle(
      tester,
      find.text('“Perro café con collar rojo cerca del paradero”').first,
    );
  }

  testWidgets(
    'el detalle del reporte muestra los me enteré y los comentarios anónimos',
    (tester) async {
      final api = FakeApi();
      await openReportDetail(tester, api);

      expect(counter('likes-counter', '2'), findsOneWidget);
      expect(counter('comments-counter', '1'), findsOneWidget);
      expect(find.text('Anónimo'), findsOneWidget);
      expect(
        find.text('Lo vi hace un rato cerca del paradero'),
        findsOneWidget,
      );

      // Con el login obligatorio siempre hay sesión: se puede escribir de inmediato
      expect(find.byKey(const ValueKey('comment-field')), findsOneWidget);
    },
  );

  testWidgets('con sesión se marca me enteré y se comenta de forma anónima', (
    tester,
  ) async {
    final api = FakeApi();
    await openReportDetail(tester, api);

    final likes = find.byKey(const ValueKey('likes-counter'));
    await tester.ensureVisible(likes);
    await tapAndSettle(tester, likes);
    expect(counter('likes-counter', '3'), findsOneWidget);
    expect(api.requests.last.method, 'PUT');
    await tapAndSettle(tester, likes);
    expect(counter('likes-counter', '2'), findsOneWidget);
    expect(api.requests.last.method, 'DELETE');

    await tester.enterText(
      find.byKey(const ValueKey('comment-field')),
      '  Voy en camino con una correa ',
    );
    await tester.pump();
    await tapAndSettle(tester, find.byTooltip('Enviar'));
    expect(find.text('Voy en camino con una correa'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
    expect(counter('comments-counter', '2'), findsOneWidget);
    expect(jsonDecode(api.requests.last.body), {
      'body': 'Voy en camino con una correa',
    });
  });

  testWidgets('tocar la foto del detalle la abre completa y con zoom', (
    tester,
  ) async {
    final api = FakeApi();
    api.reports[0]['photo_url'] = 'http://api/uploads/foto.png';
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    await tapAndSettle(
      tester,
      find.text('“Perro café con collar rojo cerca del paradero”').first,
    );
    expect(find.text('Lo que contó quien reportó'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const ValueKey('hero-photo')));
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tapAndSettle(tester, find.widgetWithIcon(MapButton, Icons.close));
    expect(find.byType(InteractiveViewer), findsNothing);
    // Sigue en el detalle, no volvió hasta el mapa
    expect(find.text('Lo que contó quien reportó'), findsOneWidget);
  });

  testWidgets(
    'el buscador encuentra fundaciones sin importar tildes y abre su perfil',
    (tester) async {
      final api = FakeApi();
      await openMap(tester, api);

      await tester.enterText(find.byType(TextField), 'pátitas');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Fundación Patitas'), findsOneWidget);

      await tapAndSettle(tester, find.widgetWithText(ListTile, 'Fundación Patitas'));
      // Las fundaciones no tienen pin en el mapa: se abre su perfil, como desde la pestaña Fundaciones
      expect(find.text('Contacto de la fundación'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No encontramos reportes, mascotas, fundaciones ni veterinarias con esas palabras.'), findsOneWidget);
    },
  );

  testWidgets('las capas muestran la leyenda y permiten ocultar los reportes', (
    tester,
  ) async {
    // Sin permiso de ubicación el mapa encuadra todas las mascotas y reportes (con ubicación se centra en ti)
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Capas'));
    expect(find.textContaining('Adopción'), findsNothing);
    expect(find.text('Mascotas reportadas (1)'), findsOneWidget);

    await tapAndSettle(tester, find.text('Mascotas reportadas (1)'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-1')), findsNothing);
  });

  testWidgets('con tu ubicación busca por cercanía y muestra la distancia', (
    tester,
  ) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Usar mi ubicación'));

    final nearby = api.requests.lastWhere(
      (r) => r.url.path == '/reports/nearby',
    );
    expect(nearby.url.queryParameters, {
      'lat': '-33.4378',
      'lng': '-70.6505',
      'radius_km': '10',
    });
    expect(find.text('Radio 10 km'), findsOneWidget);

    // Con zoom de calles la mascota queda fuera de la pantalla: al cambiar el radio se encuadra
    await tapAndSettle(tester, find.text('Radio 10 km'));
    await tapAndSettle(tester, find.text('Radio 25 km').last);
    expect(
      api.requests.lastWhere((r) => r.url.path == '/reports/nearby').url.queryParameters['radius_km'],
      '25',
    );

    await tapAndSettle(tester, find.text('Ver todas'));
    expect(find.text('Ver todas'), findsNothing);
    expect(
      api.requests.lastWhere((r) => r.url.path == '/reports/nearby').url.queryParameters['radius_km'],
      '100',
    );
  });

  testWidgets('al abrir el mapa se centra en tu ubicación con tu punto azul', (tester) async {
    await openMap(tester, FakeApi());
    final camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

    // FakeLocation parte en Santiago centro: el mapa queda ahí, a nivel de barrio
    expect(camera.center.latitude, closeTo(-33.4378, 0.0001));
    expect(camera.center.longitude, closeTo(-70.6505, 0.0001));
    expect(camera.zoom, 14);
    // HU-Z: con tu ubicación la búsqueda ya está filtrada a 10 km (como el portal con su sede),
    // y el chip ofrece cambiar el radio o volver a ver todas
    expect(find.text('Radio 10 km'), findsOneWidget);
    expect(find.text('Ver todas'), findsOneWidget);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
    expect(markers.where((m) => m.point == const LatLng(-33.4378, -70.6505)), isNotEmpty);
  });

  testWidgets('usar mi ubicación centra el mapa en ti con zoom de calles', (
    tester,
  ) async {
    await openMap(tester, FakeApi());
    MapCamera camera() => tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera;

    await tapAndSettle(tester, find.byTooltip('Usar mi ubicación'));
    // Ya llegaron las mascotas del radio y el mapa sigue centrado en ti, sin alejarse para encuadrarlas
    expect(camera().center.latitude, closeTo(-33.4378, 0.0001));
    expect(camera().center.longitude, closeTo(-70.6505, 0.0001));
    expect(camera().zoom, 16);

    // Al cambiar el radio se encuadran los resultados: el mapa deja de estar centrado solo en ti
    await tapAndSettle(tester, find.text('Radio 10 km'));
    await tapAndSettle(tester, find.text('Radio 25 km').last);
    expect(camera().center.latitude, isNot(closeTo(-33.4378, 0.0001)));
  });

  testWidgets('las fundaciones no tienen pin, ni capa, ni lugar en la leyenda', (tester) async {
    await openMap(tester, FakeApi());

    // Fundación Patitas y Patitas de Cerro tienen sede, pero el mapa solo marca reportes (y veterinarias de cerca)
    final keys = [
      for (final layer in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)))
        for (final m in layer.markers) '${m.key}',
    ];
    expect(keys.where((key) => key.contains('foundation-')), isEmpty);
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Capas'));
    expect(find.textContaining('Fundaciones ('), findsNothing);
    Navigator.of(tester.element(find.text('Capas del mapa'))).pop();
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byTooltip('Leyenda del mapa'));
    expect(find.descendant(of: find.byKey(const ValueKey('map-legend')), matching: find.text('Fundación')), findsNothing);
  });

  testWidgets('el pin del reporte lleva la huella de su especie', (
    tester,
  ) async {
    final api = FakeApi();
    api.reports.addAll([
      {
        ...api.reports.first,
        'id': 2,
        'species': 'gato',
        'latitude': -33.45,
        'longitude': -70.65,
      },
      {
        ...api.reports.first,
        'id': 3,
        'species': 'otro',
        'latitude': -33.47,
        'longitude': -70.64,
      },
    ]);
    await openMap(tester, api);

    Widget pinOf(int id) {
      final marker = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .singleWhere((m) => m.key == ValueKey('report-$id'));
      return ((marker.child as GestureDetector).child as Center).child!;
    }

    // Perro y gato: el mismo círculo rojo, cambia solo la huella de adentro
    final dog = pinOf(1) as ReportPin;
    final cat = pinOf(2) as ReportPin;
    expect((dog.paw as Icon).icon, Icons.pets);
    expect(
      ((cat.paw as CustomPaint).painter as CatPawPainter).color,
      Colors.white,
    );
    // Otro: el punto rojo de siempre
    expect(pinOf(3), same(MapPins.report));
  });

  testWidgets(
    'las veterinarias tienen pin con cruz roja, chico como el de las fundaciones',
    (tester) async {
      await openMap(tester, FakeApi());
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;

      // Con el mapa alejado no se muestran: son cientos y taparían todo
      map.move(const LatLng(-33.45, -70.62), 11);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('clinic-1')), findsNothing);

      map.move(const LatLng(-33.455, -70.605), 14);
      await tester.pumpAndSettle();
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      final clinic = markers.singleWhere(
        (m) => m.key == const ValueKey('clinic-1'),
      );
      expect(clinic.point, const LatLng(-33.455, -70.605));
      expect(clinic.alignment, Alignment.topCenter);
      expect(MapPins.clinic.kind, DropKind.clinic);
    },
  );

  testWidgets(
    'HU-Q: las mascotas son los pines más grandes y quedan encima de las veterinarias',
    (tester) async {
      // Jerarquía de tamaños: reportes > en adopción > veterinarias (que crecen al seleccionarlas)
      expect(MapPins.reportSize, greaterThan(MapPins.animal.size));
      expect(MapPins.animal.size, greaterThan(MapPins.clinic.width));
      expect(MapPins.selectedClinic.width, greaterThan(MapPins.clinic.width));

      await openMap(tester, FakeApi());
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      map.move(const LatLng(-33.455, -70.605), 14);
      await tester.pumpAndSettle();
      final keys = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .map((m) => '${(m.key as ValueKey?)?.value}')
          .toList();
      final lastClinic = keys.lastIndexWhere((k) => k.startsWith('clinic-'));
      final firstReport = keys.indexWhere((k) => k.startsWith('report-'));
      expect(lastClinic, isNot(-1));
      expect(firstReport, greaterThan(lastClinic));
    },
  );

  testWidgets(
    'la ficha de una veterinaria de urgencias ofrece cómo llegar y llamar',
    (tester) async {
      await openMap(tester, FakeApi());
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;

      map.move(const LatLng(-33.453, -70.605), 15);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byKey(const ValueKey('clinic-1')));
      expect(find.text('Clínica Urgencias Vet'), findsOneWidget);
      expect(find.text('Av. Grecia 100, Ñuñoa'), findsOneWidget);
      expect(find.text('Urgencias 24 h'), findsOneWidget);
      expect(find.text('Cómo llegar'), findsOneWidget);
      expect(find.text('Llamar'), findsOneWidget);

      // Sin teléfono no hay "Llamar"; sin urgencias se muestra el horario
      await tapAndSettle(tester, find.byTooltip('Cerrar'));
      map.move(const LatLng(-33.468, -70.63), 15);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byKey(const ValueKey('clinic-2')));
      expect(find.text('Veterinaria del Barrio'), findsOneWidget);
      expect(find.text('Horario: Mo-Fr 09:00-19:00'), findsOneWidget);
      expect(find.text('Urgencias 24 h'), findsNothing);
      expect(find.text('Llamar'), findsNothing);
    },
  );

  testWidgets('las veterinarias se pueden ocultar desde Capas', (tester) async {
    await openMap(tester, FakeApi());

    // Alejado, la capa avisa que hay que acercar el mapa
    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .move(const LatLng(-33.45, -70.62), 11);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byTooltip('Capas'));
    expect(find.text('Acerca el mapa para verlas'), findsOneWidget);
    Navigator.of(tester.element(find.text('Capas del mapa'))).pop();
    await tester.pumpAndSettle();

    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .move(const LatLng(-33.455, -70.605), 14);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('clinic-1')), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Capas'));
    await tapAndSettle(tester, find.text('Veterinarias (2)'));
    expect(find.byKey(const ValueKey('clinic-1')), findsNothing);
  });

  testWidgets('muestra el error de ubicación sin romper el mapa', (
    tester,
  ) async {
    LocationService.instance = FakeLocation(
      error: 'No diste permiso para usar tu ubicación.',
    );
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byTooltip('Usar mi ubicación'));

    expect(
      find.text('No diste permiso para usar tu ubicación.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
  });

  testWidgets('si la API falla permite reintentar', (tester) async {
    // Sin permiso de ubicación el mapa encuadra todas las mascotas y reportes (con ubicación se centra en ti)
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi()..reportsFail = true;
    await openMap(tester, api);

    expect(find.text('No pudimos cargar los reportes.'), findsOneWidget);

    api.reportsFail = false;
    await tapAndSettle(tester, find.text('Reintentar').first);
    expect(find.byKey(const ValueKey('report-1')), findsOneWidget);
  });
}
