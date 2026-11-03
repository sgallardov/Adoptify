import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';

// Vista de las cuentas de fundación (y admin) en la app. Entran por el mismo login que los adoptantes
// y el router las trae aquí en vez del mapa. El módulo todavía no existe: se avisa con "Muy pronto".
class FoundationHomeScreen extends StatelessWidget {
  const FoundationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi fundación'), automaticallyImplyLeading: false),
      body: ContentWidth(
        child: Column(
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, 0),
                child: Column(
                  children: [
                    Text(user.fullName, style: textTheme.titleMedium, textAlign: TextAlign.center),
                    const SizedBox(height: AdoptifySpacing.xs),
                    Text(user.email, style: textTheme.bodySmall, textAlign: TextAlign.center),
                  ],
                ),
              ),
            const Expanded(
              child: ComingSoon(
                icon: Icons.volunteer_activism_outlined,
                title: 'Muy pronto',
                message: 'Desde aquí vas a gestionar a tus rescatados: publicar animales en adopción, '
                    'revisar a los interesados y responder los avisos cercanos. Mientras tanto, '
                    'sigue usando el portal web de fundaciones.',
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AdoptifySpacing.xl),
                child: OutlinedButton.icon(
                  onPressed: auth.signOut,
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primaryDark,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
