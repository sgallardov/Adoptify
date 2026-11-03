import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Pestaña izquierda de la vista de fundación: hablar con un adoptante cuando haya match.
// Módulo pendiente; por ahora solo anuncia que viene.
class FoundationChatScreen extends StatelessWidget {
  const FoundationChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const ComingSoon(
        icon: Icons.chat_bubble_outline,
        title: 'Próximamente',
        message: 'Aquí vas a conversar con los adoptantes que hagan match con tus mascotas.',
      ),
    );
  }
}
