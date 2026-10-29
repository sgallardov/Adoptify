import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Error de ubicación con el mensaje que se muestra al usuario
class LocationException implements Exception {
  LocationException(this.message);

  final String message;
}

// Ubicación del dispositivo con geolocator. Se puede reemplazar en los tests.
class LocationService {
  static LocationService instance = LocationService();

  Future<LatLng> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('La ubicación del teléfono está desactivada. Actívala e inténtalo nuevamente.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw LocationException('No diste permiso para usar tu ubicación. Puedes activarlo en la configuración del teléfono.');
    }
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      // Sin señal a tiempo: se usa la última posición conocida (como maximumAge en la web)
      position = await Geolocator.getLastKnownPosition().catchError((_) => null);
    }
    if (position == null) {
      throw LocationException('No pudimos obtener tu ubicación. Inténtalo nuevamente.');
    }
    return LatLng(position.latitude, position.longitude);
  }
}
