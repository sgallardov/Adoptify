import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../map/map_service.dart';

// Fundación con sus mascotas disponibles para adopción (GET /foundations)
class Foundation {
  const Foundation({
    required this.id,
    required this.name,
    required this.city,
    required this.email,
    required this.isVerified,
    required this.animals,
    this.description,
    this.address,
    this.commune,
    this.phone,
    this.photoUrl,
    this.position,
    this.distanceKm,
  });

  factory Foundation.fromJson(Map<String, dynamic> json) => Foundation(
        id: json['id'] as int,
        name: json['name'] as String,
        city: json['city'] as String,
        email: json['email'] as String,
        isVerified: json['is_verified'] as bool,
        description: json['description'] as String?,
        address: json['address'] as String?,
        commune: json['commune'] as String?,
        phone: json['phone'] as String?,
        photoUrl: json['photo_url'] as String?,
        position: json['latitude'] == null
            ? null
            : LatLng((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        animals: [
          for (final item in json['animals'] as List<dynamic>) Animal.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int id;
  final String name;
  final String city;
  final String email;
  final bool isVerified;
  final String? description;
  final String? address;
  final String? commune;
  final String? phone;
  // Foto de perfil (enlace firmado; null sin sesión o si no tiene)
  final String? photoUrl;
  // Sede de la fundación: su pin en el mapa
  final LatLng? position;
  // Solo si se pidió con tu ubicación
  final double? distanceKm;
  final List<Animal> animals;

  String get place => [?commune, city].join(', ');
}

// Fecha de ingreso como la maneja la API (yyyy-MM-dd) y como se muestra (dd/MM/yyyy)
String dateToApi(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String dateToDisplay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

// Socio visto por la propia fundación (CRUD privado /foundations/me/members). El aporte es de uso interno.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.joinedAt,
    required this.isPublic,
    this.contribution,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as int,
        name: json['name'] as String,
        // La API manda el decimal como texto ("15000.50")
        contribution: json['contribution'] == null ? null : num.parse('${json['contribution']}'),
        joinedAt: DateTime.parse(json['joined_at'] as String),
        isPublic: json['is_public'] as bool,
      );

  final int id;
  final String name;
  final num? contribution;
  final DateTime joinedAt;
  final bool isPublic;
}

// Socio en la ficha pública "Nuestros socios": solo nombre y fecha de ingreso, nunca el aporte
class PublicMember {
  const PublicMember({required this.name, required this.joinedAt});

  factory PublicMember.fromJson(Map<String, dynamic> json) =>
      PublicMember(name: json['name'] as String, joinedAt: DateTime.parse(json['joined_at'] as String));

  final String name;
  final DateTime joinedAt;
}

class FoundationService {
  FoundationService(this._api);

  final ApiClient _api;

  // Con tu ubicación vienen de la más cercana a la más lejana; sin ella, por nombre
  Future<List<Foundation>> fetchFoundations({LatLng? origin}) async {
    final query = origin == null ? null : {'lat': origin.latitude, 'lng': origin.longitude};
    final data = await _api.get('/foundations', query: query) as List<dynamic>;
    return [for (final item in data) Foundation.fromJson(item as Map<String, dynamic>)];
  }

  // Perfil de la fundación con sesión iniciada (vista de fundación)
  Future<Foundation> fetchMine() async =>
      Foundation.fromJson(await _api.get('/foundations/me') as Map<String, dynamic>);

  // La descripción es obligatoria; photoUrl null quita la foto
  Future<Foundation> updateMine({required String description, String? photoUrl}) async => Foundation.fromJson(
        await _api.put('/foundations/me', {'description': description, 'photo_url': photoUrl}) as Map<String, dynamic>,
      );

  // Vista del adoptante: socios que la fundación marcó como públicos
  Future<List<PublicMember>> fetchPublicMembers(int foundationId) async {
    final data = await _api.get('/foundations/$foundationId/members/public') as List<dynamic>;
    return [for (final item in data) PublicMember.fromJson(item as Map<String, dynamic>)];
  }

  // Vista de la fundación: CRUD privado de sus socios
  Future<List<Member>> fetchMembers() async {
    final data = await _api.get('/foundations/me/members') as List<dynamic>;
    return [for (final item in data) Member.fromJson(item as Map<String, dynamic>)];
  }

  Future<Member> saveMember({
    int? id,
    required String name,
    required DateTime joinedAt,
    required bool isPublic,
    String? contribution,
  }) async {
    final body = {
      'name': name,
      'contribution': contribution,
      'joined_at': dateToApi(joinedAt),
      'is_public': isPublic,
    };
    final data = id == null
        ? await _api.post('/foundations/me/members', body)
        : await _api.put('/foundations/me/members/$id', body);
    return Member.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMember(int id) async {
    await _api.delete('/foundations/me/members/$id');
  }
}
