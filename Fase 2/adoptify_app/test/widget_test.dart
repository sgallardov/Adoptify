import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

void main() {
  testWidgets('abre en Inicio y navega por las pestañas', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    expect(find.text('Adoptify'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.text('Usar mi ubicación'), findsOneWidget);

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Hola de nuevo'), findsOneWidget);
  });

  testWidgets('la tarjeta de reporte lleva a la pestaña Reportar', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reportar un perro abandonado'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión para reportar. Tu nombre y tus datos no se publican.'), findsOneWidget);
  });
}
