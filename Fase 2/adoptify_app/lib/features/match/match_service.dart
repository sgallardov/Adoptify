import '../../core/api_client.dart';
import '../../core/config.dart';
import '../map/map_service.dart';

// Tarjeta del match: no trae ubicación a propósito, solo lo que sirve para decidir
class MatchAnimal {
  const MatchAnimal({
    required this.id,
    required this.name,
    required this.species,
    required this.size,
    required this.gender,
    required this.energyLevel,
    required this.matchScore,
    this.ageMonths,
    this.breed,
    this.description,
    this.photoUrl,
    this.foundationName,
  });

  factory MatchAnimal.fromJson(Map<String, dynamic> json) => MatchAnimal(
        id: json['id'] as int,
        name: json['name'] as String,
        species: json['species'] as String,
        size: json['size'] as String,
        gender: json['gender'] as String,
        energyLevel: json['energy_level'] as int,
        matchScore: (json['match_score'] as num).toDouble(),
        ageMonths: json['age_months'] as int?,
        breed: json['breed'] as String?,
        description: json['description'] as String?,
        photoUrl: mediaUrl(json['photo_url'] as String?),
        foundationName: json['foundation_name'] as String?,
      );

  final int id;
  final String name;
  final String species;
  final String size;
  final String gender;
  final int energyLevel;
  final double matchScore;
  final int? ageMonths;
  final String? breed;
  final String? description;
  final String? photoUrl;
  final String? foundationName;

  int get percent => matchScore.round();
  String get age => formatAge(ageMonths);
  String get energyLabel => energyLevel <= 2 ? 'Tranquilo' : (energyLevel == 3 ? 'Moderado' : 'Muy activo');
}

// GET /animals/match: de dónde salen las tarjetas. Si luego cambia la fuente, solo se toca este archivo.
class MatchService {
  MatchService(this._api);

  final ApiClient _api;

  // Lanza ApiException 404 si la persona aún no completó "Quiero adoptar"
  Future<List<MatchAnimal>> fetch() async {
    final data = await _api.get('/animals/match') as List<dynamic>;
    return [for (final item in data) MatchAnimal.fromJson(item as Map<String, dynamic>)];
  }

  // Favoritos: los que la persona marcó con el corazón, el más reciente primero
  Future<List<MatchAnimal>> fetchFavorites() async {
    final data = await _api.get('/animals/favorites') as List<dynamic>;
    return [for (final item in data) MatchAnimal.fromJson(item as Map<String, dynamic>)];
  }

  Future<void> addFavorite(int animalId) => _api.put('/animals/$animalId/favorite');

  Future<void> removeFavorite(int animalId) => _api.delete('/animals/$animalId/favorite');
}
