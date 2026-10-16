import 'package:flutter/material.dart';

/// نظام تصميم سوقنا — ألوان وحركات ومسافات موحّدة لكل التطبيق.
class AppColors {
  static const Color seed = Color(0xFF0F766E);          // أخضر تركوازي أساسي
  static const Color danger = Color(0xFFDC2626);        // أحمر (ديون/رجيع/حذف)
  static const Color warning = Color(0xFFF59E0B);       // برتقالي (مخزون منخفض)
  static const Color success = Color(0xFF16A34A);       // أخضر (أرباح/نجاح)
  static const Color info = Color(0xFF2563EB);          // أزرق (معلومات/بيع)
  static const Color purple = Color(0xFF7C3AED);        // بنفسجي (ذمم)
  static const Color brown = Color(0xFF92400E);         // بني (طابعة)
  static const Color slate = Color(0xFF475569);         // رمادي داكن (تحديث)
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double card = 20;
  static const double button = 14;
  static const double input = 12;
  static const double chip = 10;
}

/// ظل ناعم متعدد الطبقات يعطي عمقًا واقعيًا بدل elevation المسطّح.
List<BoxShadow> softShadow([Color tint = Colors.black]) => [
      BoxShadow(color: tint.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
      BoxShadow(color: tint.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
    ];

List<BoxShadow> elevatedShadow(Color tint) => [
      BoxShadow(color: tint.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6)),
      BoxShadow(color: tint.withOpacity(0.10), blurRadius: 32, offset: const Offset(0, 12)),
    ];

ThemeData buildSouqnaTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // خلفية باردة نظيفة
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    ),
    textTheme: base.textTheme.apply(fontFamilyFallback: ['sans-serif'])
        .copyWith(
      headlineSmall: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
    ),
    dividerTheme: DividerThemeData(space: 1, thickness: 1, color: scheme.outlineVariant.withOpacity(0.5)),
  );
}
