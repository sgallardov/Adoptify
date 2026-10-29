import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Abre la app y entra al login desde la pestaña Cuenta
Future<void> openLogin(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await tester.pumpAndSettle();
}

Finder field(String hint) => find.widgetWithText(TextFormField, hint);

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
  testWidgets('inicia sesión, guarda el token y muestra el perfil', (tester) async {
    final api = FakeApi();
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await submit(tester, 'Iniciar sesión');

    expect(api.storage.token, validToken);
    expect(find.text('Matías Adoptante'), findsOneWidget);
    expect(find.text('Adoptante'), findsOneWidget);
    expect(find.text('18765432-1'), findsOneWidget);
  });

  testWidgets('muestra el mensaje del backend si las credenciales son incorrectas', (tester) async {
    final api = FakeApi();
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'otra-clave');
    await submit(tester, 'Iniciar sesión');

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(api.storage.token, isNull);
  });

  testWidgets('la pestaña Fundación envía account_type foundation y muestra el 403', (tester) async {
    final api = FakeApi();
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
    final api = FakeApi();
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
    expect(api.requests, isEmpty);
  });

  testWidgets('registra una cuenta y deja la sesión iniciada', (tester) async {
    final api = FakeApi();
    await openLogin(tester, api);
    await tapVisible(tester, find.text('Regístrate'));

    await tester.enterText(field('Tu nombre'), 'Matías Adoptante');
    await tester.enterText(field('12.345.678-5'), '18.765.432-1');
    await tester.enterText(field('tucorreo@ejemplo.cl'), 'nuevo@gmail.com');
    await tester.enterText(field('Mínimo 8 caracteres'), 'Adoptante2026');
    await submit(tester, 'Crear cuenta');

    expect(api.requests.first.url.path, '/auth/register');
    expect(api.requests.first.body, contains('"rut":"18.765.432-1"'));
    expect(api.requests.map((r) => r.url.path), containsAllInOrder(['/auth/register', '/auth/login']));
  });

  testWidgets('sin conexión muestra el mensaje de servidor no disponible', (tester) async {
    final api = FakeApi()..offline = true;
    await openLogin(tester, api);

    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await submit(tester, 'Iniciar sesión');

    expect(find.text('No pudimos conectar con el servidor. Inténtalo nuevamente.'), findsOneWidget);
  });

  testWidgets('recupera la sesión guardada al abrir la app y permite cerrarla', (tester) async {
    final api = FakeApi();
    api.storage.token = validToken;
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Matías Adoptante'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(api.storage.token, isNull);
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
  });

  testWidgets('descarta un token vencido al abrir la app', (tester) async {
    final api = FakeApi();
    api.storage.token = 'token-vencido';
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();

    expect(api.storage.token, isNull);
    expect(api.auth.user, isNull);
  });
}
