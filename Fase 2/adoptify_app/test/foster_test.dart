import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Postulación a hogar temporal (HU-B) desde el Perfil del adoptante

const pendingApplication = {
  'id': 1,
  'species': 'perro',
  'sizes': ['pequeño', 'grande'],
  'space': 'departamento',
  'max_animals': 2,
  'max_days': 45,
  'availability': 'Fines de semana',
  'phone': '+56 9 8765 4321',
  'address': 'Av. Grecia 1234, Ñuñoa',
  'status': 'pending',
};

// El formulario es largo y su lista solo construye lo visible: se desplaza hasta el elemento antes de tocarlo
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable));
  if (finder.evaluate().isEmpty && form.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: form.first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openProfile(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester, FakeApi api) async {
  await openProfile(tester, api);
  await tapVisible(tester, find.text('Hogar temporal'));
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> enterVisible(WidgetTester tester, Finder finder, String text) async {
  final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable));
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 200, scrollable: form.first);
  await tester.enterText(finder, text);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el Perfil invita a postular y el formulario usa el nombre y correo de la cuenta', (tester) async {
    final api = FakeApi();
    await openProfile(tester, api);

    await tester.ensureVisible(find.text('Hogar temporal'));
    expect(find.textContaining('toca para postular'), findsOneWidget);

    await tapVisible(tester, find.text('Hogar temporal'));
    expect(find.widgetWithText(AppBar, 'Hogar temporal'), findsOneWidget);
    expect(find.text('Matías Adoptante'), findsOneWidget);
    expect(find.text('matias.adopter@gmail.com'), findsOneWidget);
    expect(find.text('Privada: solo la verán las fundaciones.'), findsOneWidget);
  });

  testWidgets('todos los campos son obligatorios', (tester) async {
    final api = FakeApi();
    await openForm(tester, api);

    await tapVisible(tester, find.text('Enviar postulación'));

    // Junto al botón, todos los pendientes (los errores de arriba quedan fuera de la pantalla)
    expect(
      find.text('Revisa: Teléfono, Dirección, Tipo de mascota, Tamaño, Días máximos, Espacio, Disponibilidad.'),
      findsOneWidget,
    );
    expect(find.text('Cuéntanos tu disponibilidad.'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST' && r.url.path == '/foster-applications'), isEmpty);
  });

  testWidgets('envía la postulación sin elegir fundación y el Perfil muestra que está en revisión', (tester) async {
    final api = FakeApi();
    await openForm(tester, api);

    await enterVisible(tester, field('Teléfono *'), '+56 9 1234 5678');
    await enterVisible(tester, field('Dirección *'), 'Av. Grecia 1234, Ñuñoa');
    await tapVisible(tester, find.text('Ambos'));
    await tapVisible(tester, find.text('Grande'));
    await tapVisible(tester, find.text('Pequeño'));
    await tapVisible(tester, find.byTooltip('Más'));
    await enterVisible(tester, field('Días máximos que puedes tenerlo *'), '30');
    await tapVisible(tester, find.text('Casa con patio'));
    await enterVisible(tester, field('Disponibilidad *'), 'Desde ya');
    await tapVisible(tester, find.text('Enviar postulación'));

    final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/foster-applications');
    expect(jsonDecode(post.body), {
      'species': 'ambos',
      'sizes': ['pequeño', 'grande'],
      'space': 'casa_patio',
      'max_animals': 2,
      'max_days': 30,
      'availability': 'Desde ya',
      'phone': '+56 9 1234 5678',
      'address': 'Av. Grecia 1234, Ñuñoa',
    });
    // De vuelta en el Perfil, la tarjeta muestra el estado
    expect(find.widgetWithText(AppBar, 'Perfil'), findsOneWidget);
    await tester.ensureVisible(find.text('Hogar temporal'));
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.textContaining('Hasta 2 a la vez · máx. 30 días'), findsOneWidget);
  });

  testWidgets('mientras está en revisión se puede editar', (tester) async {
    final api = FakeApi()..fosterApplication = {...pendingApplication};
    await openForm(tester, api);

    expect(find.text('Av. Grecia 1234, Ñuñoa'), findsOneWidget);
    await enterVisible(tester, field('Días máximos que puedes tenerlo *'), '60');
    await tapVisible(tester, find.text('Guardar cambios'));

    final put = api.requests.lastWhere((r) => r.method == 'PUT' && r.url.path == '/foster-applications/me');
    expect(jsonDecode(put.body)['max_days'], 60);
    expect(api.fosterApplication!['max_days'], 60);
  });

  testWidgets('ya revisada no se edita, pero se puede retirar', (tester) async {
    final api = FakeApi()..fosterApplication = {...pendingApplication, 'status': 'approved'};
    await openForm(tester, api);

    expect(find.textContaining('Aprobada: Una fundación aprobó tu postulación'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsNothing);
    expect(tester.widget<TextFormField>(field('Teléfono *')).enabled, isFalse);

    await tapVisible(tester, find.text('Retirar postulación'));
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();

    expect(api.fosterApplication, isNull);
    await tester.ensureVisible(find.text('Hogar temporal'));
    expect(find.textContaining('toca para postular'), findsOneWidget);
  });
}
