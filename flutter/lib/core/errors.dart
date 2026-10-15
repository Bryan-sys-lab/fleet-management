/// The client's copy of the backend's frozen error catalogue (RFC7807 bodies;
/// branch on `error_code` only — never on `title`/`detail`).
enum ErrorAction {
  retry,
  edit,
  discard,
  contactAdmin,
  relogin,
  wait,
  giveConsent,
  mfa,
  openClockout,
  openShift,
  refresh,
  viewFlags,
}

class CatalogueEntry {
  const CatalogueEntry(this.i18nKey, this.action, {this.retryable = false});
  final String i18nKey;
  final ErrorAction action;
  final bool retryable;
}

class HelixError implements Exception {
  HelixError({
    required this.code,
    required this.status,
    this.detail,
    this.fieldErrors = const {},
    this.retryAfterSeconds,
  });

  final String code;
  final int status;
  final String? detail;
  final Map<String, String> fieldErrors;
  final int? retryAfterSeconds;

  bool get isNetwork => code == 'NETWORK';
  bool get isOfflineAuth => code == 'OFFLINE_AUTH_EXPIRED';

  static const String networkCode = 'NETWORK';
  static const String unknownCode = 'TRANSACTION_FAILED';

  factory HelixError.network() => HelixError(code: networkCode, status: 0);

  static HelixError fromProblem(Map<String, dynamic> body, int status) {
    final code = (body['error_code'] as String?) ?? unknownCode;
    final fields = <String, String>{};
    final raw = body['field_errors'];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          final path = f['field']?.toString();
          if (path != null) fields[path] = f['message']?.toString() ?? '';
        }
      }
    }
    final retryAfter = body['retry_after_seconds'];
    return HelixError(
      code: code,
      status: status,
      detail: body['detail']?.toString(),
      fieldErrors: fields,
      retryAfterSeconds: retryAfter is int ? retryAfter : null,
    );
  }

  CatalogueEntry get catalogue => ERROR_CATALOG[code] ?? ERROR_CATALOG[unknownCode]!;

  /// Error-code-first classification, then status class.
  bool get isRetryable {
    final entry = ERROR_CATALOG[code];
    if (entry != null) return entry.retryable;
    return status >= 500 || status == 408 || status == 429;
  }
}

