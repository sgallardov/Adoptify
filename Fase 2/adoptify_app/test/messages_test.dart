import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Pestaña Mensajes del adoptante (HU-G2): lista, chat, envío y sondeo

Future<void> openMessages(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mensajes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la barra del adoptante tiene Mensajes en segundo lugar', (tester) async {
    await tester.pumpWidget(AdoptifyApp(auth: FakeApi().auth));
    await tester.pumpAndSettle();
    final labels = ['Fundaciones', 'Mensajes', 'Mapa', 'Match', 'Perfil'];
    final positions = [for (final label in labels) tester.getCenter(find.text(label).last).dx];
    expect(positions, [...positions]..sort());
  });

  testWidgets('lista las conversaciones con el último mensaje', (tester) async {
    await openMessages(tester, FakeApi());
    expect(find.text('Fundación Patitas'), findsOneWidget);
    expect(find.text('¡Hola Matías! ¿Te gustaría conocer a Luna?'), findsOneWidget);
  });

  testWidgets('sin conversaciones explica que las abre una fundación', (tester) async {
    final api = FakeApi()..conversations.clear();
    await openMessages(tester, api);
    expect(find.text('Aún no tienes mensajes'), findsOneWidget);
  });

  testWidgets('si falla la carga muestra el error y se puede reintentar', (tester) async {
    final api = FakeApi()..conversationsFail = true;
    await openMessages(tester, api);
    expect(find.text('No se pudieron cargar las conversaciones.'), findsOneWidget);
    api.conversationsFail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Fundación Patitas'), findsOneWidget);
  });

  testWidgets('abre el chat y responde a la fundación', (tester) async {
    final api = FakeApi();
    await openMessages(tester, api);
    await tester.tap(find.text('Fundación Patitas'));
    await tester.pumpAndSettle();

    // Título con el nombre de la fundación y el mensaje que ella escribió
    expect(find.widgetWithText(AppBar, 'Fundación Patitas'), findsOneWidget);
    expect(find.text('¡Hola Matías! ¿Te gustaría conocer a Luna?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  ¡Sí, me encantaría!  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();

    expect(find.text('¡Sí, me encantaría!'), findsOneWidget);
    final sent = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/conversations/5/messages');
    expect(jsonDecode(sent.body), {'body': '¡Sí, me encantaría!'});
    // El campo queda vacío y el botón deshabilitado hasta escribir otra cosa
    final send = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));
    expect(send.onPressed, isNull);
  });

  testWidgets('no envía mensajes vacíos', (tester) async {
    final api = FakeApi();
    await openMessages(tester, api);
    await tester.tap(find.text('Fundación Patitas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '    ');
    await tester.pump();
    final send = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));
    expect(send.onPressed, isNull);
  });

  testWidgets('el campo no acepta más de 1000 caracteres', (tester) async {
    await openMessages(tester, FakeApi());
    await tester.tap(find.text('Fundación Patitas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a' * 1200);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text.length, 1000);
  });

  testWidgets('un mensaje nuevo de la fundación aparece en 10 s sin recargar', (tester) async {
    final api = FakeApi();
    await openMessages(tester, api);
    await tester.tap(find.text('Fundación Patitas'));
    await tester.pumpAndSettle();

    api.foundationWrites(5, 'Te esperamos el sábado a las 11.');
    expect(find.text('Te esperamos el sábado a las 11.'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Te esperamos el sábado a las 11.'), findsOneWidget);
    // El sondeo pide solo lo posterior al último mensaje visto
    final poll = api.requests.lastWhere((r) => r.url.path == '/conversations/5/messages');
    expect(poll.url.queryParameters['after_id'], '1');
  });

  testWidgets('la lista se actualiza sola cada 15 s', (tester) async {
    final api = FakeApi();
    await openMessages(tester, api);
    api.foundationWrites(5, 'Recuerda traer tu carnet.');
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('Recuerda traer tu carnet.'), findsOneWidget);
  });
}
