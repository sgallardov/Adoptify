import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/photo_service.dart';
import '../../shared/map/map_style.dart';

// Modelos y llamadas de mascotas y reportes: equivalente a services/animals.ts y services/reports.ts del portal

// HU-Z: criterio común de búsqueda de reportes entre la app y el portal de fundaciones.
// Las dos vistas piden GET /reports/nearby con los mismos parámetros, así que con la misma ubicación y el
// mismo radio muestran exactamente los mismos reportes (los que no están resueltos).
//   - Con ubicación (la del teléfono en la app, la sede de la fundación en el portal): el radio elegido,
//     por defecto defaultReportRadiusKm.
//   - Sin ubicación (permiso denegado, o cuenta sin sede ubicada): Santiago con noLocationReportRadiusKm,
//     el radio máximo que acepta la API.
// El equivalente en el portal es reportSearchArea de src/services/reportArea.ts: mantener los dos iguales.
const reportRadiusOptions = [5, 10, 25, 50, 100];
const defaultReportRadiusKm = 10;
const noLocationReportRadiusKm = 100;

class ReportSearchArea {
  const ReportSearchArea(this.origin, this.radiusKm);

  final LatLng origin;
  final int radiusKm;
}

ReportSearchArea reportSearchArea(LatLng? origin, [int radiusKm = defaultReportRadiusKm]) => origin != null
    ? ReportSearchArea(origin, radiusKm)
    : const ReportSearchArea(santiago, noLocationReportRadiusKm);

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
    this.commune,
    this.withinRadius = false,
    this.description,
    this.breed,
    this.gender,
    this.energyLevel,
  });

  factory Animal.fromJson(Map<String, dynamic> json, {bool withinRadius = false}) => Animal(
        id: json['id'] as int,
        name: json['name'] as String,
        species: json['species'] as String,
        ageMonths: json['age_months'] as int?,
        size: json['size'] as String,
        status: json['status'] as String,
        photoUrl: mediaUrl(json['photo_url'] as String?),
        foundationName: json['foundation_name'] as String?,
        position: _communePoint(json['commune_point']),
        commune: json['public_commune'] as String?,
        withinRadius: withinRadius,
        description: json['description'] as String?,
        breed: json['breed'] as String?,
        gender: json['gender'] as String?,
        energyLevel: json['energy_level'] as int?,
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
  final String? commune;
  final bool withinRadius;
  final String? description;
  final String? breed;
  final String? gender;
  final int? energyLevel;
  String get publicZone => commune == null ? 'Zona no informada' : 'Zona aproximada: $commune';

  String get age => formatAge(ageMonths);
  String get statusLabel => animalStatuses[status] ?? status;
  String? get energyLabel => energyLevel == null ? null : formatEnergy(energyLevel!);
  String get summary => '${capitalize(species)} · $age · $size';
}

// Mismo texto en la ficha y en la tarjeta del match
String formatEnergy(int level) => level <= 2 ? 'Tranquilo' : (level == 3 ? 'Moderado' : 'Muy activo');

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
    this.foundationName,
    this.seenAt,
    this.takenAt,
    this.takenByFoundationId,
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
        foundationName: json['foundation_name'] as String?,
        seenAt: json['seen_at'] == null ? null : DateTime.parse(json['seen_at'] as String).toLocal(),
        takenAt: json['taken_at'] == null ? null : DateTime.parse(json['taken_at'] as String).toLocal(),
        takenByFoundationId: json['taken_by_foundation_id'] as int?,
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
  final String? foundationName;
  final DateTime? seenAt;
  final DateTime? takenAt;
  final int? takenByFoundationId;

  String get statusLabel => reportStatuses[status] ?? status;

  // HU-S: una fundación tomó el caso (la mascota está siendo atendida)
  bool get isTaken => takenByFoundationId != null && status != 'resolved';

  // Estado para tarjetas y listas: "En rescate por <Fundación>" si está tomado; si no, el estado normal
  String get careLabel => isTaken ? 'En rescate por ${foundationName ?? 'una fundación'}' : statusLabel;

  // Solo si la vio una fundación sin tomarlo todavía
  bool get seenOnly => !isTaken && seenAt != null && status != 'resolved';

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

// Comentario anónimo de un reporte: la API nunca dice quién lo escribió, solo si es tuyo
class ReportComment {
  const ReportComment({required this.id, required this.body, required this.createdAt, required this.isMine});

  factory ReportComment.fromJson(Map<String, dynamic> json) => ReportComment(
        id: json['id'] as int,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        isMine: json['is_mine'] as bool? ?? false,
      );

  final int id;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}

// Cuántos marcaron "me enteré" en un reporte y si tú eres uno de ellos
class ReportLikes {
  const ReportLikes({required this.count, required this.liked});

  factory ReportLikes.fromJson(Map<String, dynamic> json) =>
      ReportLikes(count: json['count'] as int, liked: json['liked'] as bool);

  final int count;
  final bool liked;
}

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

// Los animales solo aceptan el punto comunal público. Los reportes conservan su punto de avistamiento.
LatLng? _communePoint(Object? point) {
  if (point is List && point.length == 2 && point[0] is num && point[1] is num) {
    return LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble());
  }
  return null;
}

