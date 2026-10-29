import 'dart:convert';

import 'package:adoptify_app/core/api_client.dart';
import 'package:adoptify_app/core/token_storage.dart';
import 'package:adoptify_app/features/auth/auth_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const validToken = 'token-valido';

const matias = {
  'id': 1,
  'email': 'matias.adopter@gmail.com',
  'rut': '18765432-1',
  'full_name': 'Matías Adoptante',
  'role': 'adopter',
};

// API simulada con las mismas respuestas que el backend para /auth
class FakeApi {
  final requests = <http.Request>[];
  final storage = MemoryTokenStorage();
  bool offline = false;

  late final AuthController auth = AuthController(
    ApiClient(tokenStorage: storage, httpClient: MockClient(_handle), baseUrl: 'http://api'),
  );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('sin conexión');
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;

    switch (request.url.path) {
      case '/auth/login':
        if (body['email'] != matias['email'] || body['password'] != 'Adoptante2026') {
          return _json(401, {'detail': 'Correo o contraseña incorrectos'});
        }
        if (body['account_type'] != 'user') {
          return _json(403, {'detail': 'Esta cuenta no es de este tipo. Inicia sesión en la pestaña Usuario.'});
        }
        return _json(200, {'access_token': validToken, 'token_type': 'bearer', 'role': 'adopter'});
      case '/auth/register':
        if (body['email'] == matias['email']) return _json(409, {'detail': 'Ya existe un usuario con ese correo'});
        return _json(201, {...matias, 'email': body['email'], 'full_name': body['full_name']});
      case '/auth/me':
        if (request.headers['Authorization'] != 'Bearer $validToken') {
          return _json(401, {'detail': 'Token inválido o expirado'});
        }
        return _json(200, matias);
    }
    return _json(404, {'detail': 'Not Found'});
  }

  http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}
