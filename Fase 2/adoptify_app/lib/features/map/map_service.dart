import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/photo_service.dart';

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
        photoUrl: mediaUrl(json['photo_url'] as String?),
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

// Reporte de una mascota abandonada. Los datos de la ficha pueden faltar en reportes antiguos.
class DogReport {
  const DogReport({
    required this.id,
    required this.description,
    required this.status,
    required this.position,
    required this.createdAt,
    this.species,
    this.size,
    this.weightKg,
    this.color,
    this.features,
    this.conditions = const [],
    this.behaviors = const [],
    this.photoUrl,
    this.distanceKm,
  });

  factory DogReport.fromJson(Map<String, dynamic> json) => DogReport(
        id: json['id'] as int,
        species: json['species'] as String?,
        size: json['size'] as String?,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        color: json['color'] as String?,
        features: json['features'] as String?,
        conditions: _strings(json['conditions']),
        behaviors: _strings(json['behaviors']),
        description: json['description'] as String,
        status: json['status'] as String,
        position: _position(json)!,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        photoUrl: mediaUrl(json['photo_url'] as String?),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );

  final int id;
  final String? species;
  final String? size;
  final double? weightKg;
  final String? color;
  final String? features;
  final List<String> conditions;
  final List<String> behaviors;
  final String description;
  final String status;
  final LatLng position;
  final DateTime createdAt;
  final String? photoUrl;
  final double? distanceKm;

  String get statusLabel => reportStatuses[status] ?? status;

  // "Perro · Mediano · Café · ~12 kg", igual que reportSummary del portal. Vacío en reportes antiguos.
  String get summary => [
        ?_label(reportSpecies, species),
        ?_label(reportSizes, size),
        ?color,
        if (weightKg != null) '~${formatKm(weightKg!)} kg',
      ].join(' · ');

  // "Herido, Desnutrido · Asustado", igual que reportCondition del portal
  String get conditionLabel => [
        conditions.map((value) => _label(reportConditions, value)).join(', '),
        behaviors.map((value) => _label(reportBehaviors, value)).join(', '),
      ].where((text) => text.isNotEmpty).join(' · ');
}

String? _label(Map<String, String> options, String? value) => value == null ? null : options[value] ?? value;

List<String> _strings(Object? value) => value is List ? value.cast<String>() : const [];

// Datos que se envían al reportar (POST /reports)
class NewReport {
  const NewReport({
    required this.position,
    required this.species,
    required this.size,
    required this.color,
    required this.conditions,
    required this.description,
    this.weightKg,
    this.features,
    this.behaviors = const [],
    this.photoUrl,
  });

  final LatLng position;
  final String species;
  final String size;
  final String color;
  final List<String> conditions;
  final String description;
  final double? weightKg;
  final String? features;
  final List<String> behaviors;
  final String? photoUrl;

  Map<String, dynamic> toJson() => {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'species': species,
        'size': size,
        'color': color,
        'conditions': conditions,
        'description': description,
        'weight_kg': ?weightKg,
        'features': ?features,
        if (behaviors.isNotEmpty) 'behaviors': behaviors,
        'photo_url': ?photoUrl,
      };
}

LatLng? _position(Map<String, dynamic> json) {
  final lat = json['latitude'] as num?;
  final lng = json['longitude'] as num?;
  return lat != null && lng != null ? LatLng(lat.toDouble(), lng.toDouble()) : null;
}

const animalStatuses = {'available': 'Disponible', 'in_process': 'En proceso', 'adopted': 'Adoptado'};
const reportStatuses = {'reported': 'Reportado', 'in_rescue': 'En rescate', 'resolved': 'Resuelto'};

// Opciones del formulario de reporte: valor que guarda la API → texto (igual que reportOptions del portal)
const reportSpecies = {'perro': 'Perro', 'gato': 'Gato', 'otro': 'Otro'};
const reportSizes = {'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'};
const reportConditions = {
  'bien': 'Bien',
  'desnutrido': 'Desnutrido',
  'herido': 'Herido',
  'enfermo': 'Enfermo',
  'deplorable': 'Deplorable',
};
const reportBehaviors = {'tranquilo': 'Tranquilo', 'asustado': 'Asustado', 'agresivo': 'Agresivo'};

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

  Future<DogReport> createReport(NewReport report) async {
    final data = await _api.post('/reports', report.toJson());
    return DogReport.fromJson(data as Map<String, dynamic>);
  }

  // Sube la foto (POST /uploads) y devuelve su URL para guardarla en photo_url
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final data = await _api.upload('/uploads', photo.bytes, photo.filename);
    return (data as Map<String, dynamic>)['url'] as String;
  }

  Map<String, Object> _near(LatLng origin, int radiusKm) =>
      {'lat': origin.latitude, 'lng': origin.longitude, 'radius_km': radiusKm};
}
