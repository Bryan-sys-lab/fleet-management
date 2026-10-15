/// Runtime configuration. Defaults match the local stack:
/// API on :4000 (docker-compose), WS gateway on :8081 (run separately).
class Config {
  Config._();
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8081',
  );
  static const String adminContactUrl = String.fromEnvironment(
    'ADMIN_CONTACT_URL',
    defaultValue: 'tel:+254700000000',
  );
  static const bool requirePinning = bool.fromEnvironment('REQUIRE_PINNING', defaultValue: false);
  static const List<String> sslPins = []; // base64 sha256 per host, ≥2 required

  static const String appName = 'Helix';
  static const String urlScheme = 'helix';
  static const String consentVersion = '2026.1'; // must match the server's CONSENT_REQUIRED_VERSION
}
