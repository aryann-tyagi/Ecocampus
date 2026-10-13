import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static final TextStyle displayLarge = GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.inkPrimary,
    letterSpacing: -0.8,
  );

  static final TextStyle titleLarge = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.inkPrimary,
    letterSpacing: -0.4,
  );

  static final TextStyle titleMedium = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.inkPrimary,
  );

  static final TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.inkPrimary,
  );

  static final TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSecondary,
  );

  static final TextStyle bodySmall = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.inkMuted,
  );

  static final TextStyle labelLarge = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.inkPrimary,
  );

  static final TextStyle labelMedium = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.inkPrimary,
  );
}

class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.inkPrimary,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.titleMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.inkPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.inkPrimary),
    ),
  );
}
