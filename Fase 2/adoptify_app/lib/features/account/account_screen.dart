import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/coming_soon.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: auth.loading
          ? const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Cargando sesión…'),
                ],
              ),
            )
          : user == null
              ? Column(
                  children: [
                    const Expanded(
                      child: ComingSoon(
                        icon: Icons.person,
                        title: 'Tu cuenta de Adoptify',
                        message: 'Usa el mismo correo y contraseña del portal web.',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: FilledButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                  ],
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AdoptifyColors.primarySoft,
                  child: Text(
                    initial,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AdoptifyColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.fullName, style: textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(user.roleLabel, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.primaryDark)),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AdoptifyColors.muted),
                _InfoRow(icon: Icons.mail_outline, label: 'Correo', value: user.email),
                _InfoRow(icon: Icons.badge_outlined, label: 'RUT', value: user.rut),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdoptifyColors.primaryDark,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: AdoptifyColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AdoptifyColors.textMuted),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AdoptifyColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
