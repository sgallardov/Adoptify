import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

Future<void> openProfile(WidgetTester tester, FakeApi api) async {
  api.storage.token = validToken;
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('el formulario es opcional y empieza cerrado', (tester) async {
    final api = FakeApi();
    await openProfile(tester, api);

    expect(find.text('Quiero adoptar'), findsOneWidget);
    expect(find.text('Opcional · cuéntanos de tu hogar para encontrar tu match'), findsOneWidget);
    expect(find.text('Tipo de vivienda'), findsNothing);
  });

  testWidgets('avisa qué falta y no envía nada hasta completar lo obligatorio', (tester) async {
    final api = FakeApi();
    await openProfile(tester, api);

    await tester.tap(find.text('Quiero adoptar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar preferencias'));
    await tester.tap(find.text('Guardar preferencias'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Revisa: Tipo de vivienda'), findsOneWidget);
    expect(api.requests.where((request) => request.method == 'PUT'), isEmpty);
  });

  testWidgets('guarda el formulario con PUT /users/me/adoption-profile', (tester) async {
    final api = FakeApi();
    await openProfile(tester, api);

    await tester.tap(find.text('Quiero adoptar'));
    await tester.pumpAndSettle();
    for (final label in ['Departamento', 'Muy activo', '2 a 5 h', 'Gato', 'Pequeño']) {
      await tapChip(tester, label);
    }
    // Niños y otras mascotas comparten las opciones Sí / No
    await tester.ensureVisible(find.text('No').first);
    await tester.tap(find.text('No').first);
    await tester.tap(find.text('Sí').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar preferencias'));
    await tester.tap(find.text('Guardar preferencias'));
    await tester.pumpAndSettle();

    final put = api.requests.singleWhere((request) => request.method == 'PUT');
    expect(put.url.path, '/users/me/adoption-profile');
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['housing_type'], 'departamento');
    expect(body['has_kids'], 'no');
    expect(body['has_pets'], 'si');
    expect(body['hours_alone'], '2_5');
    expect(body['activity_level'], 'alto');
    expect(body['wanted_species'], ['gato']);
    expect(body['wanted_sizes'], ['pequeño']);
    expect(body['wanted_ages'], isEmpty);
    expect(find.text('Preferencias guardadas · toca para editar'), findsOneWidget);
  });

  testWidgets('carga lo guardado para poder editarlo', (tester) async {
    final api = FakeApi()
      ..adoptionProfile = {
        'housing_type': 'casa_patio',
        'has_kids': 'si',
        'has_pets': 'no',
        'hours_alone': '0_2',
        'activity_level': null,
        'experience': null,
        'wanted_species': ['perro'],
        'wanted_sizes': ['grande'],
        'wanted_ages': [],
        'accepts_follow_up': true,
      };
    await openProfile(tester, api);

    expect(find.text('Preferencias guardadas · toca para editar'), findsOneWidget);
    await tester.tap(find.text('Quiero adoptar'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Casa con patio'));
    expect(chip.selected, isTrue);
  });
}
