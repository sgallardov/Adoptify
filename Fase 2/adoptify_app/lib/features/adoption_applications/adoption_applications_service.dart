import '../../core/api_client.dart';
import '../../core/config.dart';
import '../account/adoption_service.dart';

// Postulación del adoptante a un animal, tal como la devuelve GET /adoption-applications/mine
class MyApplication {
  const MyApplication({
    required this.id,
    required this.animalId,
    required this.animalName,
    required this.foundationName,
    required this.status,
    required this.createdAt,
    this.photoUrl,
  });

  factory MyApplication.fromJson(Map<String, dynamic> json) => MyApplication(
        id: json['id'] as int,
        animalId: json['animal_id'] as int,
        animalName: json['animal_name'] as String,
        photoUrl: mediaUrl(json['animal_photo_url'] as String?),
        foundationName: json['foundation_name'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final int id;
  final int animalId;
  final String animalName;
  final String? photoUrl;
  final String foundationName;
  final String status;
  final DateTime createdAt;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  // Las aprobadas no se retiran: hay que hablar con la fundación
  bool get canWithdraw => !isApproved;

  String get statusLabel => switch (status) {
        'approved' => 'Aprobada',
        'rejected' => 'Por ahora no fue aprobada',
        _ => 'En revisión',
      };
}

class AdoptionApplicationsService {
  const AdoptionApplicationsService(this._api);
  final ApiClient _api;

  Future<void> apply({required int animalId, required AdoptionProfile profile, String? message}) =>
      _api.post('/adoption-applications/animals/$animalId', <String, dynamic>{
        'profile': profile.toJson(),
        'message': message,
      });

  // Las más recientes primero (el backend ya las entrega ordenadas y sin las retiradas)
  Future<List<MyApplication>> listMine() async {
    final data = await _api.get('/adoption-applications/mine') as List<dynamic>;
    return [for (final item in data) MyApplication.fromJson(item as Map<String, dynamic>)];
  }

  Future<void> withdraw(int id) => _api.delete('/adoption-applications/$id');
}
