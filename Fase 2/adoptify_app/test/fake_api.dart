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
// Sesión de la cuenta de fundación de prueba
const foundationToken = 'token-fundacion';

const matias = {
  'id': 1,
  'email': 'matias.adopter@gmail.com',
  'rut': '18765432-1',
  'full_name': 'Matías Adoptante',
  'role': 'adopter',
};

// Cuenta de fundación: entra por el mismo login y la app la lleva a su vista
const patitas = {
  'id': 2,
  'email': 'fundacion@adoptify.cl',
  'rut': '20123456-3',
  'full_name': 'Fundación Patitas',
  'role': 'foundation',
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

final rocky = {...luna, 'id': 8, 'name': 'Rocky', 'status': 'adopted'};

// API simulada con las mismas respuestas que el backend para /auth, /animals y /reports
class FakeApi {
  // El login es obligatorio: por defecto la app abre con la sesión de Matías iniciada.
  // loggedIn: false parte en el login (pruebas de iniciar sesión y registro).
  // asFoundation: true parte con la sesión de la fundación de prueba.
  FakeApi({bool loggedIn = true, bool asFoundation = false})
    : storage = MemoryTokenStorage(
        asFoundation ? foundationToken : (loggedIn ? validToken : null),
      );

  final requests = <http.Request>[];
  final MemoryTokenStorage storage;
  bool offline = false;
  bool animalsFail = false;
  bool foundationsFail = false;
  // Perfil que edita la fundación con sesión (GET y PUT /foundations/me)
  String? foundationDescription = 'Rescatamos perros y gatos de la calle.';
  String? foundationPhoto;
  // Formulario "Quiero adoptar": null hasta que se guarda, como en el backend
  Map<String, dynamic>? adoptionProfile;
  // Respuesta de POST /uploads: null devuelve la URL de la foto; si no, ese código de error
  int? uploadStatus;
  // Ids marcados con el corazón en el match
  final favorites = <int>{};
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
      {
        'id': 1,
        'body': 'Lo vi hace un rato cerca del paradero',
        'created_at': '2026-11-02T23:13:00Z',
        'mine': false,
      },
    ],
  };
  final otherLikes = <int, int>{1: 2};
  final myLikes = <int>{};

  late final AuthController auth = AuthController(
    ApiClient(
      tokenStorage: storage,
      httpClient: MockClient(_handle),
      baseUrl: 'http://api',
    ),
  );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('sin conexión');
    // La foto llega como multipart, no como JSON
    if (request.url.path == '/uploads') {
      if (request.headers['Authorization'] != 'Bearer $validToken')
        return _json(401, {'detail': 'Not authenticated'});
      if (uploadStatus == 415)
        return _json(415, {
          'detail': 'El archivo no es una imagen válida. Usa JPG o PNG.',
        });
      return _json(201, {'url': 'http://api/uploads/foto.png'});
    }
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final loggedIn = request.headers['Authorization'] == 'Bearer $validToken';

    // Comentarios anónimos y "me enteré" de un reporte
    final social = RegExp(r'^/reports/(\d+)/(comments|likes)$')
        .firstMatch(request.url.path);
    if (social != null) {
      final reportId = int.parse(social.group(1)!);
      if (!reports.any((report) => report['id'] == reportId))
        return _json(404, {'detail': 'Reporte no encontrado.'});
      final writing = request.method != 'GET';
      if (writing && !loggedIn)
        return _json(401, {'detail': 'Not authenticated'});
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
        return _json(200, [
          for (final comment in list) _comment(comment, loggedIn),
        ]);
      }
      if (request.method == 'PUT') myLikes.add(reportId);
      if (request.method == 'DELETE') myLikes.remove(reportId);
      final liked = loggedIn && myLikes.contains(reportId);
      return _json(200, {
        'count': (otherLikes[reportId] ?? 0) + (liked ? 1 : 0),
        'liked': liked,
      });
    }

    final favorite = RegExp(r'^/animals/(\d+)/favorite$')
        .firstMatch(request.url.path);
    if (favorite != null) {
      if (!loggedIn) return _json(401, {'detail': 'Not authenticated'});
      final id = int.parse(favorite.group(1)!);
      request.method == 'PUT' ? favorites.add(id) : favorites.remove(id);
      return http.Response('', 204);
    }

    switch (request.url.path) {
      // Login único: sin account_type, entra cualquier cuenta con su rol
      case '/auth/login':
        if (body['email'] == matias['email'] &&
            body['password'] == 'Adoptante2026') {
          return _json(200, {
            'access_token': validToken,
            'token_type': 'bearer',
            'role': 'adopter',
          });
        }
        if (body['email'] == patitas['email'] &&
            body['password'] == 'Fundacion2026') {
          return _json(200, {
            'access_token': foundationToken,
            'token_type': 'bearer',
            'role': 'foundation',
          });
        }
        return _json(401, {'detail': 'Correo o contraseña incorrectos'});
      case '/auth/register':
        if (body['email'] == matias['email'])
          return _json(409, {'detail': 'Ya existe un usuario con ese correo'});
        return _json(201, {
          ...matias,
          'email': body['email'],
          'full_name': body['full_name'],
        });
      case '/auth/me':
        final authorization = request.headers['Authorization'];
        if (authorization == 'Bearer $validToken') return _json(200, matias);
        if (authorization == 'Bearer $foundationToken')
          return _json(200, patitas);
        return _json(401, {'detail': 'Token inválido o expirado'});
      case '/animals':
        if (animalsFail)
          return _json(503, {'detail': 'No se pudo consultar los animales.'});
        return _json(200, [luna, rocky]);
      case '/animals/match':
        if (!loggedIn) return _json(401, {'detail': 'Not authenticated'});
        if (adoptionProfile == null)
          return _json(404, {
            'detail':
                "Completa 'Quiero adoptar' en tu perfil para ver tu match.",
          });
        return _json(200, _matchCards);
      case '/animals/favorites':
        if (!loggedIn) return _json(401, {'detail': 'Not authenticated'});
        return _json(200, [
          for (final card in _matchCards)
            if (favorites.contains(card['id'])) card,
        ]);
      case '/animals/nearby':
        if (animalsFail)
          return _json(503, {'detail': 'No se pudo consultar los animales.'});
        return _json(200, [luna]);
      case '/users/me/adoption-profile':
        if (request.headers['Authorization'] != 'Bearer $validToken')
          return _json(401, {'detail': 'Not authenticated'});
        if (request.method == 'PUT') adoptionProfile = body;
        return _json(200, adoptionProfile);
      case '/veterinary-clinics':
        return _json(200, [
          {
            'id': 1, 'name': 'Clínica Urgencias Vet', 'address': 'Av. Grecia 100', 'commune': 'Ñuñoa',
            'phone': '+56 2 2222 3333', 'opening_hours': '24/7', 'emergency': true,
            'latitude': -33.455, 'longitude': -70.605,
          },
          {
            'id': 2, 'name': 'Veterinaria del Barrio', 'address': null, 'commune': null,
            'phone': null, 'opening_hours': 'Mo-Fr 09:00-19:00', 'emergency': false,
            'latitude': -33.47, 'longitude': -70.63,
          },
        ]);
      case '/foundations/me':
        if (request.headers['Authorization'] != 'Bearer $foundationToken') {
          return _json(403, {'detail': 'Solo una cuenta de fundación puede editar su perfil.'});
        }
        if (request.method == 'PUT') {
          final description = (body['description'] as String? ?? '').trim();
          if (description.length < 20) {
            return _json(422, {'detail': [{'msg': 'Value error, La descripción debe tener al menos 20 caracteres.'}]});
          }
          foundationDescription = description;
          foundationPhoto = body['photo_url'] as String?;
        }
        return _json(200, {
          'id': 1, 'name': 'Fundación Patitas', 'description': foundationDescription,
          'address': 'Av. Siempre Viva 123', 'commune': 'Providencia', 'city': 'Santiago',
          'phone': '+56 9 1111 2222', 'email': 'hola@patitas.cl', 'is_verified': true,
          'photo_url': foundationPhoto, 'latitude': -33.43, 'longitude': -70.61, 'animals': [luna],
        });
      case '/foundations':
        if (foundationsFail)
          return _json(503, {
            'detail': 'No se pudo consultar las fundaciones.',
          });
        return _json(200, _nearestFirst(request.url.queryParameters, [
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
          {
            'id': 3,
            'name': 'Huellas del Sur',
            'description':
                'Rescatamos, rehabilitamos y buscamos hogares responsables.',
            'address': null,
            'commune': 'La Florida',
            'city': 'Santiago',
            'phone': null,
            'email': 'hola@huellasdelsur.cl',
            'is_verified': true,
            'latitude': null,
            'longitude': null,
            'animals': [
              {
                ...luna,
                'id': 12,
                'name': 'Mora',
                'species': 'gato',
                'age_months': 14,
                'size': 'pequeño',
                'public_commune': 'La Florida',
                'photo_url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba',
              },
              {
                ...luna,
                'id': 13,
                'name': 'Bruno',
                'age_months': 30,
                'size': 'grande',
                'public_commune': 'La Florida',
                'photo_url':
                    'https://images.unsplash.com/photo-1558788353-f76d92427f16',
              },
            ],
          },
          {
            'id': 4,
            'name': 'Patitas de Cerro',
            'description': 'Red vecinal de rescate y adopción en la costa.',
            'address': null,
            'commune': 'Valparaíso',
            'city': 'Valparaíso',
            'phone': null,
            'email': 'contacto@patitascerro.cl',
            'is_verified': true,
            'latitude': -33.0472,
            'longitude': -71.6127,
            'animals': [
              {
                ...luna,
                'id': 14,
                'name': 'Toto',
                'age_months': 9,
                'size': 'pequeño',
                'public_commune': 'Valparaíso',
                'photo_url': 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e',
              },
            ],
          },
          {
            'id': 5,
            'name': 'Bigotes Libres',
            'description':
                'Especialistas en gatos que necesitan una segunda oportunidad.',
            'address': null,
            'commune': 'Ñuñoa',
            'city': 'Santiago',
            'phone': null,
            'email': 'hola@bigoteslibres.cl',
            'is_verified': false,
            'latitude': null,
            'longitude': null,
            'animals': [
              {
                ...luna,
                'id': 15,
                'name': 'Nube',
                'species': 'gato',
                'age_months': 6,
                'size': 'pequeño',
                'public_commune': 'Ñuñoa',
                'photo_url': 'https://images.unsplash.com/photo-1495360010541-f48722b34f7d',
              },
              {
                ...luna,
                'id': 16,
                'name': 'Simón',
                'species': 'gato',
                'age_months': 36,
                'size': 'mediano',
                'public_commune': 'Ñuñoa',
                'photo_url': 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131',
              },
            ],
          },
          {
            'id': 6,
            'name': 'Refugio El Arrayán',
            'description':
                'Cuidado temporal y rehabilitación de perros mayores.',
            'address': null,
            'commune': 'Puente Alto',
            'city': 'Santiago',
            'phone': null,
            'email': 'equipo@elarrayan.cl',
            'is_verified': true,
            'latitude': null,
            'longitude': null,
            'animals': [
              {
                ...luna,
                'id': 17,
                'name': 'Canela',
                'age_months': 84,
                'size': 'mediano',
                'public_commune': 'Puente Alto',
                'photo_url': 'https://images.unsplash.com/photo-1587300003388-59208cc962cb',
              },
            ],
          },
          {
            'id': 7,
            'name': 'Rescate Horizonte',
            'description':
                'Un equipo de voluntariado que acompaña rescates urgentes.',
            'address': null,
            'commune': 'Concepción',
            'city': 'Concepción',
            'phone': null,
            'email': 'hola@rescatehorizonte.cl',
            'is_verified': false,
            'latitude': null,
            'longitude': null,
            'animals': [
              {
                ...luna,
                'id': 18,
                'name': 'Kira',
                'age_months': 18,
                'size': 'mediano',
                'public_commune': 'Concepción',
                'photo_url': 'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8',
              },
            ],
          },
          {
            'id': 8,
            'name': 'Casa Michi',
            'description':
                'Hogar temporal para gatos rescatados y socialización felina.',
            'address': null,
            'commune': 'Quilicura',
            'city': 'Santiago',
            'phone': null,
            'email': 'equipo@casamichi.cl',
            'is_verified': true,
            'latitude': null,
            'longitude': null,
            'animals': [
              {
                ...luna,
                'id': 19,
                'name': 'Olivia',
                'species': 'gato',
                'age_months': 20,
                'size': 'pequeño',
                'public_commune': 'Quilicura',
                'photo_url': 'https://images.unsplash.com/photo-1494256997604-768d1f608cac',
              },
            ],
          },
        ]));
      case '/reports/nearby':
        return _json(200, reports);
      case '/reports':
        if (request.headers['Authorization'] != 'Bearer $validToken') {
          return _json(401, {'detail': 'Not authenticated'});
        }
        final report = {
          'id': reports.length + 1,
          for (final field in [
            'species',
            'size',
            'weight_kg',
            'color',
            'features',
            'conditions',
            'behaviors',
          ])
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

  // Sin comuna ni coordenadas: la tarjeta del match no muestra dónde está el animal
  static const _matchCards = <Map<String, dynamic>>[
    {
      'id': 7,
      'foundation_name': 'Fundación Patitas',
      'name': 'Luna',
      'species': 'perro',
      'breed': null,
      'age_months': 18,
      'gender': 'hembra',
      'size': 'mediano',
      'energy_level': 3,
      'description': 'Muy cariñosa',
      'photo_url': null,
      'match_score': 100.0,
    },
    {
      'id': 9,
      'foundation_name': 'Fundación Patitas',
      'name': 'Thor',
      'species': 'perro',
      'breed': null,
      'age_months': 60,
      'gender': 'macho',
      'size': 'grande',
      'energy_level': 5,
      'description': null,
      'photo_url': null,
      'match_score': 55.0,
    },
  ];

  // 'mine' marca los escritos con la cuenta de prueba; la API solo lo dice si hay sesión
  Map<String, dynamic> _comment(Map<String, dynamic> comment, bool loggedIn) =>
      {
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

// Como GET /foundations con lat y lng: agrega distance_km, ordena por cercanía y deja al final las sin ubicación
List<Map<String, dynamic>> _nearestFirst(Map<String, String> query, List<Map<String, dynamic>> foundations) {
  final lat = double.tryParse(query['lat'] ?? '');
  final lng = double.tryParse(query['lng'] ?? '');
  if (lat == null || lng == null) return foundations;
  final withDistance = [
    for (final item in foundations)
      {
        ...item,
        'distance_km': item['latitude'] == null
            ? null
            : (const Distance().as(
                        LengthUnit.Meter,
                        LatLng(lat, lng),
                        LatLng(item['latitude'] as double, item['longitude'] as double),
                      ) /
                      100)
                  .round() /
                10,
      },
  ];
  return withDistance
    ..sort((a, b) {
      final da = a['distance_km'] as double?;
      final db = b['distance_km'] as double?;
      if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
      return da.compareTo(db);
    });
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
final tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
  ),
);

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
