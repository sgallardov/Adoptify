import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/core/location_service.dart';

import 'fake_api.dart';

// Configuración común de todos los tests: el mapa pide la ubicación al abrir, así que se usa la simulada
// (el GPS real no responde en las pruebas). Cada test puede reemplazarla en su propio setUp.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => LocationService.instance = FakeLocation());
  tearDown(() => LocationService.instance = LocationService());
  await testMain();
}
