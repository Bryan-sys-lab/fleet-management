import 'package:flutter/material.dart';

/// Design tokens — "Field Instrument" (see flutter/.design/helix-flutter-app/DESIGN_TOKENS.md).
/// Single source of truth: components reference these, never raw values.
class AppColors {
  AppColors._();

  // Light — "Daylight Field" (shipped default for both shells)
  static const bg = Color(0xFFF6F3EC);
  static const surface = Color(0xFFFDFCF7);
  static const surfaceSunk = Color(0xFFEFEBE1);
  static const surfaceInverse = Color(0xFF0F172A); // logo navy
  static const text = Color(0xFF191713);
  static const textSecondary = Color(0xFF57503F);
  static const textTertiary = Color(0xFF6E6759);
  static const textInverse = Color(0xFFF6F3EC);
  static const line = Color(0xFFD8D2C4);
  static const lineStrong = Color(0xFFB7AF9C);

  // Brand strands (the Helix logo's twin strands)
  static const brandNavy = Color(0xFF0F172A);
  static const accent = Color(0xFF06B6D4); // driver strand — fills/indicators
  static const accentText = Color(0xFF0E7490); // AA-safe tone of the same strand
  static const accentPressed = Color(0xFF0891B2);
  static const accentQuiet = Color(0xFFDFF3F8);
  static const adminAccent = Color(0xFF6D28D9); // admin strand
  static const adminAccentQuiet = Color(0xFFEEE9FD);
  static const adminAccentPressed = Color(0xFF5B21B6);

  // Status (N5 semantics — colour + glyph + word, never colour alone)
  static const statusOk = Color(0xFF166B3F);
  static const statusDanger = Color(0xFF9E2B1F);
  static const statusWarn = Color(0xFF8A5A00);
  static const statusWarnFill = Color(0xFFF5B400);
  static const statusInfo = Color(0xFF2A5EA8);
  static const statusNeutral = Color(0xFF5C6468);
  static const statusPlum = Color(0xFF7A1F5C);
  static const statusAmber = Color(0xFFA85500);
  static const statusOlive = Color(0xFF7A6100);

  // Dark — "Night Ops" (tokenised, reserved for admin night use)
  static const dBg = Color(0xFF141310);
  static const dSurface = Color(0xFF211F19);
  static const dSurfaceSunk = Color(0xFF0C0B09);
  static const dText = Color(0xFFECE9E0);
  static const dTextSecondary = Color(0xFFA8A394);
  static const dLine = Color(0xFF3A372E);
  static const dAccent = Color(0xFF22D3EE);
  static const dAdminAccent = Color(0xFFA78BFA);
  static const dStatusOk = Color(0xFF5CB87E);
  static const dStatusDanger = Color(0xFFE0776A);
  static const dStatusWarn = Color(0xFFD9A22E);
  static const dStatusInfo = Color(0xFF7FA8E8);
  static const dStatusNeutral = Color(0xFF8A9189);
}

class AppSpace {
  AppSpace._();
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0, s7 = 48.0, s8 = 64.0;
  static const gutterPhone = 16.0;
  static const gutterAdmin = 24.0;
  static const cardPaddingPhone = 16.0;
  static const cardPaddingAdmin = 20.0;
}

class AppRadius {
  AppRadius._();
  static const control = 8.0;
  static const card = 12.0;
  static const sheet = 16.0;
  static const full = 999.0;
}

class AppTarget {
  AppTarget._();
  static const touchPhone = 56.0;
  static const touchAdmin = 64.0;
  static const chipPhone = 44.0;
  static const chipAdmin = 52.0;
}

/// Type scale. Phone is the base; [adminScale] switches to the admin scale.
class AppType {
  AppType._();

  static const displayPhone = 30.0, displayAdmin = 36.0;
  static const titlePhone = 24.0, titleAdmin = 28.0;
  static const leadPhone = 19.0, leadAdmin = 22.0;
  static const bodyPhone = 16.0, bodyAdmin = 17.0;
  static const captionPhone = 13.0, captionAdmin = 14.0;

  static const fontDisplay = 'BarlowSemiCondensed';
  static const fontBody = 'Barlow';
  static const fontMono = 'IBMPlexMono';

  static const maxTextScale = 1.3;
}

class AppMotion {
  AppMotion._();
  static const durPress = Duration(milliseconds: 120);
  static const durFade = Duration(milliseconds: 200);
  static const durSheet = Duration(milliseconds: 280);
  static const durHold = Duration(milliseconds: 2000); // policy B-06

  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
  static const easeStandard = Cubic(0.4, 0, 0.2, 1);
}

/// Which shell is active — picks the brand strand (the logo's twin strands).
enum Shell { driver, admin }

extension ShellAccent on Shell {
  Color get fill => this == Shell.driver ? AppColors.accent : AppColors.adminAccent;
  Color get textTone => this == Shell.driver ? AppColors.accentText : AppColors.adminAccent;
  Color get pressed => this == Shell.driver ? AppColors.accentPressed : AppColors.adminAccentPressed;
  Color get quiet => this == Shell.driver ? AppColors.accentQuiet : AppColors.adminAccentQuiet;
  Color get onFill => this == Shell.driver ? AppColors.text : Colors.white;
  bool get isAdmin => this == Shell.admin;
}

/// Admin shell scale (denser type, bigger targets). Driver = phone scale.
class AppScale {
  const AppScale.of(this.admin);
  final bool admin;

  double get gutter => admin ? AppSpace.gutterAdmin : AppSpace.gutterPhone;
  double get cardPadding => admin ? AppSpace.cardPaddingAdmin : AppSpace.cardPaddingPhone;
  double get touch => admin ? AppTarget.touchAdmin : AppTarget.touchPhone;
  double get chip => admin ? AppTarget.chipAdmin : AppTarget.chipPhone;
  double get display => admin ? AppType.displayAdmin : AppType.displayPhone;
  double get title => admin ? AppType.titleAdmin : AppType.titlePhone;
  double get lead => admin ? AppType.leadAdmin : AppType.leadPhone;
  double get body => admin ? AppType.bodyAdmin : AppType.bodyPhone;
  double get caption => admin ? AppType.captionAdmin : AppType.captionPhone;
  double get radiusControl => admin ? 12.0 : AppRadius.control;
  double get radiusSheet => admin ? 24.0 : AppRadius.sheet;
}
