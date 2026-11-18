import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Desde este ancho (tablet, escritorio o navegador) el carrusel muestra flechas para avanzar y retroceder
const carouselArrowsMinWidth = 600.0;

// Arrastrar también con mouse y trackpad: Flutter web y escritorio solo lo permiten con el dedo por defecto.
// Se usa en MaterialApp.scrollBehavior; en el teléfono el gesto de deslizar no cambia.
class AdoptifyScrollBehavior extends MaterialScrollBehavior {
  const AdoptifyScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

// Lista horizontal que se puede recorrer con el dedo, arrastrando con el mouse, con la rueda del mouse
// (la rueda vertical también la mueve hacia el lado) y, en pantallas anchas, con flechas a cada lado.
class HorizontalCarousel extends StatefulWidget {
  const HorizontalCarousel({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = AdoptifySpacing.md,
    this.padding = EdgeInsets.zero,
    this.scrollable = true,
    this.listKey,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;
  // false: las tarjetas caben y la fila queda quieta (sin flechas)
  final bool scrollable;
  final Key? listKey;

  @override
  State<HorizontalCarousel> createState() => _HorizontalCarouselState();
}

class _HorizontalCarouselState extends State<HorizontalCarousel> {
  final _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final back = position.pixels > position.minScrollExtent + 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  // Avanza casi una pantalla, dejando a la vista parte de la tarjeta anterior
  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (position.pixels + direction * position.viewportDimension * 0.8)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  // Rueda del mouse: la rueda vertical también desplaza el carrusel hacia el lado
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
    final position = _controller.position;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => _controller.jumpTo(target));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= carouselArrowsMinWidth;
    final list = ListView.separated(
      key: widget.listKey,
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: widget.scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: widget.itemCount,
      separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
      itemBuilder: widget.itemBuilder,
    );
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollMetricsNotification>(
        // Al cambiar el tamaño (por ejemplo, al girar la pantalla) se recalcula si hay más hacia los lados
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
          return false;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.scrollable ? Listener(onPointerSignal: _onPointerSignal, child: list) : list,
            ),
            if (wide && widget.scrollable && _canBack)
              Positioned(
                left: AdoptifySpacing.xs,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(icon: Icons.chevron_left, tooltip: 'Anterior', onPressed: () => _page(-1))),
              ),
            if (wide && widget.scrollable && _canForward)
              Positioned(
                right: AdoptifySpacing.xs,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(icon: Icons.chevron_right, tooltip: 'Siguiente', onPressed: () => _page(1))),
              ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: CircleBorder(side: BorderSide(color: colors.border)),
      elevation: 2,
      child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, color: colors.text)),
    );
  }
}
