import 'package:flutter/material.dart';

import '../messages/messages_screen.dart';

// Pestaña Chat de la fundación (HU-G2): la misma lista que el adoptante, con sus interesados y postulados.
// Con interestedUserId (botón "Conversar") abre directo el chat con esa persona.
class FoundationChatScreen extends StatelessWidget {
  const FoundationChatScreen({super.key, this.interestedUserId});

  final int? interestedUserId;

  @override
  Widget build(BuildContext context) => MessagesScreen(openWithUserId: interestedUserId);
}
