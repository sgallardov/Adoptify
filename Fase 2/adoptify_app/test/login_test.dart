import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Login obligatorio: sin sesión, la app abre directo en el login
Future<void> openLogin(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
}

Finder field(String hint) => find.widgetWithText(TextFormField, hint);

// Solo las llamadas a /auth (después de entrar, el mapa también hace peticiones)
List<http.Request> authRequests(FakeApi api) => api.requests.where((r) => r.url.path.startsWith('/auth')).toList();

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // Se dibuja el scroll antes de tocar: si no, el toque cae donde estaba el botón
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('inicia sesión, guarda el token, vuelve al mapa y muestra el perfil', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await submit(tester, 'Iniciar sesión');

    expect(api.storage.token, validToken);
    // Con la sesión iniciada, la app abre en el mapa
    expect(find.byTooltip('Usar mi ubicación'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Matías Adoptante'), findsOneWidget);
    expect(find.text('Adoptante'), findsOneWidget);
    expect(find.text('18765432-1'), findsOneWidget);
  });

  testWidgets('muestra el mensaje del backend si las credenciales son incorrectas', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'otra-clave');
    await submit(tester, 'Iniciar sesión');

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(api.storage.token, isNull);
  });

  testWidgets('un solo login: no hay pestañas ni nada que mencione fundaciones', (tester) async {
    await openLogin(tester, FakeApi(loggedIn: false));

    expect(find.text('Usuario'), findsNothing);
    expect(find.text('Fundación'), findsNothing);
    expect(find.textContaining('fundaci'), findsNothing);
    expect(find.textContaining('Fundaci'), findsNothing);
  });

  testWidgets('una fundación entra por el mismo login y cae en su vista con la barra de fundación', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'fundacion@adoptify.cl');
    await tester.enterText(field('Tu contraseña'), 'Fundacion2026');
    await submit(tester, 'Iniciar sesión');

    // El login no manda tipo de cuenta: el rol lo decide el backend
    final login = authRequests(api).firstWhere((r) => r.url.path == '/auth/login');
    expect(login.body, isNot(contains('account_type')));
    expect(api.storage.token, foundationToken);

    // Cae en el inicio de fundación, sin barra ni mapa de adoptante
    expect(find.widgetWithText(AppBar, 'Inicio'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
    expect(find.text('Match'), findsNothing);

    // Desde Perfil puede cerrar sesión y vuelve al login
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsOneWidget);
    // El botón está al final del formulario de perfil
    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200, scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.text('Cerrar sesión'));
    expect(api.storage.token, isNull);
    expect(find.text('Hola de nuevo'), findsOneWidget);
  });

  testWidgets('sin sesión la app abre en el login y no deja entrar al mapa', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
    // Sin sesión no se piden mascotas ni reportes: nada se carga antes de entrar
    expect(api.requests.where((r) => !r.url.path.startsWith('/auth')), isEmpty);

    // Intentar abrir el mapa (por ejemplo, desde un enlace) también lleva al login
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
    router.go('/mapa');
    await tester.pumpAndSettle();
    expect(find.text('Hola de nuevo'), findsOneWidget);
  });
}
