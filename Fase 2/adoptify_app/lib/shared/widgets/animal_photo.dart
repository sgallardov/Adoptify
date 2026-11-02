import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Foto cuadrada de una mascota (o de un reporte), con una huella si no hay foto o no carga
class AnimalPhoto extends StatelessWidget {
  const AnimalPhoto({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.pets, color: context.colors.placeholder);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdoptifyRadius.md),
      child: Container(
        width: size,
        height: size,
        color: context.colors.muted,
        child: url == null ? fallback : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}
