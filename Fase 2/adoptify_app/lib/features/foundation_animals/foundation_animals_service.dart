import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../match/match_service.dart' show compatibilityLabel;

const animalStatusLabels = <String, String>{
  'available': 'En adopción',
  'in_process': 'En proceso',
  'adopted': 'Adoptado',
  // Seguimiento (HU-Y): etapa posterior a la adopción
  'follow_up': 'Seguimiento',
};

/// Pestañas de la gestión, en orden: primero los que buscan hogar, al final el seguimiento (HU-Y).
const animalStatusTabs = <String>['available', 'in_process', 'adopted', 'follow_up'];

/// Título de cada pestaña (en plural, a diferencia de la etiqueta de un animal).
const animalStatusTabLabels = <String, String>{
  'available': 'Disponibles',
  'in_process': 'En proceso',
  'adopted': 'Adoptados',
  'follow_up': 'Seguimiento',
};

/// Mensaje de la pestaña sin animales.
const animalStatusEmptyMessages = <String, String>{
  'available': 'No tienes animales disponibles. Publica un caso para que las personas puedan conocerlo.',
  'in_process': 'Ningún animal en proceso. Aquí verás los animales con una adopción en curso.',
  'adopted': 'Todavía no registras adopciones. Cuando marques un animal como adoptado, aparecerá aquí.',
  'follow_up': 'Ningún animal en seguimiento. Pasa un animal adoptado a Seguimiento para acompañar su adaptación.',
};

/// Seguimiento es la etapa posterior a la adopción: solo se ofrece a un animal adoptado o ya en seguimiento.
List<String> animalStatusOptions(String current) => current == 'adopted' || current == 'follow_up'
    ? animalStatusTabs
    : [for (final status in animalStatusTabs) if (status != 'follow_up') status];

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
    this.position,
    this.publicCommune,
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
        position: json['latitude'] == null || json['longitude'] == null
            ? null
            : LatLng((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
        publicCommune: json['public_commune'] as String?,
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
  // Punto privado (solo lo ve la fundación dueña)
  final LatLng? position;
  // Comuna que ve el público
  final String? publicCommune;

  ManagedAnimal copyWith({String? status}) => ManagedAnimal(
        id: id,
        name: name,
        species: species,
        gender: gender,
        size: size,
        energyLevel: energyLevel,
        status: status ?? this.status,
        ageMonths: ageMonths,
        description: description,
        photoUrl: photoUrl,
        keepingPlaceType: keepingPlaceType,
        keepingPlaceAddress: keepingPlaceAddress,
        position: position,
        publicCommune: publicCommune,
      );

  String get statusLabel => animalStatusLabels[status] ?? status;
  String get summary => '${_capitalize(species)} · ${_capitalize(size)}';
}

class InterestedPerson {
  const InterestedPerson({required this.userId, required this.fullName, required this.favoritedAt, this.matchScore});

  factory InterestedPerson.fromJson(Map<String, dynamic> json) => InterestedPerson(
        userId: json['user_id'] as int,
        fullName: json['full_name'] as String,
        favoritedAt: DateTime.parse(json['favorited_at'] as String).toLocal(),
        matchScore: (json['match_score'] as num?)?.toDouble(),
      );

  final int userId;
  final String fullName;
  final DateTime favoritedAt;
  // 0-100; null si la persona no completó "Quiero adoptar"
  final double? matchScore;

  String get matchLabel => matchScore == null ? 'Sin ficha de adopción' : compatibilityLabel(matchScore!);
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

class FoundationApplication {
  const FoundationApplication({required this.id, required this.animalId, required this.animalName, required this.userId, required this.fullName, required this.status, required this.housingType, required this.hasPets, this.experience, this.message});
  factory FoundationApplication.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'] as Map<String, dynamic>;
    final profile = json['profile'] as Map<String, dynamic>;
    return FoundationApplication(id: json['id'] as int, animalId: json['animal_id'] as int, animalName: json['animal_name'] as String, userId: applicant['user_id'] as int, fullName: applicant['full_name'] as String, status: json['status'] as String, housingType: profile['housing_type'] as String, hasPets: profile['has_pets'] as String, experience: profile['experience'] as String?, message: json['message'] as String?);
  }
  final int id; final int animalId; final String animalName; final int userId; final String fullName; final String status; final String housingType; final String hasPets; final String? experience; final String? message;
  bool get canAct => status == 'submitted' || status == 'reviewing';
  String get statusLabel => {'submitted': 'Nueva', 'reviewing': 'En revisión', 'invited_to_chat': 'Invitada a conversar', 'rejected': 'No continúa', 'approved': 'Preseleccionada'}[status] ?? status;
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

  // Interesados de un solo animal: el backend responde 403 si es de otra fundación
  Future<AnimalInterested> interestedIn(int animalId) async =>
      AnimalInterested.fromJson(await _api.get('/animals/$animalId/interested') as Map<String, dynamic>);

  Future<List<FoundationApplication>> applications() async {
    final response = await _api.get('/adoption-applications/foundation') as List<dynamic>;
    return response.map((item) => FoundationApplication.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> updateApplicationStatus(int id, String status) =>
      _api.patch('/adoption-applications/$id/status', <String, dynamic>{'status': status});
}

String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
