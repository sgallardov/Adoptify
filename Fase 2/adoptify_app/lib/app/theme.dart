import 'package:flutter/material.dart';

// Misma paleta que el portal web (Tailwind orange/stone)
class AdoptifyColors {
  static const primary = Color(0xFFEA580C); // orange-600
  static const primaryDark = Color(0xFFC2410C); // orange-700
  static const primarySoft = Color(0xFFFFF7ED); // orange-50
  static const primaryText = Color(0xFF9A3412); // orange-800
  static const primaryTextDark = Color(0xFF7C2D12); // orange-900
  static const surface = Colors.white;
  static const muted = Color(0xFFF5F5F4); // stone-100
  static const border = Color(0xFFE7E5E4); // stone-200
  static const placeholder = Color(0xFFA8A29E); // stone-400
  static const background = Color(0xFFFAF9F6);
  static const text = Color(0xFF292524); // stone-800
  static const textMuted = Color(0xFF78716C); // stone-500
  static const report = Color(0xFFDC2626); // red-600, pines de reportes
  static const reportText = Color(0xFFB91C1C); // red-700
  static const origin = Color(0xFF0284C7); // sky-600, tu ubicación
  static const success = Color(0xFF14532D); // green-900
  static const successSoft = Color(0xFFF0FDF4); // green-50
}

// Espaciado: siempre múltiplos de 4 para que las pantallas se vean alineadas
class AdoptifySpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AdoptifyRadius {
  static const sm = 8.0;
  static const md = 12.0; // botones y campos
  static const lg = 16.0; // tarjetas y mapas
  static const xl = 24.0; // contenedores grandes
}

// Una sola sombra sutil para todo lo que flota sobre el fondo (tarjetas, fichas, barra)
class AdoptifyShadows {
  static const soft = [
    BoxShadow(color: Color(0x0F1C1917), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A1C1917), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

// Ancho máximo del contenido en pantallas anchas (tablet y escritorio)
const contentMaxWidth = 640.0;

// Escala tipográfica: los widgets usan estos estilos en vez de tamaños sueltos
TextTheme _textTheme() {
  const color = AdoptifyColors.text;
  return const TextTheme(
    headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: color),
    titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: color),
    titleMedium: TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600, color: color),
    titleSmall: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: color),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: color),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400, color: color),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, color: AdoptifyColors.textMuted),
    labelLarge: TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w600, color: color),
    labelMedium: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: color),
    labelSmall: TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: color),
  );
}

// Contorno visible al navegar con teclado, como :focus-visible del portal
const _focusSide = BorderSide(color: AdoptifyColors.primaryDark, width: 2);

ThemeData buildAdoptifyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdoptifyColors.primary,
    primary: AdoptifyColors.primary,
    surface: AdoptifyColors.background,
  );
  final text = _textTheme();
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdoptifyRadius.md));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdoptifyColors.background,
    textTheme: text,
    // Hover y focus para todos los InkWell (tarjetas, pestañas, enlaces)
    hoverColor: const Color(0x0A1C1917),
    focusColor: AdoptifyColors.primary.withValues(alpha: 0.14),
    splashColor: AdoptifyColors.primary.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: AdoptifyColors.background,
      foregroundColor: AdoptifyColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: text.titleLarge,
      toolbarHeight: 60,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AdoptifyColors.primary.withValues(alpha: 0.55)
              : states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)
                  ? AdoptifyColors.primaryDark
                  : AdoptifyColors.primary,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AdoptifySpacing.xl)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? _focusSide : BorderSide.none,
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AdoptifyColors.text),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? AdoptifyColors.muted : AdoptifyColors.surface,
        ),
        overlayColor: const WidgetStatePropertyAll(Color(0x0A1C1917)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? _focusSide
              : const BorderSide(color: AdoptifyColors.border),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AdoptifyColors.primaryDark),
        overlayColor: WidgetStatePropertyAll(AdoptifyColors.primary.withValues(alpha: 0.08)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AdoptifyRadius.sm))),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? _focusSide : BorderSide.none,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AdoptifyColors.textMuted),
        overlayColor: const WidgetStatePropertyAll(Color(0x0F1C1917)),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? _focusSide : BorderSide.none,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: AdoptifyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        side: const BorderSide(color: AdoptifyColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AdoptifyColors.border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AdoptifyColors.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
      insetPadding: const EdgeInsets.all(AdoptifySpacing.lg),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AdoptifyColors.primary),
    // Campos como los inputs del portal: blancos, borde stone-200 y esquinas de 12
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdoptifyColors.surface,
      hintStyle: text.bodyMedium?.copyWith(color: AdoptifyColors.placeholder),
      contentPadding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: const BorderSide(color: AdoptifyColors.border),
      ),
      hoverColor: AdoptifyColors.muted,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: _focusSide,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: const BorderSide(color: AdoptifyColors.report),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: const BorderSide(color: AdoptifyColors.report, width: 2),
      ),
    ),
  );
}
