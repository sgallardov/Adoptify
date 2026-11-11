import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/content_width.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../auth/two_factor_card.dart';
import 'adoption_card.dart';

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
              // Con scroll: en pantallas bajas el aviso, la apariencia y el botón no caben juntos
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AdoptifySpacing.xl, 0, AdoptifySpacing.xl, AdoptifySpacing.xl),
                  child: ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ComingSoon(
                          icon: Icons.person,
                          title: 'Tu cuenta de Adoptify',
                          message: 'Usa el mismo correo y contraseña del portal web.',
                        ),
                        FilledButton(
                          onPressed: () => context.push('/login'),
                          child: const Text('Iniciar sesión'),
                        ),
                        const SizedBox(height: AdoptifySpacing.xl),
                        const _AppearanceCard(),
                      ],
                    ),
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
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
                border: Border.all(color: context.colors.border),
                boxShadow: AdoptifyShadows.soft,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: context.colors.primarySoft,
                    child: Text(
                      initial,
                      style: textTheme.headlineSmall?.copyWith(color: context.colors.primaryDark),
                    ),
                  ),
                  const SizedBox(height: AdoptifySpacing.md),
                  Text(user.fullName, style: textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AdoptifySpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.md, vertical: AdoptifySpacing.xs),
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(user.roleLabel, style: textTheme.labelMedium?.copyWith(color: context.colors.primaryText)),
                  ),
                  const SizedBox(height: AdoptifySpacing.xl),
                  const Divider(),
                  _InfoRow(icon: Icons.mail_outline, label: 'Correo', value: user.email),
                  _InfoRow(icon: Icons.badge_outlined, label: 'RUT', value: user.rut),
                ],
              ),
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            const AdoptionCard(),
            const SizedBox(height: AdoptifySpacing.lg),
            const TwoFactorCard(),
            const SizedBox(height: AdoptifySpacing.lg),
            const _AppearanceCard(),
            const SizedBox(height: AdoptifySpacing.xl),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primaryDark,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Apariencia de la app: sigue al sistema por defecto, o se fija en claro u oscuro
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Apariencia', style: textTheme.titleMedium),
          const SizedBox(height: AdoptifySpacing.xs),
          Text('Elige el modo claro u oscuro, o usa el de tu teléfono.', style: textTheme.bodySmall),
          const SizedBox(height: AdoptifySpacing.md),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistema')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Oscuro')),
            ],
            selected: {theme.mode},
            onSelectionChanged: (selection) => theme.setMode(selection.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected) ? colors.primarySoft : colors.surface,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected) ? colors.primaryText : colors.textMuted,
              ),
              side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
              textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
            ),
          ),
        ],
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
          Icon(icon, size: 20, color: context.colors.textMuted),
          const SizedBox(width: AdoptifySpacing.md),
          Text(label, style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted)),
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
