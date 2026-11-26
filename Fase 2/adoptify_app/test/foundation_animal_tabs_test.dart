import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'foundation_nav_test.dart' show openAnimalsTab, openFoundation, openMyAnimals, screenTitle;

// Abre la hoja de estados de un animal y elige una opción
Future<void> changeStatus(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Estado'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('las pestañas separan a los animales por estado y muestran el conteo', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);
    expect(screenTitle('Mis animales'), findsOneWidget);

    // Luna está disponible y Rocky adoptado: una pestaña cada uno
    expect(find.text('Disponibles (1)'), findsOneWidget);
    expect(find.text('En proceso (0)'), findsOneWidget);
    expect(find.text('Adoptados (1)'), findsOneWidget);
    expect(find.text('Seguimiento (0)'), findsOneWidget);

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Rocky'), findsNothing);

    await openAnimalsTab(tester, 'adopted');
    expect(find.text('Rocky'), findsOneWidget);
    expect(find.text('Luna'), findsNothing);
  });

  testWidgets('una pestaña sin animales explica qué va en ella', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);

    await openAnimalsTab(tester, 'in_process');
    expect(find.textContaining('Ningún animal en proceso'), findsOneWidget);

    await openAnimalsTab(tester, 'follow_up');
    expect(find.textContaining('Ningún animal en seguimiento'), findsOneWidget);
  });

  testWidgets('al marcar un animal como adoptado cambia de pestaña sin recargar', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);

    await changeStatus(tester, 'Adoptado');
    // Luna sale de Disponibles y los conteos se actualizan al instante
    expect(find.text('Luna'), findsNothing);
    expect(find.text('Disponibles (0)'), findsOneWidget);
    expect(find.text('Adoptados (2)'), findsOneWidget);

    await openAnimalsTab(tester, 'adopted');
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Rocky'), findsOneWidget);
  });

  testWidgets('un animal adoptado pasa a Seguimiento y vuelve a Adoptados', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);
    await openAnimalsTab(tester, 'adopted');

    await changeStatus(tester, 'Seguimiento');
    expect(find.text('Adoptados (0)'), findsOneWidget);
    expect(find.text('Seguimiento (1)'), findsOneWidget);
    expect(find.text('Rocky'), findsNothing);

    await openAnimalsTab(tester, 'follow_up');
    expect(find.text('Rocky'), findsOneWidget);

    // Y de Seguimiento vuelve a Adoptados
    await changeStatus(tester, 'Adoptado');
    expect(find.text('Seguimiento (0)'), findsOneWidget);
    expect(find.text('Adoptados (1)'), findsOneWidget);
    await openAnimalsTab(tester, 'adopted');
    expect(find.text('Rocky'), findsOneWidget);
  });

  testWidgets('Seguimiento no se ofrece a un animal que todavía no está adoptado', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);

    // Luna está disponible: la hoja de estados no ofrece Seguimiento y lo explica
    await tester.tap(find.widgetWithText(FilledButton, 'Estado'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RadioListTile<String>, 'En adopción'), findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String>, 'En proceso'), findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String>, 'Adoptado'), findsOneWidget);
    expect(find.widgetWithText(RadioListTile<String>, 'Seguimiento'), findsNothing);
    expect(find.textContaining('Seguimiento se activa cuando el animal ya está adoptado'), findsOneWidget);
  });

  testWidgets('las cuatro pestañas se pueden tocar y recibir el foco del teclado', (tester) async {
    await openFoundation(tester);
    await openMyAnimals(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.length, 4);

    for (final status in ['available', 'in_process', 'adopted', 'follow_up']) {
      final tab = find.byKey(ValueKey('tab-$status'));
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      // Área táctil suficiente para el dedo
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(40));
      // Cada pestaña es un control enfocable: se llega a ella con el teclado y se activa con Enter
      final inkWell = tester.widget<InkWell>(find.ancestor(of: tab, matching: find.byType(InkWell)).first);
      expect(inkWell.canRequestFocus, isTrue);
      expect(inkWell.onTap, isNotNull);
    }

    // Y al cambiar de pestaña se muestra el animal de ese estado
    final controller = DefaultTabController.of(tester.element(find.byType(TabBar)));
    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(controller.index, 2);
    expect(find.text('Rocky'), findsOneWidget);
  });
}
