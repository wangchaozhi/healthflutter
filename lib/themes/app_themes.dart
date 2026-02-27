import 'package:flutter/material.dart';

/// 应用自定义颜色扩展，用于健康管理页等使用主题色
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.primary,
    required this.primaryLight,
    required this.surfaceLight,
    required this.surfaceCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentBlue,
    required this.accentOrange,
  });

  final Color primary;
  final Color primaryLight;
  final Color surfaceLight;
  final Color surfaceCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentBlue;
  final Color accentOrange;

  @override
  ThemeExtension<AppThemeColors> copyWith({
    Color? primary,
    Color? primaryLight,
    Color? surfaceLight,
    Color? surfaceCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentBlue,
    Color? accentOrange,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accentBlue: accentBlue ?? this.accentBlue,
      accentOrange: accentOrange ?? this.accentOrange,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    covariant ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
    );
  }
}

/// 主题 ID 枚举
enum AppThemeId {
  teal('teal', '健康绿'),
  blue('blue', '海洋蓝'),
  purple('purple', '优雅紫'),
  sakura('sakura', '樱花粉'),
  dark('dark', '深色模式');

  const AppThemeId(this.key, this.label);
  final String key;
  final String label;

  static AppThemeId fromKey(String key) {
    return AppThemeId.values.firstWhere(
      (e) => e.key == key,
      orElse: () => AppThemeId.teal,
    );
  }
}

/// 主题集合
class AppThemes {
  static const String _storageKey = 'app_theme_id';

  static String get storageKey => _storageKey;

  /// 健康绿（默认）
  static const AppThemeColors tealColors = AppThemeColors(
    primary: Color(0xFF0D9488),
    primaryLight: Color(0xFF5EEAD4),
    surfaceLight: Color(0xFFF0FDFA),
    surfaceCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF134E4A),
    textSecondary: Color(0xFF64748B),
    accentBlue: Color(0xFF0EA5E9),
    accentOrange: Color(0xFFF59E0B),
  );

  /// 海洋蓝
  static const AppThemeColors blueColors = AppThemeColors(
    primary: Color(0xFF0369A1),
    primaryLight: Color(0xFF7DD3FC),
    surfaceLight: Color(0xFFF0F9FF),
    surfaceCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0C4A6E),
    textSecondary: Color(0xFF64748B),
    accentBlue: Color(0xFF0284C7),
    accentOrange: Color(0xFFEA580C),
  );

  /// 优雅紫
  static const AppThemeColors purpleColors = AppThemeColors(
    primary: Color(0xFF7C3AED),
    primaryLight: Color(0xFFC4B5FD),
    surfaceLight: Color(0xFFF5F3FF),
    surfaceCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF4C1D95),
    textSecondary: Color(0xFF64748B),
    accentBlue: Color(0xFF6366F1),
    accentOrange: Color(0xFFF59E0B),
  );

  /// 樱花粉
  static const AppThemeColors sakuraColors = AppThemeColors(
    primary: Color(0xFFDB2777),
    primaryLight: Color(0xFFF9A8D4),
    surfaceLight: Color(0xFFFDF2F8),
    surfaceCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF831843),
    textSecondary: Color(0xFF64748B),
    accentBlue: Color(0xFF0EA5E9),
    accentOrange: Color(0xFFF59E0B),
  );

  /// 深色模式
  static const AppThemeColors darkColors = AppThemeColors(
    primary: Color(0xFF2DD4BF),
    primaryLight: Color(0xFF5EEAD4),
    surfaceLight: Color(0xFF1E293B),
    surfaceCard: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    accentBlue: Color(0xFF38BDF8),
    accentOrange: Color(0xFFFB923C),
  );

  static AppThemeColors colorsFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.teal:
        return tealColors;
      case AppThemeId.blue:
        return blueColors;
      case AppThemeId.purple:
        return purpleColors;
      case AppThemeId.sakura:
        return sakuraColors;
      case AppThemeId.dark:
        return darkColors;
    }
  }

  static ThemeData themeFor(AppThemeId id) {
    final colors = colorsFor(id);
    final isDark = id == AppThemeId.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.surfaceLight,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: colors.primary,
              secondary: colors.primaryLight,
              surface: colors.surfaceLight,
              onPrimary: Colors.white,
              onSurface: colors.textPrimary,
            )
          : ColorScheme.light(
              primary: colors.primary,
              secondary: colors.primaryLight,
              surface: colors.surfaceLight,
              onPrimary: Colors.white,
              onSurface: colors.textPrimary,
            ),
      extensions: [colors],
    );
  }
}
