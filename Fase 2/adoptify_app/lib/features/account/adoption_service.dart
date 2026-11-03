import '../../core/api_client.dart';

// Formulario "Quiero adoptar": datos del hogar y preferencias para el motor de match.
// Los valores son los mismos que acepta schemas/adoption_profile.py del backend.
class AdoptionProfile {
  const AdoptionProfile({
    required this.housingType,
    required this.hasKids,
    required this.hasPets,
    required this.hoursAlone,
    this.activityLevel,
    this.experience,
    required this.wantedSpecies,
    required this.wantedSizes,
    this.wantedAges = const {},
    this.acceptsFollowUp = true,
  });

  factory AdoptionProfile.fromJson(Map<String, dynamic> json) => AdoptionProfile(
        housingType: json['housing_type'] as String,
        hasKids: json['has_kids'] as String,
        hasPets: json['has_pets'] as String,
        hoursAlone: json['hours_alone'] as String,
        activityLevel: json['activity_level'] as String?,
        experience: json['experience'] as String?,
        wantedSpecies: Set<String>.from(json['wanted_species'] as List),
        wantedSizes: Set<String>.from(json['wanted_sizes'] as List),
        wantedAges: Set<String>.from(json['wanted_ages'] as List),
        acceptsFollowUp: json['accepts_follow_up'] as bool,
      );

  final String housingType;
  final String hasKids;
  final String hasPets;
  final String hoursAlone;
  final String? activityLevel;
  final String? experience;
  final Set<String> wantedSpecies;
  final Set<String> wantedSizes;
  final Set<String> wantedAges;
  final bool acceptsFollowUp;

  Map<String, dynamic> toJson() => {
        'housing_type': housingType,
        'has_kids': hasKids,
        'has_pets': hasPets,
        'hours_alone': hoursAlone,
        'activity_level': activityLevel,
        'experience': experience,
        'wanted_species': wantedSpecies.toList(),
        'wanted_sizes': wantedSizes.toList(),
        'wanted_ages': wantedAges.toList(),
        'accepts_follow_up': acceptsFollowUp,
      };
}

// Llamadas a /users/me/adoption-profile
class AdoptionService {
  AdoptionService(this._api);

  final ApiClient _api;

  // null si la persona aún no lo completó (solo usa la app para reportar)
  Future<AdoptionProfile?> fetch() async {
    final data = await _api.get('/users/me/adoption-profile');
    return data == null ? null : AdoptionProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> save(AdoptionProfile profile) => _api.put('/users/me/adoption-profile', profile.toJson());
}
