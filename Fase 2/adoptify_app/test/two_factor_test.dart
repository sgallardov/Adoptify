import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Verificación en dos pasos por correo (HU-I): el login pide el código y el Perfil la activa o desactiva

Finder field(String hint) => find.widgetWithText(TextFormField, hint);
Finder codeField() => find.widgetWithText(TextField, '000000');

Future<void> tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

// Login con la contraseña de Matías, que tiene la verificación activa: queda en el paso del código
Future<FakeApi> loginWithTwoFactor(WidgetTester tester) async {
  final api = FakeApi(loggedIn: false)..twoFactor = true;
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
  await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
  await tapButton(tester, 'Iniciar sesión');
  return api;
}

void main() {
  testWidgets('con la verificación activa, la contraseña sola no inicia sesión', (tester) async {
    final api = await loginWithTwoFactor(tester);

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('m***r@gmail.com'), findsOneWidget);
    expect(find.textContaining('Vence en 10 minutos'), findsOneWidget);
    expect(api.storage.token, isNull);
    expect(find.byTooltip('Usar mi ubicación'), findsNothing);
  });

  testWidgets('con el código correcto entra al mapa', (tester) async {
    final api = await loginWithTwoFactor(tester);

    await tester.enterText(codeField(), '123456');
    await tester.pumpAndSettle();

    final verify = api.requests.lastWhere((r) => r.url.path == '/auth/verify-code');
    expect(jsonDecode(verify.body), {'challenge_id': 'login-1', 'code': '123456'});
    expect(api.storage.token, validToken);
    expect(find.byTooltip('Usar mi ubicación'), findsOneWidget);
  });

  testWidgets('un código incorrecto muestra los intentos que quedan y sigue en el paso del código', (tester) async {
    final api = await loginWithTwoFactor(tester);

    await tester.enterText(codeField(), '111111');
    await tester.pumpAndSettle();

    expect(find.text('El código no es correcto. Te quedan 4 intentos.'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(api.storage.token, isNull);
  });

  testWidgets('un código vencido vuelve a pedir la contraseña', (tester) async {
    await loginWithTwoFactor(tester);

    await tester.enterText(codeField(), '999999');
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.text('El código venció. Inicia sesión otra vez para recibir un código nuevo.'), findsOneWidget);
  });

  testWidgets('el código se puede reenviar después de 60 segundos', (tester) async {
    final api = FakeApi(loggedIn: false)..twoFactor = true;
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await tester.enterText(field('tucorreo@ejemplo.cl'), 'matias.adopter@gmail.com');
    await tester.enterText(field('Tu contraseña'), 'Adoptante2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    // Sin pumpAndSettle: así se ve la cuenta regresiva antes de que termine
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Reenviar código en 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Reenviar código en 30 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    await tester.tap(find.text('Reenviar código'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final resend = api.requests.lastWhere((r) => r.url.path == '/auth/resend-code');
    expect(jsonDecode(resend.body), {'challenge_id': 'login-1'});
    // El código nuevo vale para el desafío nuevo y la espera vuelve a empezar
    expect(find.text('Reenviar código en 60 s'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Volver regresa al formulario de contraseña', (tester) async {
    await loginWithTwoFactor(tester);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('desde el Perfil se activa confirmando el código y se desactiva con la contraseña', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    expect(find.text('Inactiva'), findsOneWidget);

    // Activar: llega un código y solo queda activa al ingresarlo
    await tapButton(tester, 'Activar');
    expect(find.textContaining('m***r@gmail.com'), findsOneWidget);
    expect(api.twoFactor, isFalse);
    await tester.enterText(codeField(), '123456');
    await tester.pumpAndSettle();
    expect(api.twoFactor, isTrue);
    expect(find.text('Activa'), findsOneWidget);

    // Desactivar pide la contraseña
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'otra-clave');
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();
    expect(find.text('La contraseña no es correcta.'), findsOneWidget);
    expect(api.twoFactor, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'Adoptante2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();
    expect(api.twoFactor, isFalse);
    expect(find.text('Inactiva'), findsOneWidget);
  });
}
