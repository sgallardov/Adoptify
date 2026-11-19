import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adoptify_app/app/app.dart';

import 'fake_api.dart';

// Cuestionario de adopción por chat (HU-G3): al apretar "Conversar" junto a un interesado, el chat le
// hace las preguntas de la fundación una a una y el adoptante responde con botones o escribiendo.

Future<void> openChat(WidgetTester tester, FakeApi api) async {
  await tester.pumpWidget(AdoptifyApp(auth: api.auth));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mensajes').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fundación Patitas'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> lastAnswer(FakeApi api) => jsonDecode(
  api.requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/answer')).body,
) as Map<String, dynamic>;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Conversar desde los interesados de una mascota empieza el cuestionario', (tester) async {
    final api = FakeApi(asFoundation: true);
    await tester.pumpWidget(AdoptifyApp(auth: api.auth));
    await tester.pumpAndSettle();
    // Inicio → Mis animales (el acceso queda bajo la barra inferior en la pantalla de prueba)
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis animales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 interesados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversar').first);
    await tester.pumpAndSettle();

    final opened = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path == '/conversations');
    expect(jsonDecode(opened.body), {'user_id': 1, 'animal_id': 7});
    // La fundación ve la pregunta como un mensaje, sin botones para responderla
    expect(find.text('Pregunta 1 de 3'), findsOneWidget);
    expect(find.text('¿Vives en casa o departamento?'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Casa'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('el adoptante responde una pregunta a la vez y al final vuelve el chat normal', (tester) async {
    final api = FakeApi()..startQuestionnaire(5, 1);
    await openChat(tester, api);

    // Alternativas: botones en lugar del campo de texto
    expect(find.text('Pregunta 1 de 3'), findsOneWidget);
    expect(find.text('Elige tu respuesta · Pregunta 1 de 3'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Departamento'));
    await tester.pumpAndSettle();
    expect(lastAnswer(api), {'answer': 'Departamento'});
    expect(find.text('Departamento'), findsOneWidget);

    // Sí o no
    expect(find.text('Pregunta 2 de 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sí'));
    await tester.pumpAndSettle();
    expect(lastAnswer(api), {'answer': true});

    // Pregunta abierta: lo que se escribe es la respuesta
    expect(find.text('Pregunta 3 de 3'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Escribe tu respuesta…'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Tuve un gato por 10 años  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(lastAnswer(api), {'answer': 'Tuve un gato por 10 años'});

    expect(find.text(FakeApi.questionnaireFinished), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Escribe un mensaje…'), findsOneWidget);
    expect(find.text('Prefiero no responder'), findsNothing);
    expect(api.formRequests[1]!['answers'], ['Departamento', true, 'Tuve un gato por 10 años']);
  });

  testWidgets('una pregunta opcional se puede saltar', (tester) async {
    final api = FakeApi()..startQuestionnaire(5, 1);
    await openChat(tester, api);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Casa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'No'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prefiero no responder'));
    await tester.pumpAndSettle();
    expect(lastAnswer(api), {'answer': null});
    expect(find.text(FakeApi.questionnaireFinished), findsOneWidget);
  });

  testWidgets('las preguntas que llegan con el chat abierto aparecen solas en 10 s', (tester) async {
    final api = FakeApi();
    await openChat(tester, api);
    expect(find.byType(TextField), findsOneWidget);

    api.startQuestionnaire(5, 1);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('¿Vives en casa o departamento?'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Casa'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
