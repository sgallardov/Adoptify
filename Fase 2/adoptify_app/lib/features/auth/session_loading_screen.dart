import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/adoptify_logo.dart';

// Primera pantalla al abrir la app, mientras se revisa si hay una sesión guardada.
// Evita mostrar el mapa un instante antes de mandar al login (ver redirect en router.dart).
class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdoptifyLogo(),
            SizedBox(height: AdoptifySpacing.xl),
            SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
