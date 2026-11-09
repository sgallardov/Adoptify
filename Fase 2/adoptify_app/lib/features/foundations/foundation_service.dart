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
}
