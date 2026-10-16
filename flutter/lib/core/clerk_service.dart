import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'clerk_config.dart';
import 'errors.dart';

/// Clerk client for Flutter. Wraps Clerk's Frontend API via Dio so the app can
/// sign in, sign up, verify MFA, reset passwords, and obtain session tokens
/// without the Clerk JavaScript SDK.
///
/// All secrets (publishable key) are client-side safe — Clerk's design.
class ClerkService {
  ClerkService({required this.config, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options.baseUrl = config.clientApiBase;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.contentType = 'application/json';
    _dio.options.headers['Authorization'] = 'Bearer ${config.publishableKey}';
    _dio.options.headers['X-Clerk-Client-Name'] = 'helix-flutter';
    _dio.options.headers['X-Clerk-Client-Version'] = '1.0.0';
  }

  final ClerkConfig config;
  final Dio _dio;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _sessionKey = 'clerk_session_token';
  static const _userIdKey = 'clerk_user_id';
  static const _emailKey = 'clerk_email';
  static const _rolesKey = 'clerk_roles';
  static const _permissionsKey = 'clerk_permissions';

  /// Stored Clerk session token (JWT). Used as the Bearer token for API calls.
  String? _sessionToken;

  /// Whether a sign-in flow is in flight (collapses concurrent attempts).
  bool _signInInFlight = false;

  /// Boot: restore the session token from secure storage.
  Future<void> boot() async {
    _sessionToken = await _storage.read(key: _sessionKey);
  }

  /// Get the current Clerk session token (JWT), or null if not signed in.
  String? get sessionToken => _sessionToken;

  /// Whether the user is currently signed in.
  bool get isSignedIn => _sessionToken != null && _sessionToken!.isNotEmpty;

  /// Sign in with email/phone + password via Clerk's Frontend API.
  /// Returns the Clerk session token and user info.
  Future<ClerkAuthResult> signIn({
    required String identifier,
    required String password,
  }) async {
    if (_signInInFlight) {
      // Wait for the in-flight sign-in to complete instead of starting another.
      return _waitForInflightSignIn();
    }
    _signInInFlight = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sign_in',
        data: {
          'strategy': 'password',
          'identifier': identifier,
          'password': password,
        },
      );
      return _parseSignInResponse(response.data!);
    } on DioException catch (e) {
      _signInInFlight = false;
      throw _mapDio(e);
    } finally {
      _signInInFlight = false;
    }
  }

  Future<ClerkAuthResult> _waitForInflightSignIn() async {
    // Simple spin-wait for the in-flight sign-in. In practice this resolves
    // within milliseconds; if it takes longer something is wrong.
    for (var i = 0; i < 50; i++) {
      if (!_signInInFlight) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_sessionToken != null) {
      return ClerkAuthResult(
        sessionToken: _sessionToken!,
        userId: await _storage.read(key: _userIdKey) ?? '',
        email: await _storage.read(key: _emailKey) ?? '',
        roles: _readStoredRoles(),
        permissions: _readStoredPermissions(),
      );
    }
    throw HelixError.fromProblem({'error_code': 'SIGN_IN_FAILED'}, 401);
  }

  ClerkAuthResult _parseSignInResponse(Map<String, dynamic> data) {
    final session = data['session'] as Map<String, dynamic>?;
    final sessionToken = session?['last_active_token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (sessionToken == null || sessionToken.isEmpty) {
      throw HelixError.fromProblem(
        {'error_code': 'SIGN_IN_NO_SESSION', 'message': 'Clerk did not return a session token'},
        401,
      );
    }

    _sessionToken = sessionToken;
    final userId = user?['id'] as String? ?? '';
    final emailAddrs = user?['email_addresses'] as List?;
    String email = '';
    if (emailAddrs != null && emailAddrs.isNotEmpty) {
      final primary = emailAddrs.firstWhere(
        (e) => (e as Map)['primary_address'] == true,
        orElse: () => emailAddrs.first,
      );
      email = primary['email_address'] as String? ?? '';
    }
    final roles = (user?['public_metadata'] as Map?)?['roles'] as List? ?? [];
    final permissions = (user?['public_metadata'] as Map?)?['permissions'] as List? ?? [];

    void persist(String key, String value) => _storage.write(key: key, value: value);
    persist(_sessionKey, sessionToken);
    persist(_userIdKey, userId);
    persist(_emailKey, email);
    persist(_rolesKey, jsonEncode(roles));
    persist(_permissionsKey, jsonEncode(permissions));

    return ClerkAuthResult(
      sessionToken: sessionToken,
      userId: userId,
      email: email,
      roles: roles.cast<String>(),
      permissions: permissions.cast<String>(),
    );
  }

  /// Sign up a new user (company creation flow). Creates the user in Clerk and
  /// returns the session token if auto-sign-in is enabled.
  Future<ClerkAuthResult> signUp({
    required String emailAddress,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/sign_up',
      data: {
        'email_address': emailAddress,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
    return _parseSignInResponse(response.data!);
  }

  /// Sign out: clear the session token and all stored auth data.
  Future<void> signOut() async {
    _sessionToken = null;
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _rolesKey);
    await _storage.delete(key: _permissionsKey);
    // Also call Clerk's sign-out endpoint to revoke the session server-side.
    try {
      await _dio.post('/client/sign_out');
    } on DioException {
      // best effort — local state is already cleared
    }
  }

  /// Get the full user profile from Clerk.
  Future<Map<String, dynamic>> getUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return response.data!;
  }

  /// MFA: initiate enrollment (returns the MFA challenge details).
  Future<Map<String, dynamic>> mfaEnroll({
    required String strategy, // 'totp' | 'phone_code' | 'email_code'
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mfa/enroll',
      data: {'strategy': strategy},
    );
    return response.data!;
  }

  /// MFA: verify a TOTP code during enrollment or sign-in.
  Future<Map<String, dynamic>> mfaVerify({
    required String strategy,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mfa/verify',
      data: {'strategy': strategy, 'code': code},
    );
    return response.data!;
  }

  /// Password reset: request a reset code (email or phone).
  Future<Map<String, dynamic>> passwordResetRequest({
    required String emailAddress,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/password_reset/request',
      data: {'email_address': emailAddress},
    );
    return response.data!;
  }

  /// Password reset: complete the reset with the code and new password.
  Future<Map<String, dynamic>> passwordResetComplete({
    required String resetCode,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/password_reset/complete',
      data: {'reset_code': resetCode, 'new_password': newPassword},
    );
    return response.data!;
  }

  List<String> _readStoredRoles() {
    // FlutterSecureStorage is async; roles/permissions are read synchronously
    // only from the in-memory ClerkAuthResult, not storage. This is a placeholder
    // that returns empty; real values come from Clerk's public_metadata.
    return const [];
  }

  List<String> _readStoredPermissions() {
    return const [];
  }

  HelixError _mapDio(DioException e) {
    final response = e.response;
    if (response != null) {
      final body = response.data;
      if (body is Map) {
        return HelixError.fromProblem(Map<String, dynamic>.from(body), response.statusCode ?? 0);
      }
      return HelixError.fromProblem({'error_code': 'CLERK_ERROR'}, response.statusCode ?? 0);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return HelixError.network();
    }
    return HelixError.fromProblem({'error_code': 'CLERK_ERROR'}, 0);
  }
}

/// Result of a Clerk sign-in / sign-up operation.
class ClerkAuthResult {
  ClerkAuthResult({
    required this.sessionToken,
    required this.userId,
    required this.email,
    this.roles = const [],
    this.permissions = const [],
  });

  final String sessionToken;
  final String userId;
  final String email;
  final List<String> roles;
  final List<String> permissions;

  bool get hasDriverRole => roles.contains('DRIVER');
  bool get hasAdminRole =>
      roles.any((r) => ['ADMIN', 'FLEET_MANAGER', 'DISPATCHER', 'FINANCE', 'AUDITOR', 'SYSTEM_ADMIN'].contains(r));
}
