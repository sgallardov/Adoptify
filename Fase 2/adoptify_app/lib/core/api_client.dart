import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'token_storage.dart';

// Error de la API. statusCode es null si no hubo respuesta (sin conexión o timeout).
class ApiException implements Exception {
  ApiException({this.statusCode, this.detail});

  final int? statusCode;
  final Object? detail;
}

// Cliente HTTP de la app: equivalente a services/api.ts del portal.
// Adjunta el token Bearer a cada petición y avisa cuando la sesión deja de ser válida.
class ApiClient {
  ApiClient({required this._tokenStorage, http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? apiUrl;

  final TokenStorage _tokenStorage;
  final http.Client _http;
  final String _baseUrl;
  String? _token;

  // Se llama cuando una petición con token recibe 401 (token vencido o inválido)
  void Function()? onUnauthorized;

  bool get hasToken => _token != null;

  Future<String?> loadToken() async => _token = await _tokenStorage.read();

  Future<void> setToken(String? token) async {
    _token = token;
    await _tokenStorage.write(token);
  }

  Future<dynamic> get(String path, {Map<String, Object>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send('POST', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body, Map<String, Object>? query}) async {
    final token = _token;
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null) {
      uri = uri.replace(queryParameters: query.map((key, value) => MapEntry(key, '$value')));
    }
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 10)),
      );
    } on TimeoutException {
      throw ApiException();
    } on http.ClientException {
      throw ApiException();
    }

    final text = utf8.decode(response.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException(
        statusCode: response.statusCode,
        detail: data is Map<String, dynamic> ? data['detail'] : null,
      );
    }
    return data;
  }
}

// Mensaje para mostrar al usuario, con las mismas reglas que errorMessage() del portal
String errorMessage(Object error, String fallback) {
  if (error is! ApiException) return fallback;
  if (error.statusCode == null) return 'No pudimos conectar con el servidor. Inténtalo nuevamente.';
  final detail = error.detail;
  if (detail is String) return detail;
  // Errores de validación (422): Pydantic envía una lista; se muestra el primer motivo propio
  if (detail is List && detail.isNotEmpty && detail.first is Map) {
    final message = (detail.first as Map)['msg'];
    if (message is String && message.startsWith('Value error, ')) {
      return message.replaceFirst('Value error, ', '');
    }
  }
  if (error.statusCode == 422) {
    return 'Revisa los datos: el correo debe ser válido y la contraseña tener al menos 8 caracteres.';
  }
  return fallback;
}
