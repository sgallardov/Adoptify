import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Formulario de adopción por chat (HU-G3): la fundación lo envía y el adoptante lo responde una vez

Future<void> openChat(WidgetTester tester, FakeApi api, {required String tab, required String title}) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('la fundación envía su formulario desde el chat', (tester) async {
    final api = FakeApi(asFoundation: true);
    await openChat(tester, api, tab: 'Chat', title: 'Matías Adoptante');

    await tester.tap(find.byTooltip('Enviar formulario de adopción'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¿Enviar tu formulario de adopción a Matías Adoptante?'), findsOneWidget);
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(api.requests.where((r) => r.url.path == '/conversations/5/form'), hasLength(1));
    expect(find.text('Te enviamos nuestro formulario de adopción.'), findsOneWidget);
    expect(find.text('3 preguntas · Esperando respuestas'), findsOneWidget);
    // La fundación no responde su propio formulario
    expect(find.text('Responder formulario'), findsNothing);
  });

  testWidgets('sin preguntas configuradas muestra el mensaje del backend', (tester) async {
    final api = FakeApi(asFoundation: true)..formQuestions.clear();
    await openChat(tester, api, tab: 'Chat', title: 'Matías Adoptante');
    await tester.tap(find.byTooltip('Enviar formulario de adopción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Primero configura las preguntas de tu formulario en Mi fundación.'), findsOneWidget);
  });

  testWidgets('el adoptante no ve el botón de enviar formulario', (tester) async {
    await openChat(tester, FakeApi(), tab: 'Mensajes', title: 'Fundación Patitas');
    expect(find.byTooltip('Enviar formulario de adopción'), findsNothing);
  });

  testWidgets('el adoptante responde el formulario y queda marcado como respondido', (tester) async {
    final api = FakeApi();
    api.foundationSendsForm(5);
    await openChat(tester, api, tab: 'Mensajes', title: 'Fundación Patitas');
    expect(find.text('3 preguntas · Esperando respuestas'), findsOneWidget);

    await tester.tap(find.text('Responder formulario'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Formulario de adopción'), findsOneWidget);

    // Enviar sin las obligatorias marca cada una y no llama a la API
    await tester.tap(find.text('Enviar respuestas'));
    await tester.pumpAndSettle();
    expect(find.text('Responde esta pregunta.'), findsNWidgets(2));
    expect(api.requests.where((r) => r.url.path.endsWith('/answers')), isEmpty);

    await tester.tap(find.text('Casa'));
    await tester.tap(find.text('Sí'));
    await tester.pump();
    expect(find.text('Responde esta pregunta.'), findsNothing);
    await tester.enterText(find.byType(TextField), '  Tuve una perrita 10 años  ');
    await tester.ensureVisible(find.text('Enviar respuestas'));
    await tester.tap(find.text('Enviar respuestas'));
    await tester.pumpAndSettle();

    final sent = api.requests.lastWhere((r) => r.url.path == '/conversations/5/forms/1/answers');
    expect(jsonDecode(sent.body), {'answers': ['Casa', true, 'Tuve una perrita 10 años']});
    // De vuelta en el chat: la respuesta aparece y el formulario ya no se puede responder otra vez
    expect(find.widgetWithText(AppBar, 'Fundación Patitas'), findsOneWidget);
    expect(find.text('Respondí el formulario de adopción.'), findsOneWidget);
    expect(find.text('3 preguntas · Respondido'), findsOneWidget);
    expect(find.text('Responder formulario'), findsNothing);
    expect(find.text('Tuve una perrita 10 años'), findsOneWidget);
  });

  testWidgets('una pregunta opcional se puede dejar sin responder', (tester) async {
    final api = FakeApi();
    api.foundationSendsForm(5);
    await openChat(tester, api, tab: 'Mensajes', title: 'Fundación Patitas');
    await tester.tap(find.text('Responder formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Departamento'));
    await tester.tap(find.text('No'));
    await tester.ensureVisible(find.text('Enviar respuestas'));
    await tester.tap(find.text('Enviar respuestas'));
    await tester.pumpAndSettle();

    final sent = api.requests.lastWhere((r) => r.url.path.endsWith('/answers'));
    expect(jsonDecode(sent.body), {'answers': ['Departamento', false, null]});
    expect(find.text('Sin respuesta'), findsOneWidget);
  });

  testWidgets('la fundación ve las respuestas con el sondeo del chat', (tester) async {
    final api = FakeApi(asFoundation: true);
    final message = api.foundationSendsForm(5);
    await openChat(tester, api, tab: 'Chat', title: 'Matías Adoptante');
    expect(find.text('3 preguntas · Esperando respuestas'), findsOneWidget);

    // Matías responde desde su app
    final form = api.formRequests[message['form_id']]!;
    form['answers'] = ['Casa', true, null];
    api.chatMessages[5]!.add({'id': 900, 'body': 'Respondí el formulario de adopción.', 'created_at': '2026-11-15T12:50:00Z',
      'from_foundation': false, 'kind': 'form_answers', 'form_id': form['id']});
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.text('Respondí el formulario de adopción.'), findsOneWidget);
    expect(find.text('¿Vives en casa o departamento?'), findsOneWidget);
    expect(find.text('Sí'), findsOneWidget);
    expect(find.text('Sin respuesta'), findsOneWidget);
  });
}
