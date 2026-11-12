import '../../core/api_client.dart';
import '../../core/config.dart';

const animalStatusLabels = <String, String>{
  'available': 'En adopción',
  'in_process': 'En proceso',
  'adopted': 'Adoptado',
};

class ManagedAnimal {
  const ManagedAnimal({
    required this.id,
    required this.name,
    required this.species,
    required this.gender,
    required this.size,
    required this.energyLevel,
    required this.status,
    this.ageMonths,
    this.description,
    this.photoUrl,
    this.keepingPlaceType,
    this.keepingPlaceAddress,
  });

  factory ManagedAnimal.fromJson(Map<String, dynamic> json) => ManagedAnimal(
        id: json['id'] as int,
        name: json['name'] as String,
        species: json['species'] as String,
        gender: json['gender'] as String,
        size: json['size'] as String,
        energyLevel: json['energy_level'] as int? ?? 3,
        status: json['status'] as String,
        ageMonths: json['age_months'] as int?,
        description: json['description'] as String?,
        photoUrl: mediaUrl(json['photo_url'] as String?),
        keepingPlaceType: json['keeping_place_type'] as String?,
        keepingPlaceAddress: json['keeping_place_address'] as String?,
      );

  final int id;
  final String name;
  final String species;
  final String gender;
  final String size;
  final int energyLevel;
  final String status;
  final int? ageMonths;
  final String? description;
  final String? photoUrl;
  final String? keepingPlaceType;
  final String? keepingPlaceAddress;

  String get statusLabel => animalStatusLabels[status] ?? status;
  String get summary => '${_capitalize(species)} · ${_capitalize(size)}';
}

class InterestedPerson {
  const InterestedPerson({required this.userId, required this.fullName, required this.favoritedAt});

  factory InterestedPerson.fromJson(Map<String, dynamic> json) => InterestedPerson(
        userId: json['user_id'] as int,
        fullName: json['full_name'] as String,
        favoritedAt: DateTime.parse(json['favorited_at'] as String).toLocal(),
      );

  final int userId;
  final String fullName;
  final DateTime favoritedAt;
}

class AnimalInterested {
  const AnimalInterested({
    required this.animalId,
    required this.animalName,
    required this.animalStatus,
    required this.interested,
  });

  factory AnimalInterested.fromJson(Map<String, dynamic> json) => AnimalInterested(
        animalId: json['animal_id'] as int,
        animalName: json['animal_name'] as String,
        animalStatus: json['animal_status'] as String,
        interested: (json['interested'] as List<dynamic>)
            .map((item) => InterestedPerson.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final int animalId;
  final String animalName;
  final String animalStatus;
  final List<InterestedPerson> interested;
}

class FoundationAnimalsService {
  const FoundationAnimalsService(this._api);

  final ApiClient _api;

  Future<List<ManagedAnimal>> list() async {
    final response = await _api.get('/animals/management') as List<dynamic>;
    return response
        .map((item) => ManagedAnimal.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus(int animalId, String status) =>
      _api.patch('/animals/$animalId', <String, dynamic>{'status': status});

  Future<List<AnimalInterested>> interested() async {
    final response = await _api.get('/animals/interested') as List<dynamic>;
    return response.map((item) => AnimalInterested.fromJson(item as Map<String, dynamic>)).toList();
  }
}

String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