LatLng? _position(Map<String, dynamic> json) {
  final lat = json['latitude'] as num?;
  final lng = json['longitude'] as num?;
  return lat != null && lng != null ? LatLng(lat.toDouble(), lng.toDouble()) : null;
}

const animalStatuses = {'available': 'Disponible', 'in_process': 'En proceso', 'adopted': 'Adoptado', 'follow_up': 'Seguimiento'};
const reportStatuses = {'reported': 'Reportado', 'in_rescue': 'En rescate', 'resolved': 'Resuelto'};

// Opciones del formulario de reporte: valor que guarda la API → texto (igual que reportOptions del portal)
const reportSpecies = {'perro': 'Perro', 'gato': 'Gato', 'otro': 'Otro'};
const reportSizes = {'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'};
// Estado y comportamiento admiten varias opciones
const reportConditions = {
  'bien': 'Bien',
  'desnutrido': 'Desnutrido',
  'deshidratado': 'Deshidratado',
  'herido': 'Herido',
  'sangrando': 'Sangrando',
  'cojea': 'Cojea',
  'atropellado': 'Atropellado',
  'no_se_mueve': 'No se puede mover',
  'enfermo': 'Enfermo',
  'problemas_piel': 'Sarna o problemas de piel',
  'parasitos': 'Pulgas o garrapatas',
  'problemas_ojos': 'Problemas en los ojos',
  'prenada': 'Preñada',
  'con_crias': 'Con crías',
  'deplorable': 'Deplorable',
};
const reportBehaviors = {
  'tranquilo': 'Tranquilo',
  'amistoso': 'Amistoso, se deja tocar',
  'jugueton': 'Juguetón',
  'sigue_personas': 'Sigue a las personas',
  'decaido': 'Decaído',
  'asustado': 'Asustado',
  'se_esconde': 'Se esconde',
  'huye': 'Huye al acercarse',
  'nervioso': 'Nervioso',
  'desconfiado': 'Desconfiado',
  'ruidoso': 'Ladra o maúlla mucho',
  'protector': 'Protege a sus crías',
  'agresivo': 'Agresivo',
};

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

// 29-10-2026, 20:13
String formatDateTime(DateTime date) =>
    '${formatDate(date)}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class MapService {
  MapService(this._api);

  final ApiClient _api;

  Future<List<DogReport>> fetchNearbyReports(LatLng origin, int radiusKm) async {
    final data = await _api.get('/reports/nearby', query: _near(origin, radiusKm)) as List<dynamic>;
    return data.map((item) => DogReport.fromJson(item as Map<String, dynamic>)).toList();
  }

  // Mascotas en adopción: ya no van en el mapa (HU-R), pero el buscador las encuentra y abre su ficha
  Future<List<Animal>> fetchAnimals() async {
    final data = await _api.get('/animals') as List<dynamic>;
    return data.map((item) => Animal.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<DogReport> createReport(NewReport report) async {
    final data = await _api.post('/reports', report.toJson());
    return DogReport.fromJson(data as Map<String, dynamic>);
  }

  // Ficha pública de un animal por id (enlace /animales/:id recargado)
  Future<Animal> fetchAnimal(int animalId) async =>
      Animal.fromJson(await _api.get('/animals/$animalId') as Map<String, dynamic>);

  Future<DogReport> fetchReport(int reportId) async => _reportAction(await _api.get('/reports/$reportId'));

  // Acciones de la fundación sobre un reporte (HU-C). Cada una devuelve el reporte ya actualizado.
  Future<DogReport> takeReport(int reportId) async => _reportAction(await _api.put('/reports/$reportId/taken'));

  Future<DogReport> untakeReport(int reportId) async => _reportAction(await _api.delete('/reports/$reportId/taken'));

  // Cierra el rescate: el reporte pasa a 'resolved' y sale del mapa
  Future<DogReport> resolveReport(int reportId) async =>
      _reportAction(await _api.patch('/reports/$reportId/status', {'status': 'resolved'}));

  DogReport _reportAction(Object? data) => DogReport.fromJson(data as Map<String, dynamic>);

  Future<List<ReportComment>> fetchComments(int reportId) async {
    final data = await _api.get('/reports/$reportId/comments') as List<dynamic>;
    return data.map((item) => ReportComment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ReportComment> addComment(int reportId, String body) async {
    final data = await _api.post('/reports/$reportId/comments', {'body': body});
    return ReportComment.fromJson(data as Map<String, dynamic>);
  }

  Future<ReportLikes> fetchLikes(int reportId) async =>
      ReportLikes.fromJson(await _api.get('/reports/$reportId/likes') as Map<String, dynamic>);

  // Marca o quita tu "me enteré" y devuelve el total actualizado
  Future<ReportLikes> setLiked(int reportId, bool liked) async {
    final path = '/reports/$reportId/likes';
    final data = liked ? await _api.put(path) : await _api.delete(path);
    return ReportLikes.fromJson(data as Map<String, dynamic>);
  }

  // Sube la foto (POST /uploads) y devuelve su URL para guardarla en photo_url
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final data = await _api.upload('/uploads', photo.bytes, photo.filename);
    return (data as Map<String, dynamic>)['url'] as String;
  }

  Map<String, Object> _near(LatLng origin, int radiusKm) =>
      {'lat': origin.latitude, 'lng': origin.longitude, 'radius_km': radiusKm};
}
