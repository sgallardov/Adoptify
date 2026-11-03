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
  'public_commune': 'Ñuñoa',
  'commune_point': [-33.46, -70.60],
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
  bool foundationsFail = false;
  // Formulario "Quiero adoptar": null hasta que se guarda, como en el backend
  Map<String, dynamic>? adoptionProfile;
  // Respuesta de POST /uploads: null devuelve la URL de la foto; si no, ese código de error
  int? uploadStatus;
  final reports = <Map<String, dynamic>>[
    {
      'id': 1,
      'species': 'perro',
      'size': 'mediano',
      'weight_kg': 12.5,
      'color': 'Café',
      'features': 'Collar rojo',
      'conditions': ['herido', 'desnutrido'],
      'behaviors': ['asustado'],
      'description': 'Perro café con collar rojo cerca del paradero',
      'photo_url': null,
      'status': 'reported',
      'latitude': -33.44,
      'longitude': -70.66,
      'created_at': '2026-10-28T15:30:00Z',
      'distance_km': 2.5,
    },
  ];

  // Comentarios por reporte y "me enteré": los de otros vecinos y los de la cuenta de prueba
  final comments = <int, List<Map<String, dynamic>>>{
    1: [
      {'id': 1, 'body': 'Lo vi hace un rato cerca del paradero', 'created_at': '2026-11-02T23:13:00Z', 'mine': false},
    ],
  };
  final otherLikes = <int, int>{1: 2};
  final myLikes = <int>{};

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
    final loggedIn = request.headers['Authorization'] == 'Bearer $validToken';

    // Comentarios anónimos y "me enteré" de un reporte
    final social = RegExp(r'^/reports/(\d+)/(comments|likes)$').firstMatch(request.url.path);
    if (social != null) {
      final reportId = int.parse(social.group(1)!);
      if (!reports.any((report) => report['id'] == reportId)) return _json(404, {'detail': 'Reporte no encontrado.'});
      final writing = request.method != 'GET';
      if (writing && !loggedIn) return _json(401, {'detail': 'Not authenticated'});
      if (social.group(2) == 'comments') {
        final list = comments.putIfAbsent(reportId, () => []);
        if (writing) {
          final comment = {
            'id': list.length + 1,
            'body': (body['body'] as String).trim(),
            'created_at': '2026-11-02T23:30:00Z',
            'mine': true,
          };
          list.add(comment);
          return _json(201, _comment(comment, loggedIn));
        }
        return _json(200, [for (final comment in list) _comment(comment, loggedIn)]);
      }
      if (request.method == 'PUT') myLikes.add(reportId);
      if (request.method == 'DELETE') myLikes.remove(reportId);
      final liked = loggedIn && myLikes.contains(reportId);
      return _json(200, {'count': (otherLikes[reportId] ?? 0) + (liked ? 1 : 0), 'liked': liked});
    }

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
          luna,
        ]);
      case '/users/me/adoption-profile':
        if (request.headers['Authorization'] != 'Bearer $validToken') return _json(401, {'detail': 'Not authenticated'});
        if (request.method == 'PUT') adoptionProfile = body;
        return _json(200, adoptionProfile);
      case '/foundations':
        if (foundationsFail) return _json(503, {'detail': 'No se pudo consultar las fundaciones.'});
        return _json(200, [
          {
            'id': 1,
            'name': 'Fundación Patitas',
            'description': 'Rescatamos perros y gatos de la calle.',
            'address': 'Av. Siempre Viva 123',
            'commune': 'Providencia',
            'city': 'Santiago',
            'phone': '+56 9 1111 2222',
            'email': 'hola@patitas.cl',
            'is_verified': true,
            'latitude': -33.43,
            'longitude': -70.61,
            'animals': [luna],
          },
          {
            'id': 2,
            'name': 'Refugio Sin Casos',
            'description': null,
            'address': null,
            'commune': null,
            'city': 'Valparaíso',
            'phone': null,
            'email': 'refugio@ejemplo.cl',
            'is_verified': false,
            'latitude': null,
            'longitude': null,
            'animals': [],
          },
        ]);
      case '/reports/nearby':
        return _json(200, reports);
      case '/reports':
        if (request.headers['Authorization'] != 'Bearer $validToken') {
          return _json(401, {'detail': 'Not authenticated'});
        }
        final report = {
          'id': reports.length + 1,
          for (final field in ['species', 'size', 'weight_kg', 'color', 'features', 'conditions', 'behaviors'])
            field: body[field],
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

  // 'mine' marca los escritos con la cuenta de prueba; la API solo lo dice si hay sesión
  Map<String, dynamic> _comment(Map<String, dynamic> comment, bool loggedIn) => {
        'id': comment['id'],
        'body': comment['body'],
        'created_at': comment['created_at'],
        'is_mine': loggedIn && comment['mine'] == true,
      };

  http.Response _json(int status, Object? body) => http.Response.bytes(
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
