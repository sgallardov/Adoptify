import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';

// Un lugar encontrado para la dirección buscada (GET /geocode, OpenStreetMap limitado a Chile)
class GeocodeResult {
  const GeocodeResult({required this.label, required this.position, this.commune});

  factory GeocodeResult.fromJson(Map<String, dynamic> json) => GeocodeResult(
        label: json['label'] as String,
        position: LatLng((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
        commune: json['commune'] as String?,
      );

  final String label;
  final LatLng position;
  // Comuna del catálogo reconocida en el lugar; null si no se reconoció
  final String? commune;
}

class GeocodeService {
  const GeocodeService(this._api);

  final ApiClient _api;

  Future<List<GeocodeResult>> search(String query) async {
    final data = await _api.get('/geocode', query: {'q': query}) as List<dynamic>;
    return [for (final item in data) GeocodeResult.fromJson(item as Map<String, dynamic>)];
  }
}
