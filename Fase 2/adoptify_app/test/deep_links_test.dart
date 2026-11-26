import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/features/messages/chat_screen.dart';

import 'fake_api.dart';

// Recargar la página o abrir un enlace directo no trae `extra`: la pantalla debe cargarse sola, sin error
Future<void> openLink(WidgetTester tester, String location, {bool asFoundation = false}) async {
  final api = FakeApi(asFoundation: asFoundation);
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocationService.instance = FakeLocation();
  });
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('el chat de una conversación se abre por enlace directo', (tester) async {
    await openLink(tester, '/mensajes/5');
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('el chat de la fundación se abre por enlace directo', (tester) async {
    await openLink(tester, '/fundacion/mensajes/5', asFoundation: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('una conversación que no existe muestra el aviso, no un error', (tester) async {
    await openLink(tester, '/mensajes/999');
    expect(tester.takeException(), isNull);
    expect(find.text('No encontramos lo que buscas. Puede que ya no exista.'), findsOneWidget);
  });

  testWidgets('el formulario de postulación y la edición de mascota no fallan sin extra', (tester) async {
    await openLink(tester, '/animales/1/postular');
    expect(tester.takeException(), isNull);
    await openLink(tester, '/fundacion/mis-animales/1/editar', asFoundation: true);
    expect(tester.takeException(), isNull);
  });
}
