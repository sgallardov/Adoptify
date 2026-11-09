import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/features/foundations/foundations_screen.dart';
import 'package:adoptify_app/shared/widgets/content_width.dart';
import 'package:latlong2/latlong.dart';

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
    // FakeLocation parte en Santiago centro: la fundación de Providencia queda a unos 4 km
    expect(find.textContaining(RegExp(r'^Providencia, Santiago · a [34],\d km$')), findsOneWidget);
    expect(find.byTooltip('Fundación verificada'), findsOneWidget);
    expect(find.text('1 animal disponible'), findsOneWidget);

  });

  testWidgets('con tu ubicación ordena de la más cercana a la más lejana', (tester) async {
    // En Valparaíso, Patitas de Cerro queda primero y Fundación Patitas (Providencia) después
    LocationService.instance = FakeLocation(position: const LatLng(-33.0472, -71.6127));
    final api = FakeApi();
    await openFoundations(tester, api);

    final request = api.requests.lastWhere((r) => r.url.path == '/foundations');
    expect(request.url.queryParameters['lat'], '-33.0472');
    expect(request.url.queryParameters['lng'], '-71.6127');
    expect(find.text('De la más cercana a la más lejana de ti.'), findsOneWidget);

    // Orden de las tarjetas en la lista (se lee de sus hijos porque la lista solo construye lo visible)
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final names = [
      for (final child in (list.childrenDelegate as SliverChildListDelegate).children)
        if (child is ContentWidth && child.child is FoundationCard) (child.child as FoundationCard).foundation.name,
    ];
    expect(names.take(2), ['Patitas de Cerro', 'Fundación Patitas']);

    await tester.scrollUntilVisible(
      find.text('Valparaíso, Valparaíso · a 0 km'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      // Valparaíso queda a unos 100 km de Providencia
      find.textContaining(RegExp(r'^Providencia, Santiago · a (9\d|10\d)(,\d)? km$')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });

  testWidgets('sin permiso de ubicación quedan por nombre y sin distancia', (tester) async {
    LocationService.instance = FakeLocation(error: 'No diste permiso para usar tu ubicación.');
    final api = FakeApi();
    await openFoundations(tester, api);

    expect(api.requests.where((r) => r.url.path == '/foundations' && r.url.hasQuery), isEmpty);
    expect(find.text('Conoce su labor y a sus animales disponibles.'), findsOneWidget);
    expect(find.textContaining(' km'), findsNothing);
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
