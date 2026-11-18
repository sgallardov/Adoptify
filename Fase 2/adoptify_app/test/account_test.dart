import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Perfil del adoptante: editar el nombre y cambiar la contraseña. También el carrusel con mouse.

Future<void> openProfile(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('editar nombre', () {
    testWidgets('guarda el nombre sin espacios al borde y el Perfil lo muestra', (tester) async {
      final api = FakeApi();
      await openProfile(tester, api);
      await tapVisible(tester, find.text('Editar nombre'));

      await tester.enterText(find.byKey(const ValueKey('edit-full-name')), '  Matías Morales  ');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

      final request = api.requests.lastWhere((r) => r.method == 'PATCH' && r.url.path == '/auth/me');
      expect(jsonDecode(request.body), {'full_name': 'Matías Morales'});
      expect(find.text('Matías Morales'), findsOneWidget);
      expect(find.text('Guardamos tu nombre.'), findsOneWidget);
    });

    testWidgets('pide al menos 2 caracteres, igual que el registro', (tester) async {
      final api = FakeApi();
      await openProfile(tester, api);
      await tapVisible(tester, find.text('Editar nombre'));

      await tester.enterText(find.byKey(const ValueKey('edit-full-name')), ' M ');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Guardar'));

      expect(find.text('El nombre debe tener al menos 2 caracteres.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });
  });

  group('cambiar contraseña', () {
    Future<void> fill(WidgetTester tester, {required String current, required String next, String? repeat}) async {
      await tester.enterText(find.byKey(const ValueKey('current-password')), current);
      await tester.enterText(find.byKey(const ValueKey('new-password')), next);
      await tester.enterText(find.byKey(const ValueKey('repeat-password')), repeat ?? next);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Cambiar'));
    }

    testWidgets('con la contraseña actual correcta la cambia y la sesión sigue abierta', (tester) async {
      final api = FakeApi();
      await openProfile(tester, api);
      await tapVisible(tester, find.text('Cambiar contraseña'));
      await fill(tester, current: 'Adoptante2026', next: 'NuevaClave2026');

      expect(api.matiasPassword, 'NuevaClave2026');
      expect(find.text('Cambiamos tu contraseña.'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('una contraseña actual incorrecta muestra el error y no cierra la sesión', (tester) async {
      final api = FakeApi();
      await openProfile(tester, api);
      await tapVisible(tester, find.text('Cambiar contraseña'));
      await fill(tester, current: 'NoEsLaClave', next: 'NuevaClave2026');

      // El diálogo sigue abierto con el error y la cuenta sigue con sesión
      expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.storage.token, validToken);
      expect(api.matiasPassword, 'Adoptante2026');
    });

    testWidgets('valida el largo y que las dos nuevas coincidan antes de enviar', (tester) async {
      final api = FakeApi();
      await openProfile(tester, api);
      await tapVisible(tester, find.text('Cambiar contraseña'));
      await fill(tester, current: 'Adoptante2026', next: 'corta');
      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);

      await fill(tester, current: 'Adoptante2026', next: 'NuevaClave2026', repeat: 'OtraClave2026');
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(api.requests.where((r) => r.url.path == '/auth/change-password'), isEmpty);
    });
  });

  group('carrusel en web', () {
    Future<ListView> openStories(WidgetTester tester) async {
      await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundaciones'));
      await tester.pumpAndSettle();
      return tester.widget<ListView>(find.byKey(const ValueKey('adoption-stories')));
    }

    testWidgets('se arrastra con el mouse', (tester) async {
      final list = await openStories(tester);
      await tester.drag(find.byKey(const ValueKey('adoption-stories')), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(0));
    });

    testWidgets('la rueda del mouse lo desplaza hacia el lado', (tester) async {
      final list = await openStories(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(const ValueKey('adoption-stories')))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(0));
    });

    testWidgets('en pantallas anchas tiene flechas para avanzar y retroceder', (tester) async {
      final list = await openStories(tester);
      // Al inicio no hay nada antes
      expect(find.byTooltip('Anterior'), findsNothing);
      await tester.tap(find.byTooltip('Siguiente').first);
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(0));
      await tester.tap(find.byTooltip('Anterior').first);
      await tester.pumpAndSettle();
      expect(list.controller!.offset, 0);
    });

    testWidgets('en el teléfono no hay flechas y se desliza con el dedo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final list = await openStories(tester);
      expect(find.byTooltip('Siguiente'), findsNothing);
      await tester.drag(find.byKey(const ValueKey('adoption-stories')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(list.controller!.offset, greaterThan(0));
    });
  });
}
