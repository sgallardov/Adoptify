import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/shared/widgets/adoptify_logo.dart';

import 'fake_api.dart';

void main() {
  testWidgets('abre en el mapa con el logo en el header y una barra de 3 elementos', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    expect(find.byType(AdoptifyLogo), findsOneWidget);
    expect(find.text('Usar mi ubicación'), findsOneWidget);
    expect(find.text('Reportar mascota'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Cuenta'), findsNothing);

    // Orden de izquierda a derecha: Reportar, Mapa, Perfil
    final report = tester.getCenter(find.text('Reportar mascota')).dx;
    final map = tester.getCenter(find.text('Mapa')).dx;
    final profile = tester.getCenter(find.text('Perfil')).dx;
    expect(report < map && map < profile, isTrue);
  });

  testWidgets('la barra navega a Perfil y a Reportar mascota', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta de Adoptify'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Hola de nuevo'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reportar mascota'));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión para reportar. Tu nombre y tus datos no se publican.'), findsOneWidget);
  });
}
