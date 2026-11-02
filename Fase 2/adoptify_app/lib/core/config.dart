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

// Las fotos subidas (/uploads/...) se piden al mismo servidor que la API.
// El backend arma la URL con la dirección desde la que se subió: una foto subida desde el portal
// (localhost) no abriría en el emulador (10.0.2.2), y al revés.
String? mediaUrl(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.path.startsWith('/uploads/')) return url;
  return Uri.parse(apiUrl).replace(path: uri.path, query: null).toString();
}
