import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/features/foundations/foundation_service.dart';

import 'fake_api.dart';

Map<String, dynamic> member(int id, String name, {bool isPublic = false, String? contribution, int foundationId = 1}) => {
      'id': id,
      'foundation_id': foundationId,
      'name': name,
      'contribution': contribution,
      'joined_at': '2026-03-15',
      'is_public': isPublic,
    };

// Vista de la fundación: pestaña Perfil, con la sección Socios al final de la lista
Future<FakeApi> openProfile(WidgetTester tester, {List<Map<String, dynamic>> members = const []}) async {
  final api = FakeApi(asFoundation: true)..members.addAll(members);
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  return api;
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  // .last: la pantalla de arriba (si hay otra debajo en la pila, queda detrás)
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
}

// Vista del adoptante: Fundaciones → ficha de Fundación Patitas
Future<void> openPublicProfile(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fundaciones'));
  await tester.pumpAndSettle();
  // La lista va por distancia: Providencia (Fundación Patitas) queda primera
  await tester.scrollUntilVisible(
    find.text('Rescatamos perros y gatos de la calle.'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Ver fundación').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ver fundación').first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('vista de la fundación', () {
    testWidgets('sin socios muestra un estado vacío claro', (tester) async {
      await openProfile(tester);
      await scrollTo(tester, find.text('Aún no registras socios'));

      expect(find.text('Aún no registras socios'), findsOneWidget);
      expect(find.text('Agregar socio'), findsOneWidget);
    });

    testWidgets('lista los socios con su aporte y si son públicos', (tester) async {
      await openProfile(tester, members: [
        member(1, 'Ana Pérez', isPublic: true, contribution: '15000.50'),
        member(2, 'Beto Soto'),
      ]);
      await scrollTo(tester, find.text('Beto Soto'));

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.textContaining('Aporte \$15000.5'), findsOneWidget);
      expect(find.text('Visible en la ficha pública'), findsOneWidget);
      expect(find.text('Solo interno'), findsOneWidget);
    });

    testWidgets('agrega un socio y lo marca como público', (tester) async {
      final api = await openProfile(tester);
      await scrollTo(tester, find.text('Agregar socio'));
      await tester.tap(find.text('Agregar socio'));
      await tester.pumpAndSettle();

      // El nombre es obligatorio y no llega a la API vacío
      await tester.tap(find.text('Guardar socio'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre del socio.'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Nombre *'), '  Carla Rojas ');
      await tester.enterText(find.widgetWithText(TextField, 'Aporte en CLP (opcional)'), '20000');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar socio'));
      await tester.pumpAndSettle();

      final post = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/foundations/me/members');
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['name'], 'Carla Rojas');
      expect(body['contribution'], '20000');
      expect(body['is_public'], true);
      expect(body['joined_at'], dateToApi(DateTime.now()));
      expect(find.text('Socio guardado.'), findsOneWidget);
      expect(find.text('Carla Rojas'), findsOneWidget);
      expect(find.text('Aún no registras socios'), findsNothing);
    });

    testWidgets('rechaza un aporte con formato inválido', (tester) async {
      final api = await openProfile(tester);
      await scrollTo(tester, find.text('Agregar socio'));
      await tester.tap(find.text('Agregar socio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nombre *'), 'Dani');
      await tester.enterText(find.widgetWithText(TextField, 'Aporte en CLP (opcional)'), '12.345');
      await tester.tap(find.text('Guardar socio'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Usa un monto válido'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('edita un socio', (tester) async {
      final api = await openProfile(tester, members: [member(1, 'Ana Pérez', contribution: '1000')]);
      await scrollTo(tester, find.byTooltip('Editar a Ana Pérez'));
      await tester.tap(find.byTooltip('Editar a Ana Pérez'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nombre *'), 'Ana P. Soto');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar socio'));
      await tester.pumpAndSettle();

      final put = api.requests.lastWhere((r) => r.method == 'PUT' && r.url.path == '/foundations/me/members/1');
      expect(jsonDecode(put.body), containsPair('name', 'Ana P. Soto'));
      expect(jsonDecode(put.body), containsPair('is_public', true));
      expect(find.text('Ana P. Soto'), findsOneWidget);
      expect(find.text('Visible en la ficha pública'), findsOneWidget);
    });

    testWidgets('borra un socio solo tras confirmar', (tester) async {
      final api = await openProfile(tester, members: [member(1, 'Ana Pérez')]);
      await scrollTo(tester, find.byTooltip('Borrar a Ana Pérez'));

      await tester.tap(find.byTooltip('Borrar a Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);

      await tester.tap(find.byTooltip('Borrar a Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.method == 'DELETE' && r.url.path == '/foundations/me/members/1'), hasLength(1));
      expect(find.text('Socio borrado.'), findsOneWidget);
      expect(find.text('Aún no registras socios'), findsOneWidget);
    });

    testWidgets('si la API falla permite reintentar', (tester) async {
      final api = FakeApi(asFoundation: true)..membersFail = true;
      await tester.pumpWidget(AdoptifyApp(auth: api.auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Reintentar socios'));
      expect(find.text('No se pudo consultar los socios.'), findsOneWidget);

      api.membersFail = false;
      await tester.tap(find.text('Reintentar socios'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no registras socios'), findsOneWidget);
    });
  });

  group('vista del adoptante', () {
    testWidgets('sin socios públicos muestra un estado vacío claro', (tester) async {
      // Hay un socio, pero privado: no debe aparecer
      final api = FakeApi()..members.add(member(1, 'Socio Privado', contribution: '99999'));
      await openPublicProfile(tester, api);
      await scrollTo(tester, find.text('Nuestros socios'));

      expect(find.text('Aún no hay socios públicos'), findsOneWidget);
      expect(find.text('Socio Privado'), findsNothing);
    });

    testWidgets('muestra solo nombre y fecha de los socios públicos, nunca el aporte', (tester) async {
      final api = FakeApi()
        ..members.addAll([
          member(1, 'Ana Pérez', isPublic: true, contribution: '15000.50'),
          member(2, 'Socio Privado', contribution: '99999'),
          member(3, 'Socia de otra fundación', isPublic: true, foundationId: 2),
        ]);
      await openPublicProfile(tester, api);
      await scrollTo(tester, find.text('Ana Pérez'));

      expect(find.text('Nuestros socios'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Desde 15/03/2026'), findsOneWidget);
      expect(find.text('Socio Privado'), findsNothing);
      expect(find.text('Socia de otra fundación'), findsNothing);
      expect(find.textContaining('15000'), findsNothing);
      expect(find.textContaining('Aporte'), findsNothing);
    });
  });
}
