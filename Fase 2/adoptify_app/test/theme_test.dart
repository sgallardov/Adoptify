import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';
import 'package:adoptify_app/app/theme.dart';
import 'package:adoptify_app/features/account/account_screen.dart';

import 'fake_api.dart';

Brightness brightnessOf(WidgetTester tester) => Theme.of(tester.element(find.byType(AccountScreen))).brightness;

Future<void> openProfile(WidgetTester tester) async {
  await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Perfil permite elegir el modo oscuro y lo guarda', (tester) async {
    await openProfile(tester);
    expect(find.text('Apariencia'), findsOneWidget);
    expect(brightnessOf(tester), Brightness.light);

    await tester.ensureVisible(find.text('Oscuro'));

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(brightnessOf(tester), Brightness.dark);
    expect(Theme.of(tester.element(find.byType(AccountScreen))).extension<AdoptifyColors>(), AdoptifyColors.dark);
    expect((await SharedPreferences.getInstance()).getString('theme_mode'), 'dark');

    await tester.ensureVisible(find.text('Claro'));

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(brightnessOf(tester), Brightness.light);
  });

  testWidgets('recupera el modo oscuro guardado al abrir la app', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    await openProfile(tester);
    expect(brightnessOf(tester), Brightness.dark);
  });

  testWidgets('por defecto sigue la apariencia del teléfono', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openProfile(tester);
    expect(brightnessOf(tester), Brightness.dark);
  });
}
