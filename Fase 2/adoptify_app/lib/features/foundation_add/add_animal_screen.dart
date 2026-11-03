import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Pestaña central de la vista de fundación (la acción principal): publicar una mascota en adopción.
// El formulario está pendiente; por ahora solo anuncia que viene.
class AddAnimalScreen extends StatelessWidget {
  const AddAnimalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar mascota')),
      body: const ComingSoon(
        icon: Icons.add_circle_outline,
        title: 'Próximamente',
        message: 'Aquí vas a publicar a tus rescatados con su foto, ficha y ubicación para que los adoptantes los encuentren.',
      ),
    );
  }
}
