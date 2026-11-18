import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Si el navegador o el teléfono no responden el permiso, se deja de esperar a los 15 s
const permissionTimeout = Duration(seconds: 15);
// Tope de toda la consulta (permiso + GPS). Así ningún botón queda cargando para siempre.
const locationTimeout = Duration(seconds: 20);

const permissionTimeoutMessage =
    'No recibimos respuesta al permiso de ubicación. Revisa la ventana del navegador o del teléfono e inténtalo de nuevo.';

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
      // Algunos navegadores dejan la pregunta abierta sin responder nunca
      permission = await Geolocator.requestPermission().timeout(
        permissionTimeout,
        onTimeout: () => throw LocationException(permissionTimeoutMessage),
      );
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

// Lo que usan las pantallas: la ubicación con tope de tiempo. Cualquier falla llega como LocationException,
// así cada pantalla solo maneja un tipo de error y su botón siempre deja de cargar.
Future<LatLng> currentLocation() async {
  try {
    return await LocationService.instance.current().timeout(
      locationTimeout,
      onTimeout: () => throw LocationException(permissionTimeoutMessage),
    );
  } on LocationException {
    rethrow;
  } catch (_) {
    throw LocationException('No pudimos obtener tu ubicación. Inténtalo nuevamente.');
  }
}
