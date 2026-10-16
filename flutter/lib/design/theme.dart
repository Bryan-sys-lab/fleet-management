import 'dart:ui';
import 'package:flutter/material.dart';
import 'tokens.dart';

/// A translucent, blurred backing for chrome: nav bar, sheets, tab bar.
/// Content scrolls underneath; hierarchy comes from material depth, not shadows.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.blur = AppColors.blurChrome,
    this.color,
  });

  final Widget child;
  final double blur;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          color: color ?? AppColors.frostChrome,
          child: child,
        ),
      ),
    );
  }
}

/// Builds the app themes from tokens. Light = "Daylight Field"; dark =
/// "Night Ops". Strand accents come from [ShellAccent], not from the theme.
class HelixTheme {
  HelixTheme._();

  static ThemeData light() => _base(brightness: Brightness.light);

  static ThemeData dark() {
    AppColors.setDark(true);
    try {
      return _base(brightness: Brightness.dark);
    } finally {
      AppColors.setDark(false);
    }
  }

  static ThemeData _base({required Brightness brightness}) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandNavy,
        brightness: brightness,
      ).copyWith(
        surface: AppColors.surface,
        onSurface: AppColors.text,
        primary: AppColors.brandNavy,
        outline: AppColors.line,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textInverse),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.frostChrome,
        indicatorColor: Colors.transparent,
        height: AppTarget.touchPhone,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.frostSheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        dragHandleColor: AppColors.line,
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceInverse,
        contentTextStyle: TextStyle(
          fontFamily: AppType.fontBody,
          fontWeight: FontWeight.w400,
          fontSize: AppType.bodyPhone,
          height: 1.5,
          color: AppColors.textInverse,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
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
      displaySmall: display(AppColors.text, AppType.displayPhone),
      headlineMedium: display(AppColors.text, AppType.displayPhone),
      titleLarge: title(AppColors.text, AppType.titlePhone),
      titleMedium: lead(AppColors.text, AppType.leadPhone),
      bodyLarge: body(AppColors.text, AppType.bodyPhone),
      bodyMedium: body(AppColors.textSecondary, AppType.bodyPhone),
      bodySmall: body(AppColors.textSecondary, AppType.captionPhone),
      labelLarge: lead(AppColors.text, AppType.bodyPhone),
    );

    return base.copyWith(textTheme: textTheme, splashFactory: InkSparkle.splashFactory);
  }
}
