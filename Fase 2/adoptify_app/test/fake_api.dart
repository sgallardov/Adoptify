import 'dart:convert';
import 'dart:typed_data';

import 'package:adoptify_app/core/api_client.dart';
import 'package:adoptify_app/core/location_service.dart';
import 'package:adoptify_app/core/photo_service.dart';
import 'package:adoptify_app/core/token_storage.dart';
import 'package:adoptify_app/features/auth/auth_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const validToken = 'token-valido';

const matias = {
  'id': 1,
  'email': 'matias.adopter@gmail.com',
  'rut': '18765432-1',
  'full_name': 'Matías Adoptante',
  'role': 'adopter',
};

const luna = {
  'id': 7,
  'foundation_id': 1,
  'foundation_name': 'Fundación Patitas',
  'name': 'Luna',
  'species': 'perro',
  'breed': null,
  'age_months': 18,
  'gender': 'hembra',
  'size': 'mediano',
  'energy_level': 3,
  'description': null,
  'status': 'available',
  'photo_url': null,
  'latitude': -33.4378,
  'longitude': -70.6505,
};

final rocky = {
  ...luna,
  'id': 8,
  'name': 'Rocky',
  'status': 'adopted',
};

// API simulada con las mismas respuestas que el backend para /auth, /animals y /reports
class FakeApi {
  final requests = <http.Request>[];
  final storage = MemoryTokenStorage();
  bool offline = false;
  bool animalsFail = false;
  // Respuesta de POST /uploads: null devuelve la URL de la foto; si no, ese código de error
  int? uploadStatus;
  final reports = <Map<String, dynamic>>[
    {
      'id': 1,
      'description': 'Perro café con collar rojo cerca del paradero',
      'photo_url': null,
      'status': 'reported',
      'latitude': -33.44,
      'longitude': -70.66,
      'created_at': '2026-10-28T15:30:00Z',
      'distance_km': 2.5,
    },
  ];

  late final AuthController auth = AuthController(
    ApiClient(tokenStorage: storage, httpClient: MockClient(_handle), baseUrl: 'http://api'),
  );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('sin conexión');
    // La foto llega como multipart, no como JSON
    if (request.url.path == '/uploads') {
      if (request.headers['Authorization'] != 'Bearer $validToken') return _json(401, {'detail': 'Not authenticated'});
      if (uploadStatus == 415) return _json(415, {'detail': 'El archivo no es una imagen válida. Usa JPG o PNG.'});
      return _json(201, {'url': 'http://api/uploads/foto.png'});
    }
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
      case '/animals':
        if (animalsFail) return _json(503, {'detail': 'No se pudo consultar los animales.'});
        return _json(200, [luna, rocky]);
      case '/animals/nearby':
        if (animalsFail) return _json(503, {'detail': 'No se pudo consultar los animales.'});
        return _json(200, [
          {...luna, 'distance_km': 1.25},
        ]);
      case '/reports/nearby':
        return _json(200, reports);
      case '/reports':
        if (request.headers['Authorization'] != 'Bearer $validToken') {
          return _json(401, {'detail': 'Not authenticated'});
        }
        final report = {
          'id': reports.length + 1,
          'description': body['description'],
          'photo_url': body['photo_url'],
          'status': 'reported',
          'latitude': body['latitude'],
          'longitude': body['longitude'],
          'created_at': '2026-10-29T12:00:00Z',
        };
        reports.add({...report, 'distance_km': 0.1});
        return _json(201, report);
    }
    return _json(404, {'detail': 'Not Found'});
  }

  http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

// Ubicación simulada: devuelve un punto fijo o falla con el mensaje indicado
class FakeLocation extends LocationService {
  FakeLocation({this.position = const LatLng(-33.4378, -70.6505), this.error});

  final LatLng position;
  final String? error;

  @override
  Future<LatLng> current() async {
    if (error != null) throw LocationException(error!);
    return position;
  }
}

// PNG de 1×1 píxel: suficiente para la vista previa de la foto
final tinyPng = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
));

// Cámara y galería simuladas: devuelven siempre la misma foto, o null si se cancela
class FakePhotos extends PhotoService {
  FakePhotos({this.cancel = false});

  final bool cancel;
  final sources = <PhotoSource>[];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    sources.add(source);
    if (cancel) return null;
    return PickedPhoto(bytes: tinyPng, filename: 'perro.png');
  }
}
