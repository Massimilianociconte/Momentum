/// Padelandia design system — dark premium, palette "campo da padel di notte".
///
/// Principi: superfici profonde con bordi luce, accento lime (palla) usato
/// con parsimonia, gradienti campo-blu per i momenti hero, glow morbidi al
/// posto delle elevation piatte.
library;

import 'package:flutter/material.dart';

abstract final class RallyColors {
  /// Padel court blue.
  static const court = Color(0xFF0E5AA7);
  static const courtDeep = Color(0xFF083A6F);

  /// Ball lime — primary accent.
  static const lime = Color(0xFFC8F135);

  /// Deep night background.
  static const night = Color(0xFF0C1220);
  static const surface = Color(0xFF16202F);
  static const surfaceHigh = Color(0xFF1E2B3E);

  static const win = Color(0xFF3DDC84);
  static const loss = Color(0xFFFF5C6C);

  static const teamUs = lime;
  static const teamThem = Color(0xFF5AB0FF);

  /// Secondary dashboard accents. Each color identifies a product area while
  /// lime remains reserved for primary actions and live scoring.
  static const cyan = Color(0xFF40F3E8);
  static const teamGold = Color(0xFFFFC857);
  static const training = Color(0xFFFF9F43);
  static const goal = Color(0xFFFF987E);

  /// Gradiente hero (score card, pulsanti principali, wrapped).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [court, courtDeep],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF101A2C), night],
  );

  /// Glow morbido per gli elementi accent.
  ///
  /// Blur di default contenuto (12): il costo di rasterizzazione della sfocatura
  /// cresce col raggio, quindi un glow piu compatto riduce il tempo GPU per
  /// frame senza perdere l'effetto "luce" premium.
  static List<BoxShadow> glow(Color color, {double blur = 12}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: blur,
      spreadRadius: -4,
    ),
  ];

  /// Bordo "luce" delle superfici premium.
  static BorderSide get hairline =>
      BorderSide(color: Colors.white.withValues(alpha: 0.06));
}

ThemeData rallyTheme() {
  final scheme = ColorScheme.dark(
    primary: RallyColors.lime,
    onPrimary: const Color(0xFF15200A),
    secondary: RallyColors.teamThem,
    onSecondary: const Color(0xFF06121F),
    surface: RallyColors.surface,
    onSurface: Colors.white,
    surfaceContainerHighest: RallyColors.surfaceHigh,
    error: RallyColors.loss,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RallyColors.night,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: RallyColors.night,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: RallyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: RallyColors.hairline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: WidgetStatePropertyAll(
          RallyColors.lime.withValues(alpha: 0.4),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RallyColors.night,
      indicatorColor: RallyColors.lime,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF15200A), size: 26);
        }
        return const IconThemeData(color: Colors.white70, size: 25);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? RallyColors.lime : Colors.white70,
        );
      }),
      overlayColor: WidgetStatePropertyAll(
        RallyColors.lime.withValues(alpha: 0.08),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RallyColors.surfaceHigh,
      selectedColor: RallyColors.lime.withValues(alpha: 0.25),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RallyColors.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: RallyColors.lime, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.06)),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: RallyColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
