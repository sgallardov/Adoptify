import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/core/photo_service.dart';

import 'fake_api.dart';

// Abre el reporte. Con sesión, primero aparece el mapa a pantalla completa; confirm: true acepta el punto
// (la ubicación simulada se marca sola) y deja el formulario a la vista.
Future<void> openReport(WidgetTester tester, FakeApi api, {bool confirm = true}) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reportar mascota'));
  await tester.pumpAndSettle();
  if (confirm && api.storage.token != null) {
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Completa lo obligatorio del formulario: tipo, tamaño, color, estado y comentarios
Future<void> fillRequired(WidgetTester tester, {String comments = 'Perrita negra asustada bajo un auto'}) async {
  await tapVisible(tester, find.text('Perro'));
  await tapVisible(tester, find.text('Mediano'));
  await tester.enterText(find.byKey(const ValueKey('report-color')), ' Negro ');
  await tapVisible(tester, find.text('Herido'));
  await tester.enterText(find.byKey(const ValueKey('report-comments')), comments);
}

void main() {
  late FakePhotos photos;

  setUp(() {
    LocationService.instance = FakeLocation();
    PhotoService.instance = photos = FakePhotos();
  });
  tearDown(() {
    LocationService.instance = LocationService();
    PhotoService.instance = PhotoService();
  });

  testWidgets('abre el mapa a pantalla completa con tu ubicación marcada', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api, confirm: false);

    expect(find.text('¿Dónde está la mascota?'), findsOneWidget);
    expect(find.text('Punto marcado. Toca otro lugar para moverlo.'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker')), findsOneWidget);
    // El formulario aparece recién al confirmar el punto
    expect(find.text('Enviar reporte'), findsNothing);

    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('1. ¿Dónde está? *'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker')), findsOneWidget);
    expect(find.text('Enviar reporte'), findsOneWidget);
  });

  testWidgets('sin permiso de ubicación hay que marcar el punto antes de seguir', (tester) async {
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api, confirm: false);

    expect(find.text('Toca el mapa para marcar el punto.'), findsOneWidget);
    expect(find.byKey(const ValueKey('picker')), findsNothing);
    final confirm = tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Confirmar ubicación'));
    expect(confirm.onPressed, isNull);
    // Al abrir no se muestra el error; solo si la persona pide su ubicación
    expect(find.textContaining('No diste permiso'), findsNothing);

    await tester.tap(find.byTooltip('Usar mi ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('No diste permiso para usar tu ubicación. Toca el mapa para marcar el punto.'), findsOneWidget);
  });

  testWidgets('cambiar la ubicación vuelve al mapa sin perder lo escrito', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tester.enterText(find.byKey(const ValueKey('report-color')), 'Negro');
    await tapVisible(tester, find.text('Cambiar ubicación'));
    expect(find.text('¿Dónde está la mascota?'), findsOneWidget);

    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('report-color'))).controller!.text, 'Negro');

    // El botón "atrás" desde el formulario también vuelve al mapa
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde está la mascota?'), findsOneWidget);
  });

  testWidgets('valida los campos obligatorios antes de enviar', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Enviar reporte'));
    expect(find.text('Revisa: Tipo de animal, Tamaño, Color, Estado y Comentarios.'), findsWidgets);
    expect(find.text('Selecciona el tipo de animal.'), findsOneWidget);
    expect(find.text('Selecciona el tamaño.'), findsOneWidget);
    expect(find.text('Indica el color (por ejemplo, café o negro con blanco).'), findsOneWidget);
    expect(find.text('Selecciona cómo se encuentra (una o más opciones).'), findsOneWidget);
    expect(find.text('Cuéntanos la situación con al menos 10 caracteres.'), findsOneWidget);

    await tapVisible(tester, find.text('Gato'));
    expect(find.text('Selecciona el tipo de animal.'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('report-weight')), '500');
    await tester.enterText(find.byKey(const ValueKey('report-comments')), 'corto');
    await tapVisible(tester, find.text('Enviar reporte'));
    expect(find.text('Indica un peso aproximado entre 0 y 150 kg.'), findsOneWidget);
    expect(find.text('Cuéntanos la situación con al menos 10 caracteres.'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path == '/reports'), isEmpty);
  });

  testWidgets('envía el reporte y vuelve al mapa con el nuevo pin', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await fillRequired(tester);
    await tapVisible(tester, find.text('Enviar reporte'));

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports');
    expect(post.headers['Authorization'], 'Bearer $validToken');
    // Lo opcional vacío no se envía
    expect(jsonDecode(post.body), {
      'latitude': -33.4378,
      'longitude': -70.6505,
      'species': 'perro',
      'size': 'mediano',
      'color': 'Negro',
      'conditions': ['herido'],
      'description': 'Perrita negra asustada bajo un auto',
    });
    expect(find.text('¡Gracias! Tu reporte quedó publicado en el mapa.'), findsOneWidget);
    // Volvió al mapa y el nuevo reporte aparece en el mapa
    expect(find.byTooltip('Capas'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-2')), findsOneWidget);
  });

  testWidgets('envía también el peso, las características y el comportamiento', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await fillRequired(tester);
    await tester.enterText(find.byKey(const ValueKey('report-weight')), '3,5');
    await tester.enterText(find.byKey(const ValueKey('report-features')), ' Collar azul sin placa ');
    // Varios estados y comportamientos; tocar uno marcado lo desmarca
    await tapVisible(tester, find.text('Desnutrido'));
    await tapVisible(tester, find.text('Tranquilo'));
    await tapVisible(tester, find.text('Tranquilo'));
    await tapVisible(tester, find.text('Asustado'));
    await tapVisible(tester, find.text('Agresivo'));
    await tapVisible(tester, find.text('Enviar reporte'));

    final body = jsonDecode(api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports').body);
    expect(body['weight_kg'], 3.5);
    expect(body['features'], 'Collar azul sin placa');
    expect(body['conditions'], ['herido', 'desnutrido']);
    expect(body['behaviors'], ['asustado', 'agresivo']);
  });

  testWidgets('"Bien" se puede marcar junto a otros estados', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await fillRequired(tester); // marca "Herido"
    await tapVisible(tester, find.text('Bien'));
    await tapVisible(tester, find.text('Preñada'));
    await tapVisible(tester, find.text('Enviar reporte'));
    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports');
    expect(jsonDecode(post.body)['conditions'], ['herido', 'bien', 'prenada']);
  });

  testWidgets('el mensaje dice qué falta y lleva al primer campo con error', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await fillRequired(tester, comments: 'corto');
    await tester.enterText(find.byKey(const ValueKey('report-color')), '');
    await tapVisible(tester, find.text('Enviar reporte'));

    expect(find.text('Revisa: Color y Comentarios.'), findsWidgets);
    // Quedó a la vista el campo Color
    final color = tester.getRect(find.byKey(const ValueKey('report-color')));
    final screen = tester.getRect(find.byType(Scaffold).first);
    expect(screen.contains(color.center), isTrue);
  });

  testWidgets('muestra el mensaje si no hay conexión al enviar', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await fillRequired(tester, comments: 'Perro grande herido en la plaza');
    api.offline = true;
    await tapVisible(tester, find.text('Enviar reporte'));

    expect(find.text('No pudimos conectar con el servidor. Inténtalo nuevamente.'), findsOneWidget);
  });

  testWidgets('sube una foto de la galería y la envía con el reporte', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Galería'));
    expect(photos.sources, [PhotoSource.gallery]);
    final upload = api.requests.singleWhere((r) => r.url.path == '/uploads');
    expect(upload.headers['Authorization'], 'Bearer $validToken');
    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(find.text('Foto lista'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto de la mascota'), findsOneWidget);

    await fillRequired(tester);
    await tapVisible(tester, find.text('Enviar reporte'));

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports');
    expect(jsonDecode(post.body)['photo_url'], 'http://api/uploads/foto.png');
    expect(find.text('¡Gracias! Tu reporte quedó publicado en el mapa.'), findsOneWidget);
  });

  testWidgets('la cámara toma la foto y se puede quitar antes de enviar', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Tomar foto'));
    expect(photos.sources, [PhotoSource.camera]);
    expect(find.text('Foto lista'), findsOneWidget);

    await tapVisible(tester, find.text('Quitar foto'));
    expect(find.text('Foto lista'), findsNothing);
    expect(find.text('Tomar foto'), findsOneWidget);

    await fillRequired(tester, comments: 'Perro grande herido en la plaza');
    await tapVisible(tester, find.text('Enviar reporte'));

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/reports');
    expect(jsonDecode(post.body).containsKey('photo_url'), isFalse);
  });

  testWidgets('si se cancela la cámara no sube nada', (tester) async {
    PhotoService.instance = photos = FakePhotos(cancel: true);
    final api = FakeApi();
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Tomar foto'));
    expect(api.requests.where((r) => r.url.path == '/uploads'), isEmpty);
    expect(find.text('Foto lista'), findsNothing);
  });

  testWidgets('muestra el mensaje del backend si la foto no es válida', (tester) async {
    final api = FakeApi()..uploadStatus = 415;
    api.storage.token = validToken;
    await openReport(tester, api);

    await tapVisible(tester, find.text('Galería'));
    expect(find.text('El archivo no es una imagen válida. Usa JPG o PNG.'), findsOneWidget);
    expect(find.text('Foto lista'), findsNothing);
    expect(find.text('Galería'), findsOneWidget);
  });
}
