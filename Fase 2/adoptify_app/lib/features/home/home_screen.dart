import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.pets, color: AdoptifyColors.primary, size: 32),
                const SizedBox(width: 10),
                Text('Adoptify', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Encuentra a tu próximo compañero o ayuda a un perro que lo necesita.',
              style: textTheme.titleMedium?.copyWith(color: AdoptifyColors.textMuted),
            ),
            const SizedBox(height: 24),
            _ActionCard(
              icon: Icons.map,
              color: AdoptifyColors.primary,
              title: 'Mascotas cerca de ti',
              subtitle: 'Mira en el mapa los animales en adopción y los perros reportados.',
              onTap: () => context.go('/mapa'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.add_location_alt,
              color: AdoptifyColors.report,
              title: 'Reportar un perro abandonado',
              subtitle: 'Marca dónde está para que las fundaciones puedan ayudarlo.',
              onTap: () => context.go('/reportar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AdoptifyColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
