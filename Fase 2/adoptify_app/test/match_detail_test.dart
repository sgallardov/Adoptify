import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// HU-N: ficha desde Match y favoritos, ficha completa y descartes que se recuerdan
const _profile = {
  'housing_type': 'departamento',
  'has_kids': 'no',
  'has_pets': 'no',
  'hours_alone': '2_5',
  'wanted_species': ['perro'],
  'wanted_sizes': ['mediano'],
  'wanted_ages': <String>[],
  'accepts_follow_up': true,
};

FakeApi _api() => FakeApi()..adoptionProfile = Map<String, dynamic>.of(_profile);

Future<void> _openMatch(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conecta'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('"Ver ficha" abre la ficha completa y al volver sigue la misma tarjeta', (tester) async {
    await _openMatch(tester, _api());

    await tester.tap(find.text('Ver ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre Luna'), findsOneWidget);
    expect(find.text('Muy cariñosa'), findsOneWidget);
    expect(find.text('Mestiza'), findsOneWidget);
    expect(find.text('Hembra'), findsOneWidget);
    expect(find.text('Moderado'), findsOneWidget);
    expect(find.text('Postular a adoptar'), findsOneWidget);

    await tester.tap(find.text('Postular a adoptar'));
    await tester.pumpAndSettle();
    expect(find.text('Postulación para Luna'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Quedan 2'), findsOneWidget);
  });

  testWidgets('sin descripción la ficha no deja el título vacío', (tester) async {
    await _openMatch(tester, _api());
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver ficha'));
    await tester.pumpAndSettle();
    expect(find.text('Thor'), findsOneWidget);
    expect(find.textContaining('Sobre '), findsNothing);
    expect(find.text('Muy activo'), findsOneWidget);
  });

  testWidgets('tocar un favorito abre su ficha; el corazón lo quita sin abrirla', (tester) async {
    final api = _api()..favorites.addAll({7, 9});
    await _openMatch(tester, api);
    await tester.tap(find.byTooltip('Mis favoritos'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Quitar de favoritos').last);
    await tester.pumpAndSettle();
    expect(api.favorites, {7});
    expect(find.text('Mis favoritos'), findsOneWidget);

    await tester.tap(find.text('Luna'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre Luna'), findsOneWidget);
    expect(find.text('Postular a adoptar'), findsOneWidget);
  });

  testWidgets('los descartes se recuerdan al recargar y se pueden volver a ver', (tester) async {
    final api = _api();
    await _openMatch(tester, api);
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Thor'), findsOneWidget);

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('Thor'), findsOneWidget);
    expect(find.text('Quedan 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Ver descartados'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Quedan 2'), findsOneWidget);
  });

  testWidgets('los poco compatibles van al final con su rótulo', (tester) async {
    final api = _api()
      ..extraMatchCards.add({
        'id': 11,
        'foundation_name': 'Fundación Patitas',
        'name': 'Michi',
        'species': 'gato',
        'breed': null,
        'age_months': 24,
        'gender': 'macho',
        'size': 'pequeño',
        'energy_level': 2,
        'description': null,
        'photo_url': null,
        'match_score': 10.0,
      });
    await _openMatch(tester, api);
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Michi'), findsOneWidget);
    expect(find.text('Poco compatible · 10 %'), findsOneWidget);

    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Viste todas las mascotas'), findsOneWidget);
    expect(find.text('Ver descartados'), findsOneWidget);
  });
}
