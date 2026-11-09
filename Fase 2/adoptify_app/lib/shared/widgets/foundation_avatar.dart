import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'network_photo.dart';

// Foto de perfil de una fundación. Sin foto (o si no carga) muestra la inicial del nombre en [color]
// sobre un cuadro claro, que contrasta en modo claro y oscuro.
class FoundationAvatar extends StatelessWidget {
  const FoundationAvatar({super.key, required this.name, required this.photoUrl, required this.size, required this.color});

  final String name;
  final String? photoUrl;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final initial = Center(
      child: Text(
        clean.isEmpty ? '?' : clean[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdoptifyRadius.md),
      child: Container(
        width: size,
        height: size,
        color: context.colors.onAccent,
        child: photoUrl == null
            ? initial
            : NetworkPhoto(url: photoUrl!, fallback: initial, pixelsWide: size * 2),
      ),
    );
  }
}
