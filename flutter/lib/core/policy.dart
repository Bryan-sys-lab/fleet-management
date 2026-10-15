/// Product-owned numbers. Every value single-sourced here with its ledger id,
/// mirroring the Expo app's src/core/policy.ts. Tests must assert nothing
/// duplicates these.
library;

class Policy {
  Policy._();

  // — server-sourced config defaults (mirrors @fleet/shared CONFIG_DEFAULTS) —
  static const int deviceOfflineMaxHours = 24; // auth.device_offline_max_hours
  static const int pinLockoutAttempts = 5; // auth.offline_pin_lockout_attempts
  static const int pinWipeAttempts = 10; // auth.offline_pin_wipe_attempts
  static const int pinLockoutMinutes = 15; // auth.offline_pin_lockout_minutes
  static const int refreshTokenDays = 7;
  static const int accessTokenTtlSeconds = 900;
  static const int mediaPresignTtlSeconds = 60; // MEDIA_PRESIGN_TTL_SECONDS
  static const double ocrConfidenceThreshold = 0.7; // OCR_CONFIDENCE_THRESHOLD
  static const int speedLimitKph = 80; // speed.limit_kph
  static const int maxDutyHours = 14; // shift.max_duty_hours
  static const int accidentAckTimeoutMinutes = 5; // accident.ack_timeout_minutes
  static const int workPlanMaxPhotos = 5; // shift.work_plan_max_photos
  static const int documentsWarnDays = 30; // documents.warn_days_before

  // — client behaviour (ledger B-*) —
  static const int queueMaxAttempts = 6; // B-04
  static const Duration retryBase = Duration(seconds: 5); // B-04
  static const Duration retryMax = Duration(minutes: 5); // B-04
  static const Duration queuePollInterval = Duration(seconds: 5); // outbox polling
  static const Duration maydayHold = Duration(seconds: 2); // B-06
  static const int mediaMaxWidthPx = 1080; // B-07
  static const int mediaMaxBytes = 500 * 1024; // B-07
  static const int reviewQueueDays = 1; // B-09 — shift review default window (today)
  static const Duration realtimeThrottle = Duration(seconds: 2); // B-05
  static const Duration pollWhenSocketDown = Duration(seconds: 15); // B-05
  static const int listPageSize = 50; // cursor page size

  // — phone GPS ingest bounds (PHONE_POINTS) —
  static const int phonePointsMax = 60;
  static const int phonePointsMaxHistorySeconds = 300;
  static final Duration phonePointsMinInterval = Duration(seconds: 10);
  static const int phonePositionDistanceFilterM = 50;
  static const Duration phoneFlushInterval = Duration(seconds: 60);

  // — odometer guards —
  static const int odometerMaxJumpKm = 500;

  // — locales (B-18/B-19) —
  static const List<String> locales = ['en', 'sw'];
  static const String defaultLocale = 'en';

  static String localeForDevice(String? deviceLanguageCode) {
    if (deviceLanguageCode == 'sw') return 'sw';
    return defaultLocale; // a partial translation is worse than English
  }
}
