import 'package:flutter/material.dart';

class MiuiColors {
  // MIUI Accent & Primary Colors
  static const Color primaryBlue = Color(0xFF0C84FF);
  static const Color primaryTeal = Color(0xFF00C6FF);
  static const Color callGreen = Color(0xFF25D366);
  static const Color callRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);

  // MIUI Dark Theme Colors
  static const Color darkBackground = Color(0xFF000000); // Home Screen AMOLED Black
  static const Color darkSurface = Color(0xFF1E232D);
  static const Color darkCard = Color(0xFF181C24);
  static const Color darkBorder = Color(0xFF2B313E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E98A8);
  static const Color darkKeypadBg = Color(0xFF151921); // Restored Dialer Dark Background
  static const Color darkKeypadBtn = Color(0xFF222834);

  // MIUI Light Theme Colors
  static const Color lightBackground = Color(0xFFF4F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightKeypadBg = Color(0xFFFFFFFF);
  static const Color lightKeypadBtn = Color(0xFFF3F4F6);
}

class MiuiTheme {
  static const String fontFamily = 'Roboto';
  static const String mitypeFont = 'Mitype';
  static const List<String> fontFamilyFallback = ['sans-serif', 'Roboto'];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    brightness: Brightness.light,
    scaffoldBackgroundColor: MiuiColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: MiuiColors.primaryBlue,
      secondary: MiuiColors.callGreen,
      surface: MiuiColors.lightSurface,
      error: MiuiColors.callRed,
      onSurface: MiuiColors.lightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MiuiColors.lightSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: MiuiColors.lightTextPrimary,
      ),
      iconTheme: IconThemeData(color: MiuiColors.lightTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: MiuiColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MiuiColors.lightBorder, width: 0.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MiuiColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MiuiColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MiuiColors.callGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.normal, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.normal, fontSize: 14),
      labelLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MiuiColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: MiuiColors.primaryBlue,
      secondary: MiuiColors.callGreen,
      surface: MiuiColors.darkSurface,
      error: MiuiColors.callRed,
      onSurface: MiuiColors.darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MiuiColors.darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: MiuiColors.darkTextPrimary,
      ),
      iconTheme: IconThemeData(color: MiuiColors.darkTextPrimary),
    ),
    cardTheme: CardThemeData(
      color: MiuiColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MiuiColors.darkBorder, width: 0.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MiuiColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MiuiColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MiuiColors.callGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.normal, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.normal, fontSize: 14),
      labelLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
    ),
  );
}
