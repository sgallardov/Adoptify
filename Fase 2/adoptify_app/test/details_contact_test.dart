import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/shared/external_links.dart';
import 'package:adoptify_app/shared/widgets/content_width.dart';

import 'fake_api.dart';

// HU-O: acciones en las fichas (llamar, escribir, llegar) y enlaces que se pueden abrir o recargar
Future<void> openLink(WidgetTester tester, String location) async {
  final api = FakeApi();
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

void main() {
  late List<Uri> opened;
  var canOpen = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.instance = FakeLocation();
    opened = [];
    canOpen = true;
    externalLauncher = (url) async {
      opened.add(url);
      return canOpen;
    };
  });

  tearDown(() {
    LocationService.instance = LocationService();
    externalLauncher = (url) async => false;
  });

  group('contacto de fundación', () {
    testWidgets('tocar el teléfono y el correo abre la marcación y el cliente de correo', (tester) async {
      await openLink(tester, '/fundaciones/1');

      await tester.ensureVisible(find.text('+56 9 1111 2222'));
      await tester.tap(find.text('+56 9 1111 2222'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('hola@patitas.cl'));
      await tester.tap(find.text('hola@patitas.cl'));
      await tester.pumpAndSettle();

      expect(opened.map((url) => url.toString()), ['tel:+56911112222', 'mailto:hola@patitas.cl']);
    });

    testWidgets('si no se puede abrir la app avisa y la pantalla sigue funcionando', (tester) async {
      canOpen = false;
      await openLink(tester, '/fundaciones/1');

      await tester.ensureVisible(find.text('+56 9 1111 2222'));
      await tester.tap(find.text('+56 9 1111 2222'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos abrir esa opción en este dispositivo.'), findsOneWidget);
      expect(find.text('Perfil de fundación'), findsOneWidget);
    });

    testWidgets('las tarjetas de la pestaña Fundaciones muestran la insignia Verificada', (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(AdoptifyApp(auth: api.auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Verificada', skipOffstage: false), findsOneWidget);
    });
  });

  group('detalle de reporte', () {
    testWidgets('textos distintos, un solo título de ubicación y botón Cómo llegar', (tester) async {
      await openLink(tester, '/reportes/1');

      expect(find.text('Lo que contó quien reportó'), findsOneWidget);
      expect(find.text('Comentarios de vecinos'), findsOneWidget);
      expect(find.text('Comentarios'), findsNothing);
      expect(find.text('Último avistamiento'), findsOneWidget);
      expect(find.text('Ubicación'), findsNothing);

      await tester.ensureVisible(find.text('Cómo llegar'));
      await tester.tap(find.text('Cómo llegar'));
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(opened.single.host, 'www.google.com');
      expect(opened.single.path, '/maps/dir/');
      expect(opened.single.queryParameters['destination'], matches(RegExp(r'^-?\d+\.\d+,-?\d+\.\d+$')));
    });

    testWidgets('la barra de comentario respeta el ancho máximo del contenido', (tester) async {
      await openLink(tester, '/reportes/1');

      expect(
        find.ancestor(of: find.byKey(const ValueKey('comment-field')), matching: find.byType(ContentWidth)),
        findsOneWidget,
      );
    });
  });

  group('enlaces recargables', () {
    testWidgets('abrir /reportes/:id directo carga el reporte por id', (tester) async {
      await openLink(tester, '/reportes/1');

      expect(find.text('Mascota reportada'), findsOneWidget);
    });

    testWidgets('abrir /animales/:id directo carga el animal por id', (tester) async {
      await openLink(tester, '/animales/7');

      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets('abrir /fundaciones/:id directo carga la fundación por id', (tester) async {
      await openLink(tester, '/fundaciones/1');

      expect(find.text('Fundación Patitas'), findsOneWidget);
    });

    testWidgets('un id inexistente muestra un mensaje claro y un botón para volver', (tester) async {
      await openLink(tester, '/reportes/999');

      expect(find.text('No encontramos lo que buscas. Puede que ya no exista.'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos lo que buscas. Puede que ya no exista.'), findsNothing);
    });
  });
}
