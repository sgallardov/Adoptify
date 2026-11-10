import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';

// Clínica veterinaria para emergencias (GET /veterinaries, datos de OpenStreetMap o alta administrativa)
class VetClinic {
  const VetClinic({
    required this.id,
    required this.name,
    required this.position,
    required this.emergency,
    this.address,
    this.commune,
    this.phone,
    this.openingHours,
  });

  factory VetClinic.fromJson(Map<String, dynamic> json) => VetClinic(
        id: json['id'] as int,
        name: json['name'] as String,
        position: LatLng((json['latitude'] as num).toDouble(), (json['longitude'] as num).toDouble()),
        emergency: json['emergency'] as bool,
        address: json['address'] as String?,
        commune: json['commune'] as String?,
        phone: json['phone'] as String?,
        openingHours: json['opening_hours'] as String?,
      );

  final int id;
  final String name;
  final LatLng position;
  // Urgencias o abierta las 24 horas
  final bool emergency;
  final String? address;
  final String? commune;
  final String? phone;
  final String? openingHours;

  // "Av. Grecia 100, Ñuñoa"; null si OpenStreetMap no trae dirección ni comuna
  String? get place {
    final parts = [?address, ?commune];
    return parts.isEmpty ? null : parts.join(', ');
  }

  // Ruta en Google Maps (app o navegador) desde donde estés hasta la clínica
  Uri get directionsUrl => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${position.latitude},${position.longitude}',
      });

  Uri? get phoneUrl => phone == null ? null : Uri(scheme: 'tel', path: phone!.replaceAll(' ', ''));
}

class ClinicService {
  ClinicService(this._api);

  final ApiClient _api;

  Future<List<VetClinic>> fetchClinics(LatLng origin, int radiusKm) async {
    final data = await _api.get('/veterinaries', query: {
      'lat': origin.latitude,
      'lng': origin.longitude,
      'radius_km': radiusKm,
    }) as List<dynamic>;
    return [for (final item in data) VetClinic.fromJson(item as Map<String, dynamic>)];
  }
}
