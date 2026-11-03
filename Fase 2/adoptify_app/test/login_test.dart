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

  testWidgets('la pestaña Fundación envía account_type foundation y muestra el 403', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    await tester.tap(find.text('Fundación'));
    await tester.pumpAndSettle();
    expect(find.text('Portal de fundaciones'), findsOneWidget);
    expect(find.text('Las cuentas de fundación las crea el equipo de Adoptify.'), findsOneWidget);

    await tester.enterText(field('contacto@fundacion.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await submit(tester, 'Iniciar sesión');

    expect(api.requests.last.body, contains('"account_type":"foundation"'));
    expect(find.text('Esta cuenta no es de este tipo. Inicia sesión en la pestaña Usuario.'), findsOneWidget);
  });

  testWidgets('valida los campos antes de enviar', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);

    await tapVisible(tester, find.text('Regístrate'));
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'correo-sin-arroba');
    await tester.enterText(field('Mínimo 8 caracteres'), 'corta');
    await submit(tester, 'Crear cuenta');

    expect(find.text('El nombre debe tener al menos 2 caracteres'), findsOneWidget);
    expect(find.text('Ingresa tu RUT'), findsOneWidget);
    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);
    expect(authRequests(api), isEmpty);
  });

  testWidgets('registra una cuenta y deja la sesión iniciada', (tester) async {
    final api = FakeApi(loggedIn: false);
    await openLogin(tester, api);
    await tapVisible(tester, find.text('Regístrate'));

    await tester.enterText(field('Tu nombre'), 'Matías Adoptante');
    await tester.enterText(field('12.345.678-5'), '18.765.432-1');
    await tester.enterText(field('tucorreo@ejemplo.cl'), 'nuevo@gmail.com');
    await tester.enterText(field('Mínimo 8 caracteres'), 'Adoptante2026');
    await submit(tester, 'Crear cuenta');

    expect(authRequests(api).first.url.path, '/auth/register');
    expect(authRequests(api).first.body, contains('"rut":"18.765.432-1"'));
    expect(api.requests.map((r) => r.url.path), containsAllInOrder(['/auth/register', '/auth/login']));
  });

  testWidgets('sin conexión muestra el mensaje de servidor no disponible', (tester) async {
    final api = FakeApi(loggedIn: false)..offline = true;
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await submit(tester, 'Iniciar sesión');

    expect(find.text('No pudimos conectar con el servidor. Inténtalo nuevamente.'), findsOneWidget);
  });

  testWidgets('recupera la sesión guardada al abrir la app y permite cerrarla', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Matías Adoptante'), findsOneWidget);

    await tapVisible(tester, find.text('Cerrar sesión'));
    expect(api.storage.token, isNull);
    // Al cerrar sesión vuelve solo al login, sin barra inferior
    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
  });

  testWidgets('descarta un token vencido al abrir la app', (tester) async {
    final api = FakeApi();
    api.storage.token = 'token-vencido';
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();

    expect(api.storage.token, isNull);
    expect(api.auth.user, isNull);
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