// The catalogue is intentionally SCREAMING_SNAKE (frozen contract names, mirrors @fleet/shared).
// ignore: constant_identifier_names
const Map<String, CatalogueEntry> ERROR_CATALOG = {
  // session / identity
  'UNAUTHENTICATED': CatalogueEntry('errors.UNAUTHENTICATED', ErrorAction.relogin),
  'SESSION_REVOKED': CatalogueEntry('errors.SESSION_REVOKED', ErrorAction.relogin),
  'SESSION_LIMIT': CatalogueEntry('errors.SESSION_LIMIT', ErrorAction.contactAdmin),
  'ACCOUNT_SUSPENDED': CatalogueEntry('errors.ACCOUNT_SUSPENDED', ErrorAction.contactAdmin),
  'DEVICE_REVOKED': CatalogueEntry('errors.DEVICE_REVOKED', ErrorAction.contactAdmin),
  'IP_BLOCKED': CatalogueEntry('errors.IP_BLOCKED', ErrorAction.wait),
  'MFA_REQUIRED': CatalogueEntry('errors.MFA_REQUIRED', ErrorAction.mfa),
  'CONSENT_REQUIRED': CatalogueEntry('errors.CONSENT_REQUIRED', ErrorAction.giveConsent),
  'OFFLINE_PIN_LOCKED': CatalogueEntry('errors.OFFLINE_PIN_LOCKED', ErrorAction.wait),
  // shape
  'FORBIDDEN': CatalogueEntry('errors.FORBIDDEN', ErrorAction.contactAdmin),
  'NOT_FOUND': CatalogueEntry('errors.NOT_FOUND', ErrorAction.refresh),
  'VALIDATION_ERROR': CatalogueEntry('errors.VALIDATION_ERROR', ErrorAction.edit),
  'DUPLICATE': CatalogueEntry('errors.DUPLICATE', ErrorAction.edit),
  'RATE_LIMITED': CatalogueEntry('errors.RATE_LIMITED', ErrorAction.wait, retryable: true),
  'SERVICE_UNAVAILABLE': CatalogueEntry('errors.SERVICE_UNAVAILABLE', ErrorAction.retry, retryable: true),
  // idempotency
  'IDEMPOTENCY_CONFLICT': CatalogueEntry('errors.IDEMPOTENCY_CONFLICT', ErrorAction.discard),
  'IDEMPOTENCY_INFLIGHT': CatalogueEntry('errors.IDEMPOTENCY_INFLIGHT', ErrorAction.retry, retryable: true),
  // shift domain
  'CLOCKOUT_PENDING': CatalogueEntry('errors.CLOCKOUT_PENDING', ErrorAction.openClockout),
  'SHIFT_ALREADY_OPEN': CatalogueEntry('errors.SHIFT_ALREADY_OPEN', ErrorAction.openShift),
  'UNLOCK_REQUIRED': CatalogueEntry('errors.UNLOCK_REQUIRED', ErrorAction.contactAdmin),
  'NO_ASSIGNMENT': CatalogueEntry('errors.NO_ASSIGNMENT', ErrorAction.contactAdmin),
  'HOS_REST_BLOCKED': CatalogueEntry('errors.HOS_REST_BLOCKED', ErrorAction.wait),
  'ODOMETER_DECREASED': CatalogueEntry('errors.ODOMETER_DECREASED', ErrorAction.edit),
  'ODOMETER_DIVERGENCE': CatalogueEntry('errors.ODOMETER_DIVERGENCE', ErrorAction.viewFlags),
  'WORK_PLAN_REQUIRED': CatalogueEntry('errors.WORK_PLAN_REQUIRED', ErrorAction.edit),
  // inspection / fuel / onboarding
  'DVIR_FAIL_NEEDS_PHOTO': CatalogueEntry('errors.DVIR_FAIL_NEEDS_PHOTO', ErrorAction.edit),
  'DEFECTS_NOT_REVIEWED': CatalogueEntry('errors.DEFECTS_NOT_REVIEWED', ErrorAction.edit),
  'MEDIA_QUARANTINED': CatalogueEntry('errors.MEDIA_QUARANTINED', ErrorAction.contactAdmin),
  'ONBOARDING_PROFILE_EMPTY': CatalogueEntry('errors.ONBOARDING_PROFILE_EMPTY', ErrorAction.edit),
  'ONBOARDING_CONSENT_REQUIRED': CatalogueEntry('errors.ONBOARDING_CONSENT_REQUIRED', ErrorAction.giveConsent),
  'BACKGROUND_CHECK_ALREADY_CLEARED': CatalogueEntry('errors.BACKGROUND_CHECK_ALREADY_CLEARED', ErrorAction.contactAdmin),
  // server fallback + local-only codes (never on the wire)
  'TRANSACTION_FAILED': CatalogueEntry('errors.TRANSACTION_FAILED', ErrorAction.retry, retryable: true),
  'DEPENDENCY_FAILED': CatalogueEntry('errors.DEPENDENCY_FAILED', ErrorAction.discard),
  'UPLOAD_UNAVAILABLE': CatalogueEntry('errors.UPLOAD_UNAVAILABLE', ErrorAction.retry, retryable: true),
  'OFFLINE_AUTH_EXPIRED': CatalogueEntry('errors.OFFLINE_AUTH_EXPIRED', ErrorAction.relogin),
  HelixError.networkCode: CatalogueEntry('errors.NETWORK', ErrorAction.retry),
};

/// Informational signals shown beside a SUCCESSFUL save — not errors.
// ignore: constant_identifier_names
const List<String> SIGNAL_CODES = [
  'FUEL_ANOMALY_CRITICAL',
  'GAUGE_DELTA_HIGH',
  'FUEL_PRICE_SPIKE',
  'BLOCKER_DEFECT',
  'OFF_SHIFT_MOVEMENT',
  'TRACKER_OFFLINE',
];
