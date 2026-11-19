import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../map/map_service.dart';

// Tarjeta del match: no trae ubicación a propósito, solo lo que sirve para decidir
// Porcentaje de compatibilidad tal como se muestra ("83 % compatible"); el espacio no se corta entre líneas
String percentLabel(num percent) => '${percent.round()}\u00a0%';
String compatibilityLabel(num percent) => '${percentLabel(percent)} compatible';

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
    this.status = 'available',
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
        status: json['status'] as String? ?? 'available',
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
  final String status;

  int get percent => matchScore.round();
  String get age => formatAge(ageMonths);
  String get energyLabel => formatEnergy(energyLevel);
  bool get lowCompatibility => matchScore < lowCompatibilityScore;

  // Para abrir la misma ficha que desde el mapa (/animales/:id). El match no trae la comuna a propósito.
  Animal toAnimal() => Animal(
        id: id,
        name: name,
        species: species,
        ageMonths: ageMonths,
        size: size,
        status: status,
        photoUrl: photoUrl,
        foundationName: foundationName,
        description: description,
        breed: breed,
        gender: gender,
        energyLevel: energyLevel,
      );
}

// Bajo este porcentaje la tarjeta va al final del mazo con el rótulo "Poco compatible"
const lowCompatibilityScore = 40.0;

// Ordena el mazo: primero los compatibles, al final los poco compatibles, sin los descartados
List<MatchAnimal> buildDeck(List<MatchAnimal> cards, Set<int> discarded) => [
      for (final card in cards) if (!discarded.contains(card.id) && !card.lowCompatibility) card,
      for (final card in cards) if (!discarded.contains(card.id) && card.lowCompatibility) card,
    ];

// Descartes del match ("Pasar"): se guardan en el dispositivo, por usuario, para que no vuelvan al recargar
class DiscardStore {
  const DiscardStore(this.userId);

  final int userId;
  String get _key => 'match_discarded_$userId';

  Future<Set<int>> read() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
      return {for (final id in saved) ?int.tryParse(id)};
    } catch (_) {
      return {}; // Sin almacenamiento: los descartes duran solo esta sesión
    }
  }

  Future<void> write(Set<int> ids) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, [for (final id in ids) '$id']);
    } catch (_) {}
  }
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
