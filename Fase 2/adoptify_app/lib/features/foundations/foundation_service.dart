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
  final List<Animal> animals;

  String get place => [?commune, city].join(', ');
}

class FoundationService {
  FoundationService(this._api);

  final ApiClient _api;

  Future<List<Foundation>> fetchFoundations() async {
    final data = await _api.get('/foundations') as List<dynamic>;
    return [for (final item in data) Foundation.fromJson(item as Map<String, dynamic>)];
  }
}
