import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'design_preview.dart';
import 'errors.dart';
import 'format.dart';
import 'ids.dart';
import 'policy.dart';
import 'kv_store.dart';

enum AuthStatus { booting, blocked, needsPin, signedOut, needsMfa, needsConsent, suspended, signedIn }

const List<String> adminRoles = ['ADMIN', 'FLEET_MANAGER', 'DISPATCHER', 'FINANCE', 'AUDITOR', 'SYSTEM_ADMIN'];

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

  factory SessionBody.fromJson(Map<String, dynamic> json) => SessionBody(
        accessToken: json['access_token'] as String,
        accessTokenExpiresAt: DateTime.parse(json['access_token_expires_at'] as String).toUtc(),
        refreshToken: json['refresh_token'] as String,
        refreshTokenExpiresAt: DateTime.parse(json['refresh_token_expires_at'] as String).toUtc(),
        sessionId: json['session_id'] as String,
        userId: json['user_id'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        roles: (json['roles'] as List?)?.cast<String>() ?? const [],
        permissions: (json['permissions'] as List?)?.cast<String>() ?? const [],
        locale: (json['locale'] as String?) ?? 'en',
      );
}

/// The auth state machine. Access token lives in memory only; everything else
/// in secure storage. The refresh is single-flight: concurrent 401s collapse.
class SessionService extends ChangeNotifier {
  SessionService({required this._store});

  final KeyValueStore _store;
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

  String? get accessToken => _accessToken;
  String? get pendingChallengeToken => _pendingChallengeToken;
  bool get consentSatisfied => _consentSatisfied;
  bool get signedIn => status == AuthStatus.signedIn;
  bool _preview = false;
  bool get isPreview => _preview;

  /// Offline design preview: installs the fixture session in place. The next
  /// API read is answered by the preview adapter, so screens render fixtures.
  Future<void> enterPreview() async {
    _preview = true;
    DesignPreview.markActive();
    _accessToken = 'preview-access-token';
    await persistShell('admin'); // the review starts in the admin shell
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
    final storedRefresh = await _store.read(StoreKeys.refreshToken);
    if (storedRefresh == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    // Offline with a PIN on file → PIN gate first, refresh later.
    final pinHash = await _store.read(StoreKeys.pinHash);
    if (pinHash != null && !await _isOnline) {
      status = AuthStatus.needsPin;
      notifyListeners();
      return;
    }
    final restored = await _restoreSession(storedRefresh);
    if (!restored) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    if (!_consentSatisfied) {
      status = AuthStatus.needsConsent;
    } else {
      status = AuthStatus.signedIn;
    }
    notifyListeners();
  }

  Future<bool> _restoreSession(String refreshToken) async {
    if (!await _withinOfflineCeiling()) return false;
    try {
      final body = await _refresh(refreshToken);
      await _persist(body);
      return true;
    } on HelixError catch (e) {
      if (e.isNetwork) {
        // offline but inside the ceiling: trust stored roles until online.
        roles = await _readRoles();
        permissions = await _readPermissions();
        userId = await _store.read(StoreKeys.userId);
        _consentSatisfied = (await _store.read(StoreKeys.consentVersion)) != null;
        return await _withinOfflineCeiling();
      }
      return false;
    }
  }

  Future<bool> _withinOfflineCeiling() async {
    final lastAuthMs = int.tryParse(await _store.read(StoreKeys.lastAuthAt) ?? '');
    if (lastAuthMs == null) return false;
    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthMs, isUtc: true);
    final offlineUntilMs = int.tryParse(await _store.read(StoreKeys.offlineUntil) ?? '');
    final serverUntil = offlineUntilMs != null
        ? DateTime.fromMillisecondsSinceEpoch(offlineUntilMs, isUtc: true)
        : lastAuth.add(const Duration(days: 365));
    final clientUntil = lastAuth.add(Duration(hours: Policy.deviceOfflineMaxHours));
    // A clock moved backwards reads as expired — fail closed.
    final nowUtc = DateTime.now().toUtc();
    if (nowUtc.isBefore(lastAuth.subtract(const Duration(minutes: 5)))) return false;
    return nowUtc.isBefore(serverUntil) && nowUtc.isBefore(clientUntil);
  }

  /// Set by the composition root to ConnectivityService.
  Future<bool> Function()? isOnlineProbe;
  Future<bool> get _isOnline => isOnlineProbe?.call() ?? Future.value(true);

  // — login flows —

