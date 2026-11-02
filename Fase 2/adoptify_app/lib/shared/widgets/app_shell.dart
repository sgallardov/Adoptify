import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

// Índices de las pestañas, en el mismo orden que las ramas de app/router.dart
const _foundationsTab = 0;
const _mapTab = 1;
const _profileTab = 2;

// Estructura común de las pestañas: contenido + barra de navegación inferior
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Tocar la pestaña activa vuelve a su pantalla inicial
  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final current = shell.currentIndex;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
          boxShadow: const [BoxShadow(color: Color(0x0A1C1917), blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            // En pantallas anchas la barra no se estira: su contenido queda centrado
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AdoptifySpacing.md,
                  AdoptifySpacing.sm,
                  AdoptifySpacing.md,
                  AdoptifySpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavTab(
                        label: 'Fundaciones',
                        icon: Icons.volunteer_activism_outlined,
                        activeIcon: Icons.volunteer_activism,
                        active: current == _foundationsTab,
                        onTap: () => _go(_foundationsTab),
                      ),
                    ),
                    Expanded(
                      child: _NavTab(
                        label: 'Mapa',
                        icon: Icons.map_outlined,
                        activeIcon: Icons.map,
                        active: current == _mapTab,
                        onTap: () => _go(_mapTab),
                      ),
                    ),
                    Expanded(
                      child: _NavTab(
                        label: 'Perfil',
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        active: current == _profileTab,
                        onTap: () => _go(_profileTab),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _iconSize = 24.0;

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.primaryDark : context.colors.textMuted;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? context.colors.text : context.colors.textMuted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        );

    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdoptifyRadius.md),
          child: SizedBox(
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicador de pestaña activa: píldora naranja suave detrás del ícono
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 28,
                  decoration: BoxDecoration(
                    color: active ? context.colors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(active ? activeIcon : icon, color: color, size: _iconSize),
                ),
                const SizedBox(height: 2),
                Text(label, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
