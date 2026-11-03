import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Match de adopción: se abre con el botón "Haz Match!" del mapa.
// Por ahora anuncia el módulo; después mostrará mascotas según las preferencias del usuario
// (especie, tamaño, edad, energía), ordenadas con calculate_match_score del backend.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Haz Match!')),
      body: const ComingSoon(
        icon: Icons.favorite,
        title: 'Muy pronto',
        message: 'Cuéntanos qué mascota buscas (especie, tamaño, edad y energía) y te mostraremos las que '
            'mejor encajan contigo, para que elijas deslizando.',
      ),
    );
  }
}
