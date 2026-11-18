import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/features/foundation_animals/foundation_animals_service.dart';

import 'fake_api.dart';

const _luna = ManagedAnimal(
  id: 7,
  name: 'Luna',
  species: 'perro',
  gender: 'hembra',
  size: 'mediano',
  energyLevel: 3,
  status: 'available',
  keepingPlaceType: 'refugio',
  keepingPlaceAddress: 'Av. Grecia 100, Ñuñoa',
);

// Abre "Editar mascota" de Luna con la sesión de la fundación y baja hasta la ubicación
Future<FakeApi> openEditor(WidgetTester tester) async {
  final api = FakeApi(asFoundation: true);
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
  router.push('/fundacion/mis-animales/7/editar', extra: _luna);
  await tester.pumpAndSettle();
  await scrollTo(tester, find.text('Usar mi ubicación actual'));
  return api;
}

// El ListView del formulario (no el de un campo de texto o de los resultados)
final _formScroll = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;

// Desplaza el formulario sin arrastrar: un arrastre que cae sobre el mapa movería el mapa
Future<void> scrollTo(WidgetTester tester, Finder target, {double step = 200}) async {
  final position = tester.state<ScrollableState>(_formScroll).position;
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    position.jumpTo((position.pixels + step).clamp(0, position.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Map<String, dynamic> lastPatch(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == 'PATCH').body) as Map<String, dynamic>;

Future<void> save(WidgetTester tester) async {
  await scrollTo(tester, find.text('Guardar cambios'));
  await tester.tap(find.text('Guardar cambios'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('se ubica al animal buscando la dirección, sin escribir coordenadas', (tester) async {
    final api = await openEditor(tester);

    // No se piden latitud ni longitud
    expect(find.text('Latitud'), findsNothing);
    expect(find.text('Longitud'), findsNothing);
    // El buscador parte con la dirección del lugar de resguardo
    expect(find.widgetWithText(TextField, 'Av. Grecia 100, Ñuñoa'), findsWidgets);
    expect(find.byKey(const ValueKey('animal-location')), findsNothing);

    await tester.tap(find.byTooltip('Buscar dirección'));
    await tester.pumpAndSettle();
    expect(api.requests.last.url.queryParameters['q'], 'Av. Grecia 100, Ñuñoa');

    await tester.tap(find.text('Avenida Grecia, Ñuñoa, Santiago, Chile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('animal-location')), findsOneWidget);
    expect(find.textContaining('Ubicado en: Avenida Grecia'), findsOneWidget);
    // La comuna se completa sola con la de la dirección elegida
    expect(find.widgetWithText(TextFormField, 'Ñuñoa'), findsOneWidget);

    await save(tester);
    expect(lastPatch(api), containsPair('latitude', -33.4582));
    expect(lastPatch(api), containsPair('longitude', -70.6241));
    expect(lastPatch(api), containsPair('public_commune', 'Ñuñoa'));
  });

  testWidgets('si no encuentra la dirección lo avisa y no marca nada', (tester) async {
    final api = await openEditor(tester);

    await tester.enterText(find.byKey(const ValueKey('address-search')), 'Calle inventada 123');
    await tester.tap(find.byTooltip('Buscar dirección'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No encontramos esa dirección'), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-location')), findsNothing);
    await save(tester);
    expect(lastPatch(api).containsKey('latitude'), isFalse);
  });

  testWidgets('también se puede usar la ubicación actual del teléfono', (tester) async {
    final api = await openEditor(tester);

    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('animal-location')), findsOneWidget);

    await save(tester);
    // FakeLocation parte en Santiago centro
    expect(lastPatch(api), containsPair('latitude', -33.4378));
    expect(lastPatch(api), containsPair('longitude', -70.6505));
  });

  testWidgets('la comuna se escribe con sugerencias y se guarda con su nombre oficial', (tester) async {
    final api = await openEditor(tester);
    final commune = find.byKey(const ValueKey('commune-field'));
    await tester.ensureVisible(commune);

    await tester.enterText(commune, 'ays');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Aysén'), findsOneWidget);

    // Escrito sin tilde también se reconoce y se guarda como "Aysén"
    await tester.enterText(commune, 'aysen');
    await save(tester);
    expect(lastPatch(api), containsPair('public_commune', 'Aysén'));
  });

  testWidgets('una comuna que no existe no se guarda', (tester) async {
    final api = await openEditor(tester);
    final commune = find.byKey(const ValueKey('commune-field'));
    await tester.ensureVisible(commune);

    await tester.enterText(commune, 'Mi casa');
    await save(tester);
    await scrollTo(tester, find.text('Elige una comuna de la lista o déjala vacía.'), step: -200);
    expect(find.text('Elige una comuna de la lista o déjala vacía.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
}
