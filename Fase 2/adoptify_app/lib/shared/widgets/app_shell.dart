import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

// Índices de las pestañas, en el mismo orden que las ramas de app/router.dart
const _reportTab = 0;
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
        decoration: const BoxDecoration(
          color: AdoptifyColors.surface,
          border: Border(top: BorderSide(color: AdoptifyColors.border)),
          boxShadow: [BoxShadow(color: Color(0x0A1C1917), blurRadius: 12, offset: Offset(0, -2))],
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
                    // Los tres elementos tienen el mismo ancho; Reportar destaca solo por su fondo rojo
                    Expanded(
                      child: _ReportTab(active: current == _reportTab, onTap: () => _go(_reportTab)),
                    ),
                    const SizedBox(width: AdoptifySpacing.sm),
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

// Acción principal: botón rojo destacado, el mismo rojo del botón "Reportar perro" de la web
class _ReportTab extends StatelessWidget {
  const _ReportTab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdoptifyRadius.md);
    return Semantics(
      button: true,
      selected: active,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: active ? AdoptifyColors.reportText : AdoptifyColors.report,
          borderRadius: radius,
          // Activo: anillo suave alrededor para distinguirlo del estado normal
          boxShadow: [
            if (active) BoxShadow(color: AdoptifyColors.report.withValues(alpha: 0.25), spreadRadius: 3),
            const BoxShadow(color: Color(0x26DC2626), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            hoverColor: const Color(0x1AFFFFFF),
            focusColor: const Color(0x33FFFFFF),
            splashColor: const Color(0x26FFFFFF),
            // Misma estructura que Mapa y Perfil: ícono de 24 px arriba y etiqueta abajo
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? Icons.add_location_alt : Icons.add_location_alt_outlined,
                    color: Colors.white,
                    size: _iconSize,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reportar mascota',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final color = active ? AdoptifyColors.primaryDark : AdoptifyColors.textMuted;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? AdoptifyColors.text : AdoptifyColors.textMuted,
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
                    color: active ? AdoptifyColors.primarySoft : Colors.transparent,
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
