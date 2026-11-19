import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';

// HU-S: la tarjeta del mapa, la lista de avisos y el pin muestran si una fundación ya tomó el caso
Future<void> openMap(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mapa'));
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void takeReport(FakeApi api) {
  api.reports[0] = {
    ...api.reports[0],
    'status': 'in_rescue',
    'taken_by_foundation_id': 1,
    'foundation_name': 'Fundación Patitas',
    'seen_at': '2026-11-03T10:00:00Z',
    'taken_at': '2026-11-03T10:00:00Z',
  };
}

void main() {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());

  testWidgets('la tarjeta del pin dice qué fundación tomó el caso', (tester) async {
    final api = FakeApi();
    takeReport(api);
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));

    expect(find.text('En rescate por Fundación Patitas'), findsOneWidget);
  });

  testWidgets('la lista de avisos muestra el caso tomado', (tester) async {
    final api = FakeApi();
    takeReport(api);
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('alerts-button')));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('alerts-panel')),
        matching: find.textContaining('En rescate por Fundación Patitas'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('si una fundación solo lo vio, la tarjeta lo indica', (tester) async {
    final api = FakeApi();
    api.reports[0] = {...api.reports[0], 'seen_at': '2026-11-03T10:00:00Z'};
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));

    expect(find.text('Una fundación ya lo vio'), findsOneWidget);
    expect(find.textContaining('En rescate por'), findsNothing);
  });

  testWidgets('el pin de un caso tomado lleva insignia y la leyenda la explica', (tester) async {
    final api = FakeApi();
    takeReport(api);
    await openMap(tester, api);
    expect(
      find.descendant(of: find.byKey(const ValueKey('report-1')), matching: find.byKey(const ValueKey('taken-badge'))),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.byTooltip('Leyenda del mapa'));
    expect(find.text('Caso tomado'), findsOneWidget);
  });

  testWidgets('al volver del detalle se ve si el caso cambió', (tester) async {
    final api = FakeApi();
    await openMap(tester, api);

    await tapAndSettle(tester, find.byKey(const ValueKey('report-1')));
    expect(find.textContaining('En rescate por'), findsNothing);

    await tapAndSettle(tester, find.text('“Perro café con collar rojo cerca del paradero”').first);
    takeReport(api);
    final back = find.byTooltip('Volver');
    await tester.ensureVisible(back);
    await tapAndSettle(tester, back);

    expect(find.text('En rescate por Fundación Patitas'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('report-1')), matching: find.byKey(const ValueKey('taken-badge'))),
      findsOneWidget,
    );
  });
}
