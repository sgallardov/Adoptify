import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';

// Modelos y llamadas de mascotas y reportes: equivalente a services/animals.ts y services/reports.ts del portal

class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.ageMonths,
    required this.size,
    required this.status,
    this.photoUrl,
    this.foundationName,
    this.position,
    this.distanceKm,
  });

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
        id: json['id'] as int,
        name: json['name'] as String,
        species: json['species'] as String,
        ageMonths: json['age_months'] as int?,
        size: json['size'] as String,
        status: json['status'] as String,
        photoUrl: json['photo_url'] as String?,
        foundationName: json['foundation_name'] as String?,
        position: _position(json),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );

  final int id;
  final String name;
  final String species;
  final int? ageMonths;
  final String size;
  final String status;
  final String? photoUrl;
  final String? foundationName;
  final LatLng? position;
  final double? distanceKm;

  String get age => formatAge(ageMonths);
  String get statusLabel => animalStatuses[status] ?? status;
  String get summary => '${capitalize(species)} · $age · $size';
}

class DogReport {
  const DogReport({
    required this.id,
    required this.description,
    required this.status,
    required this.position,
    required this.createdAt,
    this.distanceKm,
  });

  factory DogReport.fromJson(Map<String, dynamic> json) => DogReport(
        id: json['id'] as int,
        description: json['description'] as String,
        status: json['status'] as String,
        position: _position(json)!,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );

  final int id;
  final String description;
  final String status;
  final LatLng position;
  final DateTime createdAt;
  final double? distanceKm;

  String get statusLabel => reportStatuses[status] ?? status;
}

LatLng? _position(Map<String, dynamic> json) {
  final lat = json['latitude'] as num?;
  final lng = json['longitude'] as num?;
  return lat != null && lng != null ? LatLng(lat.toDouble(), lng.toDouble()) : null;
}

const animalStatuses = {'available': 'Disponible', 'in_process': 'En proceso', 'adopted': 'Adoptado'};
const reportStatuses = {'reported': 'Reportado', 'in_rescue': 'En rescate', 'resolved': 'Resuelto'};

String formatAge(int? months) {
  if (months == null) return 'Edad no registrada';
  if (months == 0) return 'Menos de 1 mes';
  final years = months ~/ 12;
  final remaining = months % 12;
  return [
    if (years > 0) '$years ${years == 1 ? 'año' : 'años'}',
    if (remaining > 0) '$remaining ${remaining == 1 ? 'mes' : 'meses'}',
  ].join(' y ');
}

String capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

// Igual que toLocaleString('es-CL'): coma decimal y sin ceros sobrantes (2,5 km)
String formatKm(double km) {
  var text = km.toStringAsFixed(2);
  if (text.contains('.')) text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
}

// Igual que toLocaleDateString('es-CL'): 29-10-2026
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

class MapService {
  MapService(this._api);

  final ApiClient _api;

  // Sin ubicación: todas las mascotas disponibles
  Future<List<Animal>> fetchAvailableAnimals() async {
    final data = await _api.get('/animals') as List<dynamic>;
    return data
        .map((item) => Animal.fromJson(item as Map<String, dynamic>))
        .where((animal) => animal.status == 'available')
        .toList();
  }

  // Animales disponibles dentro del radio, ordenados del más cercano al más lejano
  Future<List<Animal>> fetchNearbyAnimals(LatLng origin, int radiusKm) async {
    final data = await _api.get('/animals/nearby', query: _near(origin, radiusKm)) as List<dynamic>;
    return data.map((item) => Animal.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<DogReport>> fetchNearbyReports(LatLng origin, int radiusKm) async {
    final data = await _api.get('/reports/nearby', query: _near(origin, radiusKm)) as List<dynamic>;
    return data.map((item) => DogReport.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<DogReport> createReport(LatLng position, String description) async {
    final data = await _api.post('/reports', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'description': description,
    });
    return DogReport.fromJson(data as Map<String, dynamic>);
  }

  Map<String, Object> _near(LatLng origin, int radiusKm) =>
      {'lat': origin.latitude, 'lng': origin.longitude, 'radius_km': radiusKm};
}
