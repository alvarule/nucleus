import 'package:flutter/material.dart';

/// Semantic tokens for the Rose vault palette, exposed as a [ThemeExtension].
/// Hand-authored — never use ColorScheme.fromSeed.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.onPrimary,
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.overlay,
  });

  final Color primary;
  final Color primaryHover;
  final Color primarySoft;
  final Color onPrimary;
  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color overlay;

  static const light = AppColors(
    primary: Color(0xFFF21649),
    primaryHover: Color(0xFFD4143F),
    primarySoft: Color(0xFFFFE5EC),
    onPrimary: Color(0xFFFFFFFF),
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF0F3),
    border: Color(0xFFE2E5EB),
    textPrimary: Color(0xFF14151A),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    success: Color(0xFF0D9F6E),
    warning: Color(0xFFD97706),
    danger: Color(0xFFE11D48),
    overlay: Color(0x9914151A),
  );

  static const dark = AppColors(
    primary: Color(0xFFFF4D73),
    primaryHover: Color(0xFFF21649),
    primarySoft: Color(0xFF3D1524),
    onPrimary: Color(0xFFFFFFFF),
    bg: Color(0xFF0F1014),
    surface: Color(0xFF1A1B22),
    surfaceMuted: Color(0xFF24262F),
    border: Color(0xFF2E303A),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    overlay: Color(0xB3000000),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? onPrimary,
    Color? bg,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? overlay,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
