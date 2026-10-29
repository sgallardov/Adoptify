import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

// Se implementa en HU-15 (mapa + GPS + POST /reports)
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar')),
      body: const ComingSoon(
        icon: Icons.add_location_alt,
        title: 'Reportar un perro abandonado',
        message: 'Pronto podrás marcar en el mapa dónde está y enviar el reporte desde aquí.',
      ),
    );
  }
}
