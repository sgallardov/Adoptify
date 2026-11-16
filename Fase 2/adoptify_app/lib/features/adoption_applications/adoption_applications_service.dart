import '../../core/api_client.dart';
import '../account/adoption_service.dart';

class AdoptionApplicationsService {
  const AdoptionApplicationsService(this._api);
  final ApiClient _api;

  Future<void> apply({required int animalId, required AdoptionProfile profile, String? message}) =>
      _api.post('/adoption-applications/animals/$animalId', <String, dynamic>{
        'profile': profile.toJson(),
        'message': message,
      });
}
