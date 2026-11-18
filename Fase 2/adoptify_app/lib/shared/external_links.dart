import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// Abre algo fuera de la app (marcador, correo, mapas). Se puede reemplazar en las pruebas.
Future<bool> Function(Uri url) externalLauncher = (url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

// Ruta en Google Maps (app o navegador) desde donde estés hasta el punto
Uri directionsUri(LatLng destination) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
    });

Uri phoneUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));

Uri mailUri(String email) => Uri(scheme: 'mailto', path: email);

// Si el dispositivo no puede abrirlo, avisa sin romper la pantalla
Future<void> openExternal(BuildContext context, Uri url) async {
  var opened = false;
  try {
    opened = await externalLauncher(url);
  } catch (_) {}
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir esa opción en este dispositivo.'),
      ),
    );
  }
}
