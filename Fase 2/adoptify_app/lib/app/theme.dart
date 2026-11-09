import 'package:flutter/material.dart';

// Misma paleta que el portal web (Tailwind orange/stone), en versión clara y oscura.
// Los widgets la leen del tema con context.colors, así cambia sola al pasar a modo oscuro.
@immutable
class AdoptifyColors extends ThemeExtension<AdoptifyColors> {
  const AdoptifyColors({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryText,
    required this.primaryTextDark,
    required this.surface,
    required this.muted,
    required this.border,
    required this.placeholder,
    required this.background,
    required this.text,
    required this.textMuted,
    required this.report,
    required this.reportStrong,
    required this.reportText,
    required this.origin,
    required this.success,
    required this.successSoft,
    required this.primaryStrong,
    required this.successStrong,
    required this.onAccent,
    required this.foundation,
  });

  final Color primary; // botones y pines de mascotas (orange-600)
  final Color primaryDark; // hover, foco, íconos y enlaces activos
  final Color primarySoft; // fondos suaves de la marca
  final Color primaryText; // texto sobre primarySoft
  final Color primaryTextDark; // texto destacado sobre primarySoft
  final Color surface; // tarjetas, campos y barra inferior
  final Color muted; // fondos grises y hover
  final Color border; // bordes y divisores
  final Color placeholder; // textos de ayuda e íconos de relleno
  final Color background; // fondo de las pantallas
  final Color text; // texto principal
  final Color textMuted; // texto secundario
  final Color report; // pines y botón de reportes (red-600)
  final Color reportStrong; // fondo del botón Reportar activo (red-700)
  final Color reportText; // texto de reportes y errores
  final Color origin; // pin de tu ubicación (sky)
  final Color success; // texto de éxito
  final Color successSoft; // fondo de mensajes de éxito
  // Fondos de color con texto onAccent encima (insignias, encabezados). Son iguales en los dos modos:
  // primaryDark y success se aclaran en modo oscuro porque son para texto, y ahí el blanco no se lee.
  final Color primaryStrong; // naranjo (orange-700), contraste 5:1 con blanco
  final Color successStrong; // verde (green-700), contraste 5:1 con blanco
  final Color onAccent; // texto e íconos sobre primary, primaryStrong y successStrong
  final Color foundation; // pines de fundaciones en el mapa (cyan-600), con onAccent encima

  static const light = AdoptifyColors(
    primary: Color(0xFFEA580C),
    primaryDark: Color(0xFFC2410C),
    primarySoft: Color(0xFFFFF7ED),
    primaryText: Color(0xFF9A3412),
    primaryTextDark: Color(0xFF7C2D12),
    surface: Color(0xFFFFFFFF),
    muted: Color(0xFFF5F5F4),
    border: Color(0xFFE7E5E4),
    placeholder: Color(0xFFA8A29E),
    background: Color(0xFFFAF9F6),
    text: Color(0xFF292524),
    textMuted: Color(0xFF78716C),
    report: Color(0xFFDC2626),
    reportStrong: Color(0xFFB91C1C),
    reportText: Color(0xFFB91C1C),
    origin: Color(0xFF0284C7),
    success: Color(0xFF14532D),
    successSoft: Color(0xFFF0FDF4),
    primaryStrong: Color(0xFFC2410C),
    successStrong: Color(0xFF15803D),
    onAccent: Color(0xFFFFFFFF),
    foundation: Color(0xFF0891B2),
  );

  static const dark = AdoptifyColors(
    primary: Color(0xFFEA580C),
    primaryDark: Color(0xFFFB923C),
    primarySoft: Color(0xFF3B1F0E),
    primaryText: Color(0xFFFDBA74),
    primaryTextDark: Color(0xFFFED7AA),
    surface: Color(0xFF1F1B18),
    muted: Color(0xFF2A2521),
    border: Color(0xFF3A3430),
    placeholder: Color(0xFF78716C),
    background: Color(0xFF141210),
    text: Color(0xFFF5F5F4),
    textMuted: Color(0xFFA8A29E),
    report: Color(0xFFDC2626),
    reportStrong: Color(0xFFB91C1C),
    reportText: Color(0xFFF87171),
    origin: Color(0xFF0EA5E9),
    success: Color(0xFF86EFAC),
    successSoft: Color(0xFF052E16),
    primaryStrong: Color(0xFFC2410C),
    successStrong: Color(0xFF15803D),
    onAccent: Color(0xFFFFFFFF),
    foundation: Color(0xFF0891B2),
  );