  /// Returns the session on success. When the backend answers 200
  /// `{mfa_required, mfa_challenge_token}` the status moves to needsMfa and
  /// null is returned.
  Future<SessionBody?> login({
    String? email,
    String? phone,
    required String password,
    String? deviceIdHash,
  }) async {
    final body = <String, dynamic>{'password': password};
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (deviceIdHash != null) body['device_id_hash'] = deviceIdHash;
    try {
      final raw = await _api.write<Map<String, dynamic>>(
        'POST',
        'auth/login',
        body: body,
        parse: (b) => b as Map<String, dynamic>,
      );
      if (raw['mfa_required'] == true) {
        _pendingChallengeToken = raw['mfa_challenge_token'] as String?;
        status = AuthStatus.needsMfa;
        notifyListeners();
        return null;
      }
      final session = SessionBody.fromJson(raw);
      await _persist(session);
      _advanceAfterAuth();
      return session;
    } on HelixError catch (e) {
      if (e.code == 'ACCOUNT_SUSPENDED') {
        status = AuthStatus.suspended;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<SessionBody> verifyMfa(String code) async {
    final session = await _api.write<SessionBody>(
      'POST',
      'auth/mfa/verify',
      body: {'mfa_challenge_token': _pendingChallengeToken, 'code': code},
      parse: (b) => SessionBody.fromJson(b as Map<String, dynamic>),
    );
    _pendingChallengeToken = null;
    await _persist(session);
    _advanceAfterAuth();
    return session;
  }

  void _advanceAfterAuth() {
    if (_consentSatisfied) {
      status = AuthStatus.signedIn;
    } else {
      status = AuthStatus.needsConsent;
    }
    notifyListeners();
  }

  Future<SessionBody> signup({
    required String companyName,
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final session = await _api.write<SessionBody>(
      'POST',
      'auth/signup',
      body: {
        'company_name': companyName,
        'full_name': fullName,
        'email': email,
        'phone': ?phone,
        'password': password,
      },
      parse: (b) => (b as Map<String, dynamic>)['session'] != null
          ? SessionBody.fromJson(b['session'] as Map<String, dynamic>)
          : SessionBody.fromJson(b),
    );
    await _persist(session);
    _advanceAfterAuth();
    return session;
  }

  Future<void> _persist(SessionBody body) async {
    _accessToken = body.accessToken;
    roles = body.roles;
    permissions = body.permissions;
    userId = body.userId;
    final now = DateTime.now().toUtc();
    await _store.write(StoreKeys.refreshToken, body.refreshToken);
    await _store.write(StoreKeys.lastAuthAt, '${now.millisecondsSinceEpoch}');
    await _store.write(StoreKeys.roles, jsonEncode(body.roles));
    await _store.write(StoreKeys.permissions, jsonEncode(body.permissions));
    await _store.write(StoreKeys.userId, body.userId);
    // The device-bound refresh widens the offline window server-side.
    await _refreshDeviceToken();
  }

  Future<void> _refreshDeviceToken() async {
    try {
      final res = await _api.write<Map<String, dynamic>>(
        'POST',
        'auth/devices/refresh',
        body: const {},
        idempotent: false,
        parse: (b) => (b as Map<String, dynamic>),
      );
      final until = DateTime.tryParse(res['offline_until']?.toString() ?? '');
      if (until != null) {
        await _store.write(StoreKeys.offlineUntil, '${until.millisecondsSinceEpoch}');
      }
      final refresh = res['refresh_token']?.toString();
      if (refresh != null && refresh.isNotEmpty) {
        await _store.write(StoreKeys.refreshToken, refresh);
      }
    } on HelixError {
      // best effort — the session refresh token still works
    }
  }

  /// Single-flight refresh. Returns false when the session is gone.
  Future<bool> refreshIfNeeded() async {
    if (_refreshInFlight != null) return _refreshInFlight!.future;
    final completer = Completer<bool>();
    _refreshInFlight = completer;
    final refreshToken = await _store.read(StoreKeys.refreshToken);
    if (refreshToken == null) {
      _refreshInFlight = null;
      _onAuthLost();
      return false;
    }
    try {
      final body = await _refresh(refreshToken);
      await _persist(body);
      completer.complete(true);
    } on HelixError catch (e) {
      if (e.code == 'UNAUTHENTICATED' || e.code == 'SESSION_REVOKED') {
        _refreshInFlight = null;
        _onAuthLost();
        completer.complete(false);
        return false;
      }
      completer.complete(false);
    } catch (_) {
      completer.complete(false);
    }
    _refreshInFlight = null;
    return completer.future;
  }

  Completer<bool>? _refreshInFlight;

  Future<SessionBody> _refresh(String refreshToken) => _api.write<SessionBody>(
        'POST',
        'auth/refresh',
        body: {'refresh_token': refreshToken},
        idempotent: false,
        parse: (b) => SessionBody.fromJson(b as Map<String, dynamic>),
      );

  void _onAuthLost() {
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _api.write<Map<String, dynamic>>('POST', 'auth/logout', body: const {}, parse: (b) => b as Map<String, dynamic>);
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
      // offline: keep the local record
      _consentSatisfied = (await _store.read(StoreKeys.consentVersion)) != null;
    }
  }

  // — PIN —

  Future<void> setPin(String pin) async {
    final salt = newUuid();
    await _store.write(StoreKeys.pinSalt, salt);
    await _store.write(StoreKeys.pinHash, sha256Hex('$salt:$pin'));
    try {
      await _api.write<Map<String, dynamic>>(
        'POST',
        'auth/devices/pin',
        body: const {},
        parse: (b) => b as Map<String, dynamic>,
      );
    } on HelixError {
      // server only records that a PIN exists; local remains authoritative offline
    }
  }

  Future<bool> verifyPin(String pin) async {
    final failures = int.tryParse(await _store.read(StoreKeys.pinFailures) ?? '0') ?? 0;
    final lockedUntilMs = int.tryParse(await _store.read(StoreKeys.pinLockedUntil) ?? '');
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

  Future<void> completePinUnlock() async {
    status = _consentSatisfied ? AuthStatus.signedIn : AuthStatus.needsConsent;
    notifyListeners();
  }

  // — devices —

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
        'device_label': ?label,
        'device_model': ?model,
        'os_version': ?osVersion,
        'app_version': ?appVersion,
        'push_token': ?pushToken,
      },
      parse: (b) => b as Map<String, dynamic>,
    );
    await _store.write(StoreKeys.deviceIdHash, deviceIdHash);
  }

  // — helpers —

  Future<List<String>> _readRoles() async {
    final raw = await _store.read(StoreKeys.roles);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<List<String>> _readPermissions() async {
    final raw = await _store.read(StoreKeys.permissions);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  SharedPreferences? _prefs;
  void attachPrefs(SharedPreferences prefs) => _prefs = prefs;

  /// Persisted shell choice, re-validated against the session's roles.
  String? get persistedShell => _prefs?.getString('helix.active_shell');

  Future<void> persistShell(String shell) async => _prefs?.setString('helix.active_shell', shell);
}
