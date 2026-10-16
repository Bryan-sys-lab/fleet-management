import 'package:flutter/material.dart';

/// Design tokens — "Field Instrument" (see flutter/.design/helix-flutter-app/DESIGN_TOKENS.md).
/// Single source of truth: components reference these, never raw values.
///
/// Dark mode: every color resolves through the `dark` flag, flipped by
/// `AppColors.setDark(bool)`. The whole tree rebuilds on change because the
/// app theme key changes. Component call sites stay `AppColors.x` — no
/// per-site migration required. Compile-time `const` call sites that pass
/// an AppColors color directly (e.g. `const Icon(..., color: AppColors.x)`)
/// are the only breakage and must drop `const`.
class AppColors {
  AppColors._();

  /// Flip between light ("Daylight Field") and dark ("Night Ops").
  static bool dark = false;

  // ── Light palette (const backing values) ─────────────────────────────

  static const Color _lBg = Color(0xFFF6F3EC);
  static const Color _lSurface = Color(0xFFFDFCF7);
  static const Color _lSurfaceSunk = Color(0xFFEFEBE1);
  static const Color _lSurfaceInverse = Color(0xFF0F172A); // logo navy
  static const Color _lText = Color(0xFF191713);
  static const Color _lTextSecondary = Color(0xFF57503F);
  static const Color _lTextTertiary = Color(0xFF6E6759);
  static const Color _lTextInverse = Color(0xFFF6F3EC);
  static const Color _lLine = Color(0xFFD8D2C4);
  static const Color _lLineStrong = Color(0xFFB7AF9C);

  // Brand strands
  static const Color _lBrandNavy = Color(0xFF0F172A);
  static const Color _lAccent = Color(0xFF06B6D4); // driver strand — fills/indicators
  static const Color _lAccentText = Color(0xFF0E7490); // AA-safe tone of the same strand
  static const Color _lAccentPressed = Color(0xFF0891B2);
  static const Color _lAccentQuiet = Color(0xFFDFF3F8);
  static const Color _lAdminAccent = Color(0xFF6D28D9); // admin strand
  static const Color _lAdminAccentQuiet = Color(0xFFEEE9FD);
  static const Color _lAdminAccentPressed = Color(0xFF5B21B6);

  // Status (N5 semantics — colour + glyph + word, never colour alone)
  static const Color _lStatusOk = Color(0xFF166B3F);
  static const Color _lStatusDanger = Color(0xFF9E2B1F);
  static const Color _lStatusWarn = Color(0xFF8A5A00);
  static const Color _lStatusWarnFill = Color(0xFFF5B400);
  static const Color _lStatusInfo = Color(0xFF2A5EA8);
  static const Color _lStatusNeutral = Color(0xFF5C6468);
  static const Color _lStatusPlum = Color(0xFF7A1F5C);
  static const Color _lStatusAmber = Color(0xFFA85500);
  static const Color _lStatusOlive = Color(0xFF7A6100);

  // ── Dark palette ("Night Ops") ───────────────────────────────────────

  static const Color _dBg = Color(0xFF141310);
  static const Color _dSurface = Color(0xFF211F19);
  static const Color _dSurfaceSunk = Color(0xFF0C0B09);
  static const Color _dSurfaceInverse = Color(0xFFF6F3EC);
  static const Color _dText = Color(0xFFECE9E0);
  static const Color _dTextSecondary = Color(0xFFA8A394);
  static const Color _dTextTertiary = Color(0xFF6E6759);
  static const Color _dTextInverse = Color(0xFF141310);
  static const Color _dLine = Color(0xFF3A372E);
  static const Color _dLineStrong = Color(0xFF57503F);

  static const Color _dAccent = Color(0xFF22D3EE);
  static const Color _dAccentText = Color(0xFF0E7490);
  static const Color _dAccentPressed = Color(0xFF0891B2);
  static const Color _dAccentQuiet = Color(0xFF1B2A30);
  static const Color _dAdminAccent = Color(0xFFA78BFA);
  static const Color _dAdminAccentQuiet = Color(0xFF2A1F42);
  static const Color _dAdminAccentPressed = Color(0xFF8B5CF6);

  static const Color _dStatusOk = Color(0xFF5CB87E);
  static const Color _dStatusDanger = Color(0xFFE0776A);
  static const Color _dStatusWarn = Color(0xFFD9A22E);
  static const Color _dStatusWarnFill = Color(0xFFF5B400);
  static const Color _dStatusInfo = Color(0xFF7FA8E8);
  static const Color _dStatusNeutral = Color(0xFF8A9189);
  static const Color _dStatusPlum = Color(0xFFB86A94);
  static const Color _dStatusAmber = Color(0xFFF0A03E);
  static const Color _dStatusOlive = Color(0xFFC4A45B);

  // ── Public accessors (light unless AppColors.dark == true) ───────────

  static Color get bg => dark ? _dBg : _lBg;
  static Color get surface => dark ? _dSurface : _lSurface;
  static Color get surfaceSunk => dark ? _dSurfaceSunk : _lSurfaceSunk;
  static Color get surfaceInverse => dark ? _dSurfaceInverse : _lSurfaceInverse;
  static Color get text => dark ? _dText : _lText;
  static Color get textSecondary => dark ? _dTextSecondary : _lTextSecondary;
  static Color get textTertiary => dark ? _dTextTertiary : _lTextTertiary;
  static Color get textInverse => dark ? _dTextInverse : _lTextInverse;
  static Color get line => dark ? _dLine : _lLine;
  static Color get lineStrong => dark ? _dLineStrong : _lLineStrong;

  static Color get brandNavy => _lBrandNavy; // brand moment, never flips
  static Color get accent => dark ? _dAccent : _lAccent;
  static Color get accentText => dark ? _dAccentText : _lAccentText;
  static Color get accentPressed => dark ? _dAccentPressed : _lAccentPressed;
  static Color get accentQuiet => dark ? _dAccentQuiet : _lAccentQuiet;
  static Color get adminAccent => dark ? _dAdminAccent : _lAdminAccent;
  static Color get adminAccentQuiet => dark ? _dAdminAccentQuiet : _lAdminAccentQuiet;
  static Color get adminAccentPressed => dark ? _dAdminAccentPressed : _lAdminAccentPressed;

  static Color get statusOk => dark ? _dStatusOk : _lStatusOk;
  static Color get statusDanger => dark ? _dStatusDanger : _lStatusDanger;
  static Color get statusWarn => dark ? _dStatusWarn : _lStatusWarn;
  static Color get statusWarnFill => dark ? _dStatusWarnFill : _lStatusWarnFill;
  static Color get statusInfo => dark ? _dStatusInfo : _lStatusInfo;
  static Color get statusNeutral => dark ? _dStatusNeutral : _lStatusNeutral;
  static Color get statusPlum => dark ? _dStatusPlum : _lStatusPlum;
  static Color get statusAmber => dark ? _dStatusAmber : _lStatusAmber;
  static Color get statusOlive => dark ? _dStatusOlive : _lStatusOlive;

  // ── Materials (frosted chrome) ───────────────────────────────────────

  /// Translucent backing for navigation bar / tab bar (content scrolls under).
  static Color get frostChrome => dark ? _dSurface.withValues(alpha: 0.88) : _lSurface.withValues(alpha: 0.88);
  static Color get frostSheet => dark ? _dSurface.withValues(alpha: 0.92) : _lSurface.withValues(alpha: 0.92);
  static const double blurChrome = 20.0;
  static const double blurSheet = 16.0;

  static void setDark(bool value) => dark = value;
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

  static const fontDisplay = 'Barlow Semi Condensed';
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
