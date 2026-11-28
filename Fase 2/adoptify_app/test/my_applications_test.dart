import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// "Mis postulaciones" (HU-AC): ver el estado de cada postulación y retirar las que no están aprobadas

Map<String, dynamic> application(int id, String name, String status, String createdAt) => {
      'id': id,
      'animal_id': id + 100,
      'animal_name': name,
      'animal_photo_url': null,
      'foundation_name': 'Fundación Patitas',
      'status': status,
      'created_at': createdAt,
    };

Future<void> openApplications(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Mis postulaciones'));
  await tester.tap(find.text('Mis postulaciones'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lista las postulaciones con su estado y la rechazada dice que no fue aprobada', (tester) async {
    final api = FakeApi()
      ..myApplications = [
        application(3, 'Luna', 'submitted', '2026-11-20T10:00:00Z'),
        application(2, 'Toby', 'rejected', '2026-11-10T10:00:00Z'),
        application(1, 'Nala', 'approved', '2026-11-01T10:00:00Z'),
      ];
    await openApplications(tester, api);

    expect(find.widgetWithText(AppBar, 'Mis postulaciones'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Por ahora no fue aprobada'), findsOneWidget);
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text('Enviada el 20-11-2026'), findsOneWidget);
    expect(find.text('Fundación Patitas'), findsNWidgets(3));
    // Más reciente primero
    expect(tester.getTopLeft(find.text('Luna')).dy, lessThan(tester.getTopLeft(find.text('Toby')).dy));
    // Retirar solo en las no aprobadas; la aprobada indica contactar a la fundación
    expect(find.text('Retirar postulación'), findsNWidgets(2));
    expect(find.textContaining('contacta a la fundación'), findsOneWidget);
  });

  testWidgets('sin postulaciones invita a explorar animales', (tester) async {
    await openApplications(tester, FakeApi());

    expect(find.text('Todavía no postulaste a ningún animal.'), findsOneWidget);
    await tester.tap(find.text('Explorar animales'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Mis postulaciones'), findsNothing);
  });

  testWidgets('pide confirmación y, al confirmar, la postulación sale de la lista', (tester) async {
    final api = FakeApi()..myApplications = [application(3, 'Luna', 'submitted', '2026-11-20T10:00:00Z')];
    await openApplications(tester, api);

    await tester.tap(find.text('Retirar postulación'));
    await tester.pumpAndSettle();
    expect(find.text('¿Retirar tu postulación?'), findsOneWidget);

    // Cancelar no retira nada
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);

    await tester.tap(find.text('Retirar postulación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();

    expect(api.requests.last.method, 'DELETE');
    expect(api.requests.last.url.path, '/adoption-applications/3');
    expect(find.text('Luna'), findsNothing);
    expect(find.text('Retiraste tu postulación.'), findsOneWidget);
    expect(find.text('Todavía no postulaste a ningún animal.'), findsOneWidget);
  });

  testWidgets('si el retiro falla se mantiene en la lista y se puede reintentar', (tester) async {
    final api = FakeApi()
      ..withdrawFails = true
      ..myApplications = [application(3, 'Luna', 'rejected', '2026-11-20T10:00:00Z')];
    await openApplications(tester, api);

    await tester.tap(find.text('Retirar postulación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo retirar la postulación.'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);

    api.withdrawFails = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsNothing);
  });
}
