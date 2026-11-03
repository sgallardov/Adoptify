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
  testWidgets('lista las fundaciones con sus mascotas en adopción', (
    tester,
  ) async {
    final api = FakeApi();
    await openFoundations(tester, api);

    expect(find.text('8'), findsWidgets);
    expect(find.text('Historias que buscan hogar'), findsOneWidget);
    expect(find.byKey(const ValueKey('adoption-stories')), findsOneWidget);
    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Perro · 1 año y 6 meses · mediano'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Rescatamos perros y gatos de la calle.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Providencia, Santiago'), findsOneWidget);
    expect(find.byTooltip('Fundación verificada'), findsOneWidget);
    expect(find.text('1 animal disponible'), findsOneWidget);

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
