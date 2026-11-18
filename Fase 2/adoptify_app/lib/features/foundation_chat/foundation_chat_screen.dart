import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Pestaña de la fundación: hablar con un adoptante solo después de revisar e invitar una postulación.
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
            ? 'Aquí vas a conversar con postulantes que tu fundación haya invitado.'
            : 'Elegiste conversar con una persona interesada${animalId == null ? '' : ' en uno de tus animales'}. El chat estará disponible pronto; por ahora no se ha enviado ningún mensaje.',
      ),
    );
  }
}
