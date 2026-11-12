import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/features/auth/auth_service.dart';

import 'fake_api.dart';

// Abre la app con la sesión de la fundación de prueba (entra directo a su vista)
Future<void> openFoundation(WidgetTester tester) async {
  await tester.pumpWidget(AdoptifyApp(auth: FakeApi(asFoundation: true).auth));
  await tester.pumpAndSettle();
}

// El título de la pantalla abierta (la barra inferior repite el nombre de la pestaña)
Finder screenTitle(String title) => find.widgetWithText(AppBar, title);

GoRouter routerOf(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('la fundación ve Inicio, Chat y Perfil, en ese orden', (tester) async {
    await openFoundation(tester);

    final home = tester.getCenter(find.text('Inicio').last).dx;
    final chat = tester.getCenter(find.text('Chat')).dx;
    final profile = tester.getCenter(find.text('Perfil')).dx;
    expect(home, lessThan(chat));
    expect(chat, lessThan(profile));

    // Nada de la barra de adoptante
    expect(find.text('Fundaciones'), findsNothing);
    expect(find.text('Mapa'), findsNothing);
    expect(find.text('Match'), findsNothing);
  });

  testWidgets('al iniciar sesión cae en Inicio sin forzar el formulario de mascotas', (tester) async {
    await openFoundation(tester);

    expect(screenTitle('Inicio'), findsOneWidget);
    expect(find.text('Cada historia importa.'), findsOneWidget);
    expect(find.text('Publica una historia'), findsNothing);
  });

  testWidgets('cada pestaña abre su placeholder', (tester) async {
    await openFoundation(tester);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(screenTitle('Chat'), findsOneWidget);
    expect(find.text('Publica una historia'), findsOneWidget);

    // Perfil ya no es un placeholder: edita la foto y la descripción de la fundación
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(screenTitle('Perfil'), findsOneWidget);
    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.text('Guardar perfil'), findsOneWidget);

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar animal'));
    await tester.pumpAndSettle();
    expect(screenTitle('Agregar mascota'), findsOneWidget);
    expect(find.text('Publica una historia'), findsOneWidget);
  });

  testWidgets('cada pestaña tiene su tooltip y un área táctil suficiente', (tester) async {
    await openFoundation(tester);

    for (final tooltip in ['Chat con adoptantes', 'Perfil de la fundación']) {
      final tab = find.byTooltip(tooltip);
      expect(tab, findsOneWidget);
      final size = tester.getSize(tab);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('la barra de fundación también funciona en modo oscuro', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    await openFoundation(tester);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Agregar mascota'), findsNothing);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('el Perfil de fundación cambia entre modo claro y oscuro con la luna y el sol', (tester) async {
    await openFoundation(tester);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    Brightness brightness() => Theme.of(tester.element(screenTitle('Perfil'))).brightness;
    Future<String?> saved() async => (await SharedPreferences.getInstance()).getString('theme_mode');

    // Arriba a la derecha, después del título, con la luna en modo claro
    expect(brightness(), Brightness.light);
    final moon = find.byTooltip('Cambiar a modo oscuro');
    expect(tester.getCenter(moon).dx, greaterThan(tester.getCenter(find.text('Perfil').first).dx));
    expect(tester.getCenter(moon).dy, lessThan(tester.getCenter(find.text('Perfil').first).dy + 1));
    expect(find.descendant(of: moon, matching: find.byIcon(Icons.dark_mode_outlined)), findsOneWidget);

    await tester.tap(moon);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(await saved(), 'dark');
    // Ahora muestra el sol para volver al claro
    expect(find.descendant(of: find.byTooltip('Cambiar a modo claro'), matching: find.byIcon(Icons.light_mode_outlined)),
        findsOneWidget);

    await tester.tap(find.byTooltip('Cambiar a modo claro'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(await saved(), 'light');
  });

  testWidgets('la fundación recupera el modo oscuro guardado y el botón solo está en Perfil', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    await openFoundation(tester);

    // Inicio y Chat no llevan el botón
    expect(find.byTooltip('Cambiar a modo claro'), findsNothing);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cambiar a modo claro'), findsOneWidget);
    expect(find.byTooltip('Cambiar a modo oscuro'), findsNothing);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cambiar a modo claro'), findsNothing);
  });

  testWidgets('la fundación no puede entrar a la vista de adoptante', (tester) async {
    await openFoundation(tester);

    routerOf(tester).go('/mapa');
    await tester.pumpAndSettle();
    expect(screenTitle('Inicio'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);

    // /fundaciones es la pestaña de adoptante, no parte del área de fundación
    routerOf(tester).go('/fundaciones');
    await tester.pumpAndSettle();
    expect(screenTitle('Inicio'), findsOneWidget);
  });

  testWidgets('el adoptante mantiene su barra y no puede entrar a la de fundación', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();

    expect(find.text('Fundaciones'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Agregar mascota'), findsNothing);

    routerOf(tester).go('/fundacion/chat');
    await tester.pumpAndSettle();
    expect(find.text('Chat'), findsNothing);
    expect(find.byTooltip('Capas'), findsOneWidget);

    // La pestaña de adoptante /fundaciones sigue funcionando
    await tester.tap(find.text('Fundaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsOneWidget);
  });

  test('admin cuenta como fundación; el adoptante no', () {
    AppUser withRole(String role) =>
        AppUser(id: 1, email: 'a@b.cl', rut: '1-9', fullName: 'Cuenta', role: role);

    expect(withRole('foundation').isFoundation, isTrue);
    expect(withRole('admin').isFoundation, isTrue);
    expect(withRole('adopter').isFoundation, isFalse);
  });
}
