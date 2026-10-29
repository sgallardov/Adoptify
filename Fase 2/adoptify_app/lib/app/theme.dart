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

ThemeData buildAdoptifyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdoptifyColors.primary,
    primary: AdoptifyColors.primary,
    surface: AdoptifyColors.background,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AdoptifyColors.background,
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AdoptifyColors.text,
          displayColor: AdoptifyColors.text,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdoptifyColors.background,
      foregroundColor: AdoptifyColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AdoptifyColors.primarySoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AdoptifyColors.primaryDark
              : AdoptifyColors.textMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdoptifyColors.primary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdoptifyColors.border),
      ),
    ),
    // Campos como los inputs del portal: blancos, borde stone-200 y esquinas de 12
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdoptifyColors.surface,
      hintStyle: const TextStyle(color: AdoptifyColors.placeholder, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdoptifyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdoptifyColors.primaryDark, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdoptifyColors.report),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdoptifyColors.report, width: 2),
      ),
    ),
  );
}
