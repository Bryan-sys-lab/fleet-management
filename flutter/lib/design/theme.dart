import 'package:flutter/material.dart';
import 'tokens.dart';

/// Builds the app themes from tokens. Light = "Daylight Field" (shipped for both
/// shells); dark = "Night Ops" (reserved for admin night use). The strand accent
/// comes from the active shell ([ShellAccent]), not from the theme.
class HelixTheme {
  HelixTheme._();

  static ThemeData light() => _base(
        brightness: Brightness.light,
        scaffold: AppColors.bg,
        surface: AppColors.surface,
        sunk: AppColors.surfaceSunk,
        text: AppColors.text,
        textSecondary: AppColors.textSecondary,
        line: AppColors.line,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        scaffold: AppColors.dBg,
        surface: AppColors.dSurface,
        sunk: AppColors.dSurfaceSunk,
        text: AppColors.dText,
        textSecondary: AppColors.dTextSecondary,
        line: AppColors.dLine,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color sunk,
    required Color text,
    required Color textSecondary,
    required Color line,
  }) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandNavy,
        brightness: brightness,
      ).copyWith(
        surface: surface,
        onSurface: text,
        primary: AppColors.brandNavy,
        outline: line,
      ),
    );

    TextStyle display(Color color, double size) => TextStyle(
          fontFamily: AppType.fontDisplay,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.1,
          color: color,
        );
    TextStyle title(Color color, double size) => TextStyle(
          fontFamily: AppType.fontDisplay,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.15,
          color: color,
        );
    TextStyle lead(Color color, double size) => TextStyle(
          fontFamily: AppType.fontBody,
          fontWeight: FontWeight.w600,
          fontSize: size,
          height: 1.3,
          color: color,
        );
    TextStyle body(Color color, double size) => TextStyle(
          fontFamily: AppType.fontBody,
          fontWeight: FontWeight.w400,
          fontSize: size,
          height: 1.5,
          color: color,
        );

    final textTheme = TextTheme(
      displaySmall: display(text, AppType.displayPhone),
      headlineMedium: display(text, AppType.displayPhone),
      titleLarge: title(text, AppType.titlePhone),
      titleMedium: lead(text, AppType.leadPhone),
      bodyLarge: body(text, AppType.bodyPhone),
      bodyMedium: body(textSecondary, AppType.bodyPhone),
      bodySmall: body(textSecondary, AppType.captionPhone),
      labelLarge: lead(text, AppType.bodyPhone),
    );

    return base.copyWith(
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceInverse,
        contentTextStyle: body(AppColors.textInverse, AppType.bodyPhone),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        dragHandleColor: line,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sunk,
        labelStyle: lead(textSecondary, AppType.captionPhone),
        helperStyle: body(textSecondary, AppType.captionPhone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.accentText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.statusDanger, width: 2),
        ),
      ),
    );
  }
}
