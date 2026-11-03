import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';

// Pestaña derecha de la vista de fundación. El perfil completo está pendiente; por ahora muestra quién
// inició sesión, deja cambiar entre modo claro y oscuro (luna / sol, arriba a la izquierda) y cerrar sesión
// (sin eso, una cuenta de fundación no podría salir de la app).
class FoundationProfileScreen extends StatelessWidget {
  const FoundationProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), leading: const _ThemeToggle()),
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
                icon: Icons.business_outlined,
                title: 'Próximamente',
                message: 'Aquí vas a editar los datos y la ubicación de tu fundación.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdoptifySpacing.xl,
                0,
                AdoptifySpacing.xl,
                AdoptifySpacing.xl,
              ),
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
          ],
        ),
      ),
    );
  }
}

// Luna en modo claro (pasa a oscuro) y sol en modo oscuro (pasa a claro). Usa el mismo ThemeController que
// la tarjeta Apariencia del Perfil de adoptante, así que la elección se guarda en el dispositivo.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    // brightness ya refleja el modo del sistema cuando no se ha elegido uno
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: () => ThemeScope.of(context).setMode(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      tooltip: dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
    );
  }
}
