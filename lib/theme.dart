import 'package:flutter/material.dart';

/// Shrinkly identity: fresh teal gradients with a coral accent, on deep green-black (dark)
/// or soft mint white (light).
class AppTheme {
  AppTheme._();

  static const Color teal = Color(0xFF0F9D8A);
  static const Color tealDeep = Color(0xFF0B7A6B);
  static const Color bright = Color(0xFF16BEA0);
  static const Color mint = Color(0xFF34D399);
  static const Color coral = Color(0xFFFF7A59);
  static const Color amber = Color(0xFFFFB627);

  /// Used for the hero card, icon badges and primary highlights.
  static const LinearGradient hero = LinearGradient(
    colors: <Color>[tealDeep, bright],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;

    final bg = dark ? const Color(0xFF09130F) : const Color(0xFFF2FAF8);
    final card = dark ? const Color(0xFF10201B) : Colors.white;
    final border = dark ? const Color(0xFF1D3830) : const Color(0xFFDDEEEA);
    final nav = dark ? const Color(0xFF0D1A16) : Colors.white;
    final field = dark ? const Color(0xFF12241E) : Colors.white;

    final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: b).copyWith(
      primary: dark ? const Color(0xFF5FE0C6) : tealDeep,
      onPrimary: dark ? const Color(0xFF09130F) : Colors.white,
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
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: nav,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        height: 64,
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
