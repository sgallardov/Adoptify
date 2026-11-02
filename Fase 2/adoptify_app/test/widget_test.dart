import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

void main() {
  testWidgets('abre en el mapa a pantalla completa con la barra Fundaciones, Mapa y Perfil', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    expect(find.text('Buscar mascota o fundación'), findsOneWidget);
    expect(find.byTooltip('Capas'), findsOneWidget);
    expect(find.byTooltip('Usar mi ubicación'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reportar mascota'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Cuenta'), findsNothing);

    // Orden de izquierda a derecha: Fundaciones, Mapa, Perfil
    final foundations = tester.getCenter(find.text('Fundaciones')).dx;
    final map = tester.getCenter(find.text('Mapa')).dx;
    final profile = tester.getCenter(find.text('Perfil')).dx;
    expect(foundations < map && map < profile, isTrue);
  });

  testWidgets('la barra navega a Fundaciones y Perfil, y el botón abre Reportar mascota', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fundaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta de Adoptify'), findsOneWidget);

    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reportar mascota'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión para reportar. Tu nombre y tus datos no se publican.'), findsOneWidget);

    // Reportar es una pantalla completa: se vuelve al mapa con la flecha
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Capas'), findsOneWidget);
  });
}
