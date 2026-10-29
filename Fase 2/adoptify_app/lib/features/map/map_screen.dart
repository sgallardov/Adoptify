import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Se implementa en HU-15 (flutter_map + /animals/nearby y /reports/nearby)
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: const ComingSoon(
        icon: Icons.map,
        title: 'Mapa de mascotas y reportes',
        message: 'Pronto podrás ver aquí los animales en adopción y los perros reportados cerca de ti.',
      ),
    );
  }
}
