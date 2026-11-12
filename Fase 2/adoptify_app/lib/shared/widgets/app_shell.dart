import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

// Una pestaña de la barra inferior. highlighted la destaca (relleno de la marca) para la acción principal;
// tooltip, si está, se muestra al mantener presionada y la lee el lector de pantalla.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.tooltip,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String? tooltip;
  final bool highlighted;
}

// Vista de adoptante: Fundaciones, Mapa, Match y Perfil, en el mismo orden que las ramas de app/router.dart
const _userItems = [
  NavItem(label: 'Fundaciones', icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism),
  NavItem(label: 'Mapa', icon: Icons.map_outlined, activeIcon: Icons.map),
  NavItem(label: 'Match', icon: Icons.favorite_border, activeIcon: Icons.favorite),
  NavItem(label: 'Perfil', icon: Icons.person_outline, activeIcon: Icons.person),
];

// Vista de fundación: Inicio, Chat y Perfil. Publicar un animal vive en su propio flujo desde Inicio.
const _foundationItems = [
  NavItem(label: 'Inicio', icon: Icons.home_outlined, activeIcon: Icons.home),
  NavItem(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    tooltip: 'Chat con adoptantes',
  ),
  NavItem(
    label: 'Perfil',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    tooltip: 'Perfil de la fundación',
  ),
];

// Estructura de las pestañas de adoptante: contenido + barra de navegación inferior
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => _TabsShell(shell: shell, items: _userItems);
}

// Lo mismo para las cuentas de fundación (y admin): otra barra, igual diseño
class FoundationShell extends StatelessWidget {
  const FoundationShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => _TabsShell(shell: shell, items: _foundationItems);
}

class _TabsShell extends StatelessWidget {
  const _TabsShell({required this.shell, required this.items});

  final StatefulNavigationShell shell;
  final List<NavItem> items;

  // Tocar la pestaña activa vuelve a su pantalla inicial
  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _NavBar(items: items, currentIndex: shell.currentIndex, onTap: _go),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.items, required this.currentIndex, required this.onTap});

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavTab(item: items[i], active: i == currentIndex, onTap: () => onTap(i)),
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

const _iconSize = 24.0;

class _NavTab extends StatelessWidget {
  const _NavTab({required this.item, required this.active, required this.onTap});

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highlighted = item.highlighted;
    // La pestaña destacada lleva siempre el relleno de la marca (como el botón principal de la app)
    final iconColor = highlighted ? Colors.white : (active ? colors.primaryDark : colors.textMuted);
    final pillColor = highlighted ? colors.primary : (active ? colors.primarySoft : Colors.transparent);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active || highlighted ? colors.text : colors.textMuted,
          fontWeight: active || highlighted ? FontWeight.w700 : FontWeight.w500,
        );

    final tab = Semantics(
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
                  decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(99)),
                  child: Icon(active ? item.activeIcon : item.icon, color: iconColor, size: _iconSize),
                ),
                const SizedBox(height: 2),
                // Con tres o cuatro pestañas el texto puede no caber: se reduce en vez de partirse en dos líneas
                FittedBox(fit: BoxFit.scaleDown, child: Text(item.label, style: labelStyle, maxLines: 1)),
              ],
            ),
          ),
        ),
      ),
    );

    final tooltip = item.tooltip;
    return tooltip == null ? tab : Tooltip(message: tooltip, child: tab);
  }
}
