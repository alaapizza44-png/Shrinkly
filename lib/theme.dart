import 'package:flutter/material.dart';

/// Creator-app identity: indigo-to-fuchsia gradients with a mint accent, on deep ink (dark)
/// or a soft lilac white (light). (Names kept from the first palette.)
class AppTheme {
  AppTheme._();

  static const Color teal = Color(0xFF7C3AED);
  static const Color tealDeep = Color(0xFF5B21B6);
  static const Color bright = Color(0xFFD946EF);
  static const Color mint = Color(0xFF2DD4BF);
  static const Color coral = Color(0xFFFF6B8A);
  static const Color amber = Color(0xFFFFB627);

  /// Used for the hero card, icon badges and primary highlights.
  static const LinearGradient hero = LinearGradient(
    colors: <Color>[Color(0xFF4F46E5), Color(0xFF9333EA), bright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;

    final bg = dark ? const Color(0xFF0B0A14) : const Color(0xFFF6F4FF);
    final card = dark ? const Color(0xFF15132A) : Colors.white;
    final border = dark ? const Color(0xFF282546) : const Color(0xFFE4DEFA);
    final nav = dark ? const Color(0xFF100E1F) : Colors.white;
    final field = dark ? const Color(0xFF1B1933) : Colors.white;

    final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: b).copyWith(
      primary: dark ? const Color(0xFFB69CFF) : tealDeep,
      onPrimary: dark ? const Color(0xFF1A0B3D) : Colors.white,
      secondary: mint,
      surface: bg,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: nav,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.2),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: nav,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
