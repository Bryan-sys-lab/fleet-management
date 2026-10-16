import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'clerk_service.dart';
import 'design_preview.dart';
import 'errors.dart';
import 'ids.dart';
import 'policy.dart';
import 'kv_store.dart';
import 'format.dart';

enum AuthStatus { booting, blocked, needsPin, signedOut, needsMfa, needsConsent, suspended, signedIn }

const List<String> adminRoles = ['ADMIN', 'FLEET_MANAGER', 'DISPATCHER', 'FINANCE', 'AUDITOR', 'SYSTEM_ADMIN'];

/// The auth state machine, now backed by Clerk (managed auth).
///
/// Clerk handles sign-in, sign-up, MFA, password reset, and session rotation.
/// SessionService owns the local state machine (PIN gate, consent, shell
/// choice) and delegates credential operations to ClerkService.
///
/// Access token = Clerk session token (JWT), lives in memory only.
/// Refresh is handled by Clerk natively; refreshIfNeeded() just confirms the
/// session token is still present.
class SessionService extends ChangeNotifier {
  SessionService({required this._store, required this._clerk});

  final KeyValueStore _store;
  final ClerkService _clerk;
  late ApiClient _api;

  /// Attached by the composition root (ApiClient needs the session's token
  /// getter, so the two are wired together there).
  void attachApi(ApiClient api) => _api = api;

  KeyValueStore get store => _store;

  AuthStatus status = AuthStatus.booting;
  String? securityReason;
  List<String> roles = const [];
  List<String> permissions = const [];
  String? userId;
  String? _accessToken;
  String? _pendingChallengeToken;
  bool _consentSatisfied = true;

  String? get accessToken => _accessToken ?? _clerk.sessionToken;
  String? get pendingChallengeToken => _pendingChallengeToken;
  bool get consentSatisfied => _consentSatisfied;
  bool get signedIn => status == AuthStatus.signedIn;
  bool _preview = false;
  bool get isPreview => _preview;

  /// Set by the composition root to ConnectivityService.
  Future<bool> Function()? _isOnlineProbe;
  set isOnlineProbe(Future<bool> Function()? probe) => _isOnlineProbe = probe;
  Future<bool> get _isOnline => _isOnlineProbe?.call() ?? Future.value(true);

