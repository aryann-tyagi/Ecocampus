import 'package:flutter/material.dart';

/// Semantic and visual design tokens matching the EcoCampus UI design reference.
class AppColors {
  AppColors._();

  // Primary brand palette
  static const Color primary = Color(0xFF144D37);
  static const Color primaryHover = Color(0xFF0F3E2C);
  static const Color primaryContainer = Color(0xFFD6F2E3);
  static const Color onPrimary = Colors.white;

  // Surfaces & Background
  static const Color background = Color(0xFFEFF5F1);
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF6FAF7);
  static const Color surfaceCard = Colors.white;

  // Typography ink
  static const Color inkPrimary = Color(0xFF142C21);
  static const Color inkSecondary = Color(0xFF5A7266);
  static const Color inkMuted = Color(0xFF8BA095);
  static const Color border = Color(0xFFE1EBE4);
  static const Color borderLight = Color(0xFFEEF4F0);

  // Severity colors
  static const Color severityLow = Color(0xFF1EA05A);
  static const Color severityLowBg = Color(0xFFE8F7EE);
  static const Color severityMedium = Color(0xFFD98327);
  static const Color severityMediumBg = Color(0xFFFDF4E7);
  static const Color severityHigh = Color(0xFFD65236);
  static const Color severityHighBg = Color(0xFFFDECE8);
  static const Color severityCritical = Color(0xFFC5231F);
  static const Color severityCriticalBg = Color(0xFFFCEAEA);

  // Status tokens
  static const Color statusReported = Color(0xFF2F80ED);
  static const Color statusAssigned = Color(0xFFE29520);
  static const Color statusInProgress = Color(0xFF9B51E0);
  static const Color statusResolved = Color(0xFF27AE60);

  // Sprig hero banner gradient
  static const Color sprigGradientStart = Color(0xFFC6F3DD);
  static const Color sprigGradientEnd = Color(0xFFE3FAF1);

  // Categories
  static const Color catWaste = Color(0xFFD65236);
  static const Color catWater = Color(0xFF2F80ED);
  static const Color catEnergy = Color(0xFFD98327);
  static const Color catGreenery = Color(0xFF1EA05A);
  static const Color catInfrastructure = Color(0xFF6C5CE7);
  static const Color catCleanliness = Color(0xFF00CEC9);
  static const Color catOther = Color(0xFF636E72);
}
