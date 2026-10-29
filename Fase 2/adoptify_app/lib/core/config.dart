import 'package:flutter/foundation.dart';

// URL de la API. Se puede cambiar al ejecutar:
//   flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1
// El emulador de Android llega al localhost del computador por 10.0.2.2.
const _apiUrlOverride = String.fromEnvironment('API_URL');

String get apiUrl {
  if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
  if (kIsWeb) return 'http://localhost:8000/api/v1';
  return 'http://10.0.2.2:8000/api/v1';
}
