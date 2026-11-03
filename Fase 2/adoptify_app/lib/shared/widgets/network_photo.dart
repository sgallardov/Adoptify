import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Las pruebas no tienen disco ni plugins: ahí las fotos usan Image.network (ver test/flutter_test_config.dart)
bool useDiskImageCache = true;

// Clave de la foto en la caché del teléfono: la ruta sin el token del enlace firmado, que cambia cada pocas
// horas aunque la foto sea la misma. Así una foto ya vista no se vuelve a descargar.
String photoCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.queryParameters.containsKey('token')) return url;
  final query = Map.of(uri.queryParameters)..remove('token');
  // Ojo: replace(queryParameters: null) conserva la consulta original; sin otros parámetros se corta a mano
  if (query.isEmpty) return url.split('?').first;
  return uri.replace(queryParameters: query).toString();
}

// Las fotos de Unsplash (animales de ejemplo) pesan 1 a 2 MB en tamaño original: se piden al ancho en que se
// muestran, redondeado a múltiplos de 200 px para reutilizar la misma versión. Las demás pasan tal cual.
String sizedPhotoUrl(String url, int? pixelWidth) {
  final uri = Uri.tryParse(url);
  if (pixelWidth == null || uri == null || uri.host != 'images.unsplash.com') return url;
  final width = (((pixelWidth + 199) ~/ 200) * 200).clamp(200, 1600);
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    'w': '$width',
    'q': '75',
    'fit': 'max',
    'auto': 'format',
  }).toString();
}

// Foto de la red con caché en disco, decodificada al tamaño en que se muestra y con indicador de carga.
// pixelsWide: ancho lógico que necesita la foto (null = tamaño original, por ejemplo en el visor con zoom).
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.pixelsWide,
  });

  final String url;
  final Widget fallback;
  final BoxFit fit;
  final double? pixelsWide;

  @override
  Widget build(BuildContext context) {
    final decodeWidth = pixelsWide == null ? null : (pixelsWide! * MediaQuery.devicePixelRatioOf(context)).round();
    final source = sizedPhotoUrl(url, decodeWidth);
    const loading = _Loading();

    if (!useDiskImageCache) {
      return Image.network(
        source,
        fit: fit,
        cacheWidth: decodeWidth,
        loadingBuilder: (context, child, progress) => progress == null ? child : loading,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: photoCacheKey(source),
      fit: fit,
      memCacheWidth: decodeWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => loading,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.muted,
      child: const Center(
        child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
