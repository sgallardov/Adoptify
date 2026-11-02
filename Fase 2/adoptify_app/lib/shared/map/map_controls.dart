import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Controles que flotan sobre los mapas a pantalla completa (mapa principal y elegir el punto del reporte)

// Fondo de las tarjetas sobre el mapa: superficie del tema con borde y sombra suave
BoxDecoration mapSurface(BuildContext context, {double radius = AdoptifyRadius.lg}) => BoxDecoration(
  color: context.colors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: context.colors.border),
  boxShadow: AdoptifyShadows.soft,
);

// Botón redondo sobre el mapa (capas, ubicación, volver)
class MapButton extends StatelessWidget {
  const MapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: active ? colors.primary : colors.surface,
          shape: CircleBorder(side: BorderSide(color: active ? colors.primary : colors.border)),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: loading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 22, color: active ? Colors.white : colors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
