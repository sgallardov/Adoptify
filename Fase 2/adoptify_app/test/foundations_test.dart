import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

Future<void> openFoundations(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fundaciones'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista las fundaciones con sus mascotas en adopción', (tester) async {
    final api = FakeApi();
    await openFoundations(tester, api);

    expect(find.text('2 fundaciones · 1 mascota en adopción'), findsOneWidget);
    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.text('Providencia, Santiago'), findsOneWidget);
    expect(find.text('Rescatamos perros y gatos de la calle.'), findsOneWidget);
    expect(find.text('+56 9 1111 2222'), findsOneWidget);
    expect(find.byTooltip('Fundación verificada'), findsOneWidget);
    expect(find.text('En adopción (1)'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Perro · 1 año y 6 meses'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Refugio Sin Casos'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Valparaíso'), findsOneWidget);
    expect(find.text('Por ahora no tiene mascotas en adopción.'), findsOneWidget);
  });

  testWidgets('si la API falla permite reintentar', (tester) async {
    final api = FakeApi()..foundationsFail = true;
    await openFoundations(tester, api);

    expect(find.text('No se pudo consultar las fundaciones.'), findsOneWidget);

    api.foundationsFail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsOneWidget);
  });
}
