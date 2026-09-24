import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.feltGreenDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.feltGreen,
      brightness: Brightness.dark,
      primary: AppColors.gold,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.feltGreenDark,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.gold,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white70),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: AppColors.gold,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

/// Başlıklar için kullanılan, casino/premium hissi veren gösterişli
/// yazı tipi (Google Fonts - Cinzel).
TextStyle displayTitleStyle({double fontSize = 32, Color color = AppColors.gold}) {
  return GoogleFonts.cinzel(
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: color,
    letterSpacing: 2,
  );
}