  static AdoptifyColors of(BuildContext context) => Theme.of(context).extension<AdoptifyColors>()!;

  @override
  AdoptifyColors copyWith() => this;

  // Transición suave entre claro y oscuro
  @override
  AdoptifyColors lerp(AdoptifyColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AdoptifyColors(
      primary: mix(primary, other.primary),
      primaryDark: mix(primaryDark, other.primaryDark),
      primarySoft: mix(primarySoft, other.primarySoft),
      primaryText: mix(primaryText, other.primaryText),
      primaryTextDark: mix(primaryTextDark, other.primaryTextDark),
      surface: mix(surface, other.surface),
      muted: mix(muted, other.muted),
      border: mix(border, other.border),
      placeholder: mix(placeholder, other.placeholder),
      background: mix(background, other.background),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      report: mix(report, other.report),
      reportStrong: mix(reportStrong, other.reportStrong),
      reportText: mix(reportText, other.reportText),
      origin: mix(origin, other.origin),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      primaryStrong: mix(primaryStrong, other.primaryStrong),
      successStrong: mix(successStrong, other.successStrong),
      onAccent: mix(onAccent, other.onAccent),
      foundation: mix(foundation, other.foundation),
    );
  }
}

extension AdoptifyColorsContext on BuildContext {
  AdoptifyColors get colors => AdoptifyColors.of(this);
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
TextTheme _textTheme(AdoptifyColors c) {
  final color = c.text;
  return TextTheme(
    headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: color),
    titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: color),
    titleMedium: TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600, color: color),
    titleSmall: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: color),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: color),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400, color: color),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400, color: c.textMuted),
    labelLarge: TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w600, color: color),
    labelMedium: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: color),
    labelSmall: TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: color),
  );
}

ThemeData buildAdoptifyTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final c = dark ? AdoptifyColors.dark : AdoptifyColors.light;
  // Capa de hover y pulsado: oscurece en modo claro y aclara en modo oscuro
  final overlay = dark ? const Color(0x14FFFFFF) : const Color(0x0A1C1917);
  // Contorno visible al navegar con teclado, como :focus-visible del portal
  final focusSide = BorderSide(color: c.primaryDark, width: 2);
  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: brightness,
    primary: c.primary,
    surface: c.background,
  );
  final text = _textTheme(c);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdoptifyRadius.md));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [c],
    scaffoldBackgroundColor: c.background,
    textTheme: text,
    // Hover y focus para todos los InkWell (tarjetas, pestañas, enlaces)
    hoverColor: overlay,
    focusColor: c.primary.withValues(alpha: 0.14),
    splashColor: c.primary.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
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
              ? c.primary.withValues(alpha: 0.55)
              : states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)
                  ? c.primaryDark
                  : c.primary,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AdoptifySpacing.xl)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : BorderSide.none,
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.text),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? c.muted : c.surface,
        ),
        overlayColor: WidgetStatePropertyAll(overlay),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? focusSide
              : BorderSide(color: c.border),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.primaryDark),
        overlayColor: WidgetStatePropertyAll(c.primary.withValues(alpha: 0.08)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AdoptifyRadius.sm))),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : BorderSide.none,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(c.textMuted),
        overlayColor: WidgetStatePropertyAll(overlay),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : BorderSide.none,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
      insetPadding: const EdgeInsets.all(AdoptifySpacing.lg),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    // Campos como los inputs del portal: color de tarjeta, borde stone-200 y esquinas de 12
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: text.bodyMedium?.copyWith(color: c.placeholder),
      contentPadding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.lg, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: BorderSide(color: c.border),
      ),
      hoverColor: c.muted,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: focusSide,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: BorderSide(color: c.report),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdoptifyRadius.md),
        borderSide: BorderSide(color: c.report, width: 2),
      ),
    ),
  );
}
