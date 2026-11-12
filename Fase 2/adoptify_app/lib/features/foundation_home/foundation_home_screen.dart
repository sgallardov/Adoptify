import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';

// Inicio de la fundación: ofrece contexto y accesos sin obligar a abrir el formulario de publicación.
class FoundationHomeScreen extends StatelessWidget {
  const FoundationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    final name = user?.fullName.split(' ').first ?? 'fundación';
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AdoptifySpacing.xl),
          children: [
            Text('Hola, $name', style: textTheme.headlineSmall),
            const SizedBox(height: AdoptifySpacing.xs),
            Text(
              'Este es el espacio de tu fundación para coordinar rescates y darles una nueva oportunidad.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AdoptifySpacing.xl),
            Container(
              padding: const EdgeInsets.all(AdoptifySpacing.xl),
              decoration: BoxDecoration(
                color: colors.primaryStrong,
                borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.volunteer_activism_outlined, color: colors.onAccent, size: 30),
                  const SizedBox(height: AdoptifySpacing.md),
                  Text('Cada historia importa.', style: textTheme.titleLarge?.copyWith(color: colors.onAccent)),
                  const SizedBox(height: AdoptifySpacing.xs),
                  Text(
                    'Publica cuando tengas un caso listo; no necesitas completar un formulario ahora.',
                    style: textTheme.bodyMedium?.copyWith(color: colors.onAccent),
                  ),
                  const SizedBox(height: AdoptifySpacing.lg),
                  FilledButton.icon(
                    onPressed: () => context.push('/fundacion/agregar'),
                    icon: const Icon(Icons.add),
                    label: const Text('Publicar animal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.surface,
                      foregroundColor: colors.primaryStrong,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdoptifySpacing.xl),
            Text('Accesos rápidos', style: textTheme.titleLarge),
            const SizedBox(height: AdoptifySpacing.md),
            _QuickAccess(
              icon: Icons.pets_outlined,
              title: 'Mis animales',
              description: 'Consulta, edita y actualiza el estado de tus casos publicados.',
              onTap: () => context.push('/fundacion/mis-animales'),
            ),
            const SizedBox(height: AdoptifySpacing.md),
            _QuickAccess(
              icon: Icons.chat_bubble_outline,
              title: 'Conversaciones',
              description: 'Revisa los mensajes de personas interesadas.',
              onTap: () => context.go('/fundacion/chat'),
            ),
            const SizedBox(height: AdoptifySpacing.md),
            _QuickAccess(
              icon: Icons.account_circle_outlined,
              title: 'Mi fundación',
              description: 'Actualiza la presentación pública de tu organización.',
              onTap: () => context.go('/fundacion/perfil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.icon, required this.title, required this.description, required this.onTap});

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(AdoptifySpacing.md),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: colors.primarySoft, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
          child: Icon(icon, color: colors.primaryDark),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
