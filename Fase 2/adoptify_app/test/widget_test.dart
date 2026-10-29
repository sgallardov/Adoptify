import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

void main() {
  testWidgets('abre en Inicio y navega por las pestañas', (tester) async {
    await tester.pumpWidget(const AdoptifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Adoptify'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.text('Mapa de mascotas y reportes'), findsOneWidget);

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio de sesión'), findsOneWidget);
  });

  testWidgets('la tarjeta de reporte lleva a la pestaña Reportar', (tester) async {
    await tester.pumpWidget(const AdoptifyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reportar un perro abandonado'));
    await tester.pumpAndSettle();
    expect(find.text('Pronto podrás marcar en el mapa dónde está y enviar el reporte desde aquí.'), findsOneWidget);
  });
}
