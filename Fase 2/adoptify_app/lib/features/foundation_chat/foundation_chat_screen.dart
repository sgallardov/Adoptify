import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Pestaña izquierda de la vista de fundación: hablar con un adoptante cuando haya match.
// Módulo pendiente; por ahora solo anuncia que viene.
class FoundationChatScreen extends StatelessWidget {
  const FoundationChatScreen({super.key, this.interestedUserId, this.animalId});

  final int? interestedUserId;
  final int? animalId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ComingSoon(
        icon: Icons.chat_bubble_outline,
        title: interestedUserId == null ? 'Próximamente' : 'Conversación preparada',
        message: interestedUserId == null
            ? 'Aquí vas a conversar con los adoptantes que hagan match con tus mascotas.'
            : 'Seleccionaste una persona interesada${animalId == null ? '' : ' en uno de tus animales'}. El chat se creará solo cuando implementemos HU-G2; por ahora no se ha enviado ningún mensaje.',
      ),
    );
  }
}
