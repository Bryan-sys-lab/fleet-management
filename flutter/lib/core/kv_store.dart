/// Storage port for the session's secure material. The production implementation
/// wraps flutter_secure_storage; tests use an in-memory fake.
abstract class KeyValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Well-known secure-store keys (shared by the app and tests).
class StoreKeys {
  StoreKeys._();

  static const accessToken = 'helix.access_token';
  static const refreshToken = 'helix.refresh_token';
  static const refreshExpiresAt = 'helix.refresh_expires_at';
  static const lastAuthAt = 'helix.last_auth_at';
  static const offlineUntil = 'helix.offline_until';
  static const roles = 'helix.roles';
  static const permissions = 'helix.permissions';
  static const activeShell = 'helix.active_shell';
  static const pinHash = 'helix.pin_hash';
  static const pinSalt = 'helix.pin_salt';
  static const pinFailures = 'helix.pin_failures';
  static const pinLockedUntil = 'helix.pin_locked_until';
  static const biometricEnabled = 'helix.biometric_enabled';
  static const consentVersion = 'helix.consent_version';
  static const consentAt = 'helix.consent_at';
  static const deviceIdHash = 'helix.device_id_hash';
  static const userId = 'helix.user_id';
  static const locale = 'helix.locale';
}

/// In-memory implementation for tests.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> delete(String key) async => _map.remove(key);
  @override
  Future<void> deleteAll() async => _map.clear();
}
