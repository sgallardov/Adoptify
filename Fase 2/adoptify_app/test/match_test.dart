import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// FakeApi() ya parte con la sesión de Matías iniciada (login obligatorio)
Future<void> openMatch(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Match'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sesión no se llega a Match: la app abre en el login', (tester) async {
    // Login obligatorio: sin sesión no hay barra inferior ni pestaña Match
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi(loggedIn: false).auth));
    await tester.pumpAndSettle();
    expect(find.text('Hola de nuevo'), findsOneWidget);
    expect(find.text('Match'), findsNothing);
  });

  testWidgets('sin "Quiero adoptar" invita a completarlo en el perfil', (tester) async {
    await openMatch(tester, FakeApi());
    expect(find.text('Cuéntanos qué buscas'), findsOneWidget);

    await tester.tap(find.text('Ir a mi perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Quiero adoptar'), findsOneWidget);
  });

  testWidgets('muestra las tarjetas por compatibilidad, sin zona, y avanza al pasar o dar me gusta', (tester) async {
    final api = FakeApi()
      ..adoptionProfile = {
        'housing_type': 'departamento',
        'has_kids': 'no',
        'has_pets': 'no',
        'hours_alone': '2_5',
        'wanted_species': ['perro'],
        'wanted_sizes': ['mediano'],
        'wanted_ages': <String>[],
        'accepts_follow_up': true,
      };
    await openMatch(tester, api);

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('100% match'), findsOneWidget);
    expect(find.textContaining('Zona'), findsNothing);

    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();
    expect(find.text('Thor'), findsOneWidget);

    await tester.tap(find.byTooltip('Pasar'));
    await tester.pumpAndSettle();
    expect(find.text('Viste todas las mascotas'), findsOneWidget);
    expect(find.text('Marcaste 1 como favorita.'), findsOneWidget);
  });

  testWidgets('el corazón guarda el favorito y se ve en Mis favoritos, donde se puede quitar', (tester) async {
    final api = FakeApi()
      ..adoptionProfile = {
        'housing_type': 'departamento',
        'has_kids': 'no',
        'has_pets': 'no',
        'hours_alone': '2_5',
        'wanted_species': ['perro'],
        'wanted_sizes': ['mediano'],
        'wanted_ages': <String>[],
        'accepts_follow_up': true,
      };
    await openMatch(tester, api);

    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();
    expect(api.favorites, {7});

    await tester.tap(find.byTooltip('Mis favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(api.favorites, isEmpty);
    expect(find.text('Aún no tienes favoritos'), findsOneWidget);
  });
}
