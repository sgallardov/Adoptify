import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: auth.loading
          ? Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AdoptifySpacing.md),
                  Text('Cargando sesión…', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : user == null
              ? ContentWidth(
                  child: Column(
                    children: [
                      const Expanded(
                        child: ComingSoon(
                          icon: Icons.person,
                          title: 'Tu cuenta de Adoptify',
                          message: 'Usa el mismo correo y contraseña del portal web.',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AdoptifySpacing.xl),
                        child: FilledButton(
                          onPressed: () => context.push('/login'),
                          child: const Text('Iniciar sesión'),
                        ),
                      ),
                    ],
                  ),
                )
              : _Profile(user: user, onSignOut: auth.signOut),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.user, required this.onSignOut});

  final AppUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = user.fullName.trim().isEmpty ? '?' : user.fullName.trim()[0].toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, AdoptifySpacing.xl),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AdoptifySpacing.xl),
              decoration: BoxDecoration(
                color: AdoptifyColors.surface,
                borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
                border: Border.all(color: AdoptifyColors.border),
                boxShadow: AdoptifyShadows.soft,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AdoptifyColors.primarySoft,
                    child: Text(
                      initial,
                      style: textTheme.headlineSmall?.copyWith(color: AdoptifyColors.primaryDark),
                    ),
                  ),
                  const SizedBox(height: AdoptifySpacing.md),
                  Text(user.fullName, style: textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AdoptifySpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.xs),
                    decoration: BoxDecoration(
                      color: AdoptifyColors.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(user.roleLabel, style: textTheme.labelMedium?.copyWith(color: AdoptifyColors.primaryText)),
                  ),
                  const SizedBox(height: AdoptifySpacing.xl),
                  const Divider(),
                  _InfoRow(icon: Icons.mail_outline, label: 'Correo', value: user.email),
                  _InfoRow(icon: Icons.badge_outlined, label: 'RUT', value: user.rut),
                ],
              ),
            ),
            const SizedBox(height: AdoptifySpacing.xl),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdoptifyColors.primaryDark,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AdoptifySpacing.lg),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AdoptifyColors.textMuted),
          const SizedBox(width: AdoptifySpacing.md),
          Text(label, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted)),
          const SizedBox(width: AdoptifySpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
