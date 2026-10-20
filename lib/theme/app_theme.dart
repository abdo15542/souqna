import 'package:flutter/material.dart';

class AppColors {
  static const Color seed = Color(0xFF0F766E);          // أخضر تركوازي أساسي
  static const Color danger = Color(0xFFDC2626);        // أحمر (ديون/رجيع/حذف)
  static const Color warning = Color(0xFFF59E0B);       // برتقالي (مخزون منخفض)
  static const Color success = Color(0xFF16A34A);       // أخضر (أرباح/نجاح)
  static const Color info = Color(0xFF2563EB);          // أزرق (معلومات/بيع)
  static const Color purple = Color(0xFF7C3AED);        // بنفسجي (ذمم)
  static const Color brown = Color(0xFF92400E);         // بني (طابعة)
  static const Color slate = Color(0xFF475569);         // رمادي داكن (تحديث)
  
  // ألوان نص عالية الوضوح (تم استبدال grey.shade600 الغامضة)
  static const Color textPrimary = Color(0xFF111827);   // أسود شبه كامل للعناوين
  static const Color textSecondary = Color(0xFF374151); // رمادي داكن واضح للنصوص الفرعية
  static const Color textMuted = Color(0xFF6B7280);     // رمادي متوسط للتلميحات فقط
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

List<BoxShadow> softShadow([Color tint = Colors.black]) => [
      BoxShadow(color: tint.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
      BoxShadow(color: tint.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8)),
    ];

ThemeData buildSouqnaTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,                    // ← كبرنا العنوان الرئيسي
        fontWeight: FontWeight.w800,     // ← أثقل وزنًا
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 26),
    ),
    
    textTheme: base.textTheme.apply(fontFamilyFallback: ['sans-serif']).copyWith(
      headlineSmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
      titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.textSecondary),
      bodySmall: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textMuted),
      labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    ),
    
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md + 2),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      contentTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    
    dividerTheme: DividerThemeData(space: 1, thickness: 1, color: scheme.outlineVariant.withOpacity(0.5)),
  );
}