  /// Offline design preview: installs the fixture session in place.
  Future<void> enterPreview() async {
    _preview = true;
    DesignPreview.markActive();
    _accessToken = 'preview-access-token';
    await persistShell('admin');
    roles = DesignPreview.roles;
    permissions = DesignPreview.permissions;
    userId = DesignPreview.userId;
    _consentSatisfied = true;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  // — lifecycle —

  Future<void> boot({required bool secure}) async {
    status = AuthStatus.booting;
    notifyListeners();
    if (!secure) {
      status = AuthStatus.blocked;
      securityReason = 'rooted';
      notifyListeners();
      return;
    }
    await _clerk.boot();
    if (!_clerk.isSignedIn) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    // Offline with a PIN on file → PIN gate first (only if we know we're offline).
    final pinHash = await _store.read(StoreKeys.pinHash);
    if (pinHash != null && !(await _isOnline)) {
      status = AuthStatus.needsPin;
      notifyListeners();
      return;
    }
    await _restoreFromClerk();
    if (!_consentSatisfied) {
      status = AuthStatus.needsConsent;
    } else {
      status = AuthStatus.signedIn;
    }
    notifyListeners();
  }

  Future<void> _restoreFromClerk() async {
    _accessToken = _clerk.sessionToken;
    final storedUserId = await _store.read(StoreKeys.userId);
    userId = _clerk.sessionToken != null ? storedUserId : null;
    final rolesRaw = await _store.read(StoreKeys.roles);
    roles = rolesRaw != null ? (jsonDecode(rolesRaw) as List).cast<String>() : const [];
    final permsRaw = await _store.read(StoreKeys.permissions);
    permissions = permsRaw != null ? (jsonDecode(permsRaw) as List).cast<String>() : const [];
    final consentRaw = await _store.read(StoreKeys.consentVersion);
    _consentSatisfied = consentRaw != null;
  }

  /// Single-flight refresh. With Clerk, session rotation is handled natively;
  /// we just confirm the session token is still present.
  Future<bool> refreshIfNeeded() async {
    if (_refreshInFlight != null) return _refreshInFlight!.future;
    final completer = Completer<bool>();
    _refreshInFlight = completer;
    try {
      if (_clerk.isSignedIn) {
        _accessToken = _clerk.sessionToken;
        completer.complete(true);
      } else {
        _onAuthLost();
        completer.complete(false);
      }
    } catch (_) {
      completer.complete(false);
    }
    _refreshInFlight = null;
    return completer.future;
  }

  Completer<bool>? _refreshInFlight;

  void _onAuthLost() {
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  // — login flows —

  Future<SessionBody?> login({
    String? email,
    String? phone,
    required String password,
    String? deviceIdHash,
  }) async {
    final identifier = email ?? phone ?? '';
    try {
      final result = await _clerk.signIn(identifier: identifier, password: password);
      _pendingChallengeToken = null;
      await _persistFromClerk(result);
      _advanceAfterAuth();
      return SessionBody(
        accessToken: result.sessionToken,
        accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        refreshToken: '',
        refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 7)),
        sessionId: result.sessionToken,
        userId: result.userId,
        email: result.email,
        phone: phone,
        roles: result.roles,
        permissions: result.permissions,
        locale: 'en',
      );
    } on HelixError catch (e) {
      if (e.code == 'ACCOUNT_SUSPENDED') {
        status = AuthStatus.suspended;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// MFA: verify a code during sign-in. Clerk handles MFA natively.
  Future<SessionBody> verifyMfa(String code) async {
    if (_pendingChallengeToken == null) {
      throw HelixError.fromProblem({'error_code': 'NO_MFA_CHALLENGE'}, 400);
    }
    await _clerk.mfaVerify(strategy: 'totp', code: code);
    final token = _clerk.sessionToken;
    if (token == null) {
      throw HelixError.fromProblem({'error_code': 'MFA_VERIFY_FAILED'}, 401);
    }
    _accessToken = token;
    await _store.write(StoreKeys.refreshToken, token);
    final session = SessionBody(
      accessToken: token,
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: token,
      refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 7)),
      sessionId: token,
      userId: userId ?? '',
      email: '',
      phone: null,
      roles: roles,
      permissions: permissions,
      locale: 'en',
    );
    _pendingChallengeToken = null;
    _advanceAfterAuth();
    return session;
  }

  /// Company creation + sign-up via Clerk.
  Future<SessionBody> signup({
    required String companyName,
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final parts = fullName.trim().split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';
    final result = await _clerk.signUp(
      emailAddress: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    await _persistFromClerk(result);
    _advanceAfterAuth();
    return SessionBody(
      accessToken: result.sessionToken,
      accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: '',
      refreshTokenExpiresAt: DateTime.now().add(const Duration(days: 7)),
      sessionId: result.sessionToken,
      userId: result.userId,
      email: result.email,
      phone: phone,
      roles: result.roles,
      permissions: result.permissions,
      locale: 'en',
    );
  }

  Future<void> _persistFromClerk(ClerkAuthResult result) async {
    _accessToken = result.sessionToken;
    roles = result.roles;
    permissions = result.permissions;
    userId = result.userId;
    final now = DateTime.now().toUtc();
    await _store.write(StoreKeys.lastAuthAt, '${now.millisecondsSinceEpoch}');
    await _store.write(StoreKeys.roles, jsonEncode(result.roles));
    await _store.write(StoreKeys.permissions, jsonEncode(result.permissions));
    await _store.write(StoreKeys.userId, result.userId);
  }

  void _advanceAfterAuth() {
    if (_consentSatisfied) {
      status = AuthStatus.signedIn;
    } else {
      status = AuthStatus.needsConsent;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _clerk.signOut();
    } on HelixError {
      // best effort
    }
    await _clear();
  }

  Future<void> _clear() async {
    _accessToken = null;
    roles = const [];
    permissions = const [];
    userId = null;
    _pendingChallengeToken = null;
    status = AuthStatus.signedOut;
    for (final key in [
      StoreKeys.refreshToken,
      StoreKeys.refreshExpiresAt,
      StoreKeys.lastAuthAt,
      StoreKeys.offlineUntil,
      StoreKeys.roles,
      StoreKeys.permissions,
      StoreKeys.userId,
      StoreKeys.pinHash,
      StoreKeys.pinSalt,
      StoreKeys.pinFailures,
      StoreKeys.pinLockedUntil,
      StoreKeys.consentVersion,
      StoreKeys.consentAt,
      StoreKeys.activeShell,
    ]) {
      await _store.delete(key);
    }
    notifyListeners();
  }

  // — consent —

  Future<void> acceptConsent(String version) async {
    await _api.write<Map<String, dynamic>>(
      'POST',
      'auth/consent',
      body: {'consent_type': 'GPS_TRACKING_WORKING_HOURS', 'policy_version': version},
      parse: (b) => b as Map<String, dynamic>,
    );
    await _store.write(StoreKeys.consentVersion, version);
    await _store.write(StoreKeys.consentAt, DateTime.now().toUtc().toIso8601String());
    _consentSatisfied = true;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> refreshConsentStatus() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('me/consent', parse: (b) => b as Map<String, dynamic>);
      _consentSatisfied = res['consented'] == true;
      if (status == AuthStatus.needsConsent && _consentSatisfied) {
        status = AuthStatus.signedIn;
        notifyListeners();
      }
    } on HelixError {
      _consentSatisfied = (await _store.read(StoreKeys.consentVersion)) != null;
    }
  }

  // — PIN —

  Future<void> setPin(String pin) async {
    final salt = newUuid();
    await _store.write(StoreKeys.pinSalt, salt);
    await _store.write(StoreKeys.pinHash, sha256Hex('$salt:$pin'));
  }

  Future<bool> verifyPin(String pin) async {
    final failures = int.tryParse(await _store.read(StoreKeys.pinFailures) ?? '0') ?? 0;
    final lockedUntilRaw = await _store.read(StoreKeys.pinLockedUntil);
    final lockedUntilMs = lockedUntilRaw != null ? int.tryParse(lockedUntilRaw) : null;
    if (lockedUntilMs != null &&
        DateTime.now().toUtc().isBefore(DateTime.fromMillisecondsSinceEpoch(lockedUntilMs, isUtc: true))) {
      return false;
    }
    final salt = await _store.read(StoreKeys.pinSalt) ?? '';
    final hash = await _store.read(StoreKeys.pinHash) ?? '';
    if (sha256Hex('$salt:$pin') == hash) {
      await _store.write(StoreKeys.pinFailures, '0');
      return true;
    }
    final next = failures + 1;
    await _store.write(StoreKeys.pinFailures, '$next');
    if (next >= Policy.pinWipeAttempts) {
      await _clear();
    } else if (next >= Policy.pinLockoutAttempts) {
      final until = DateTime.now().toUtc().add(Duration(minutes: Policy.pinLockoutMinutes));
      await _store.write(StoreKeys.pinLockedUntil, '${until.millisecondsSinceEpoch}');
    }
    return false;
  }

  /// Register this device with the backend (called after login).
  Future<void> registerDevice({
    required String deviceIdHash,
    String? label,
    String? model,
    String? osVersion,
    String? appVersion,
    String? pushToken,
  }) async {
    await _api.write<Map<String, dynamic>>(
      'POST',
      'auth/devices',
      body: {
        'device_id_hash': deviceIdHash,
        'device_label': label,
        'device_model': model,
        'os_version': osVersion,
        'app_version': appVersion,
        'push_token': pushToken,
      },
      parse: (b) => b as Map<String, dynamic>,
    );
    await _store.write(StoreKeys.deviceIdHash, deviceIdHash);
  }

  Future<void> completePinUnlock() async {
    status = _consentSatisfied ? AuthStatus.signedIn : AuthStatus.needsConsent;
    notifyListeners();
  }

  // — helpers —

  SharedPreferences? _prefs;
  void attachPrefs(SharedPreferences prefs) => _prefs = prefs;

  String? get persistedShell => _prefs?.getString('helix.active_shell');

  Future<void> persistShell(String shell) async => _prefs?.setString('helix.active_shell', shell);
}

/// Kept for backward compatibility with ApiClient and screens that pattern-match
/// on SessionBody fields.
class SessionBody {
  SessionBody({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.sessionId,
    required this.userId,
    required this.email,
    required this.phone,
    required this.roles,
    required this.permissions,
    required this.locale,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final String sessionId;
  final String userId;
  final String? email;
  final String? phone;
  final List<String> roles;
  final List<String> permissions;
  final String locale;

  bool get hasDriverRole => roles.contains('DRIVER');
  bool get hasAdminRole => roles.any(adminRoles.contains);
}
