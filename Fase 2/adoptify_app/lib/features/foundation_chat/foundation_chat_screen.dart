import 'package:flutter/material.dart';

import '../messages/messages_screen.dart';

// Pestaña Chat de la fundación (HU-G2): la misma lista que el adoptante, con sus interesados y postulados.
// Con interestedUserId (botón "Conversar") abre directo el chat con esa persona; con animalId, además
// empieza el cuestionario de adopción de esa mascota (HU-G3), una sola vez por persona y mascota.
class FoundationChatScreen extends StatelessWidget {
  const FoundationChatScreen({super.key, this.interestedUserId, this.animalId});

  final int? interestedUserId;
  final int? animalId;

  @override
  Widget build(BuildContext context) => MessagesScreen(openWithUserId: interestedUserId, openWithAnimalId: animalId);
}
