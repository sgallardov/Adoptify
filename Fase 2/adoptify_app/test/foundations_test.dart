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
  // Ancho de un teléfono común (412 dp): antes la franja de tres fotos se salía 32 px por la derecha
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<Finder> scrollToStrip(WidgetTester tester, int foundationId) async {
    final strip = find.byKey(ValueKey('animal-strip-$foundationId'));
    await tester.scrollUntilVisible(strip, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    return strip;
  }

  testWidgets('con más de 2 mascotas la franja es un carrusel que no se desborda', (tester) async {
    phoneSize(tester);
    await openFoundations(tester, FakeApi());
    final strip = await scrollToStrip(tester, 3);
    expect(tester.takeException(), isNull);

    // Se mide la tarjeta completa (foto y nombre), no solo el texto
    final canela = find.ancestor(of: find.descendant(of: strip, matching: find.text('Canela')), matching: find.byType(InkWell)).first;
    // La tercera queda asomada a la derecha; al deslizar el carrusel aparece completa
    final stripBox = tester.getRect(strip);
    expect(tester.getRect(canela).right, greaterThan(stripBox.right));
    await tester.drag(strip, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(canela).right, lessThanOrEqualTo(stripBox.right));
  });

  testWidgets('con 2 mascotas o menos la franja queda quieta', (tester) async {
    phoneSize(tester);
    await openFoundations(tester, FakeApi());
    final list = tester.widget<ListView>(find.byKey(const ValueKey('animal-strip-1')));
    expect(list.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('tocar una foto abre su ficha y al volver queda la fundación', (tester) async {
    phoneSize(tester);
    await openFoundations(tester, FakeApi());
    final strip = await scrollToStrip(tester, 3);
    await tester.tap(find.descendant(of: strip, matching: find.text('Mora')));
    await tester.pumpAndSettle();

    // Ficha de la mascota
    expect(find.text('Mora'), findsWidgets);
    expect(find.byTooltip('Volver'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    // Al volver se ve el perfil de la fundación, no la lista
    expect(find.widgetWithText(AppBar, 'Perfil de fundación'), findsOneWidget);
    expect(find.text('Huellas del Sur'), findsWidgets);
  });

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
    expect(find.text('Verificada'), findsOneWidget);
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
