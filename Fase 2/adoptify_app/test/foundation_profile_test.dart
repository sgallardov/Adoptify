import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

Future<FakeApi> openProfile(WidgetTester tester) async {
  final api = FakeApi(asFoundation: true);
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  return api;
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Guardar perfil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guardar perfil'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('muestra la descripción actual y la inicial sin foto', (tester) async {
    await openProfile(tester);

    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.text('Rescatamos perros y gatos de la calle.'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
  });

  testWidgets('la descripción es obligatoria y con un mínimo de caracteres', (tester) async {
    final api = await openProfile(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await save(tester);
    expect(find.text('Escribe una descripción de tu fundación.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Muy corta');
    await save(tester);
    expect(find.text('La descripción debe tener al menos 20 caracteres.'), findsOneWidget);
    // No llega a la API mientras no sea válida
    expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('guarda la descripción y la deja visible para los adoptantes', (tester) async {
    final api = await openProfile(tester);

    await tester.enterText(find.byType(TextField), '  Rescatamos y rehabilitamos perros en Providencia.  ');
    await save(tester);

    final put = api.requests.lastWhere((r) => r.method == 'PUT' && r.url.path == '/foundations/me');
    expect(jsonDecode(put.body), {
      'description': 'Rescatamos y rehabilitamos perros en Providencia.',
      'photo_url': null,
    });
    expect(api.foundationDescription, 'Rescatamos y rehabilitamos perros en Providencia.');
    expect(find.text('Perfil guardado. Así te verán los adoptantes en el mapa.'), findsOneWidget);
  });

  testWidgets('quitar la foto la manda como null al guardar', (tester) async {
    final api = FakeApi(asFoundation: true)..foundationPhoto = 'http://api/uploads/perfil.jpg';
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(api.foundationPhoto, isNull);
    expect(find.text('Quitar foto'), findsNothing);
  });
}
