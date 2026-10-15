import 'package:flutter_test/flutter_test.dart';
import 'package:helix/core/errors.dart';

void main() {
  group('error catalogue', () {
    test('frozen codes match the backend contract', () {
      for (final code in [
        'UNAUTHENTICATED', 'SESSION_REVOKED', 'SESSION_LIMIT', 'ACCOUNT_SUSPENDED',
        'DEVICE_REVOKED', 'IP_BLOCKED', 'MFA_REQUIRED', 'CONSENT_REQUIRED',
        'OFFLINE_PIN_LOCKED', 'OFFLINE_AUTH_EXPIRED', 'FORBIDDEN', 'NOT_FOUND',
        'VALIDATION_ERROR', 'DUPLICATE', 'RATE_LIMITED', 'SERVICE_UNAVAILABLE',
        'IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_INFLIGHT', 'CLOCKOUT_PENDING',
        'SHIFT_ALREADY_OPEN', 'UNLOCK_REQUIRED', 'NO_ASSIGNMENT', 'HOS_REST_BLOCKED',
        'ODOMETER_DECREASED', 'ODOMETER_DIVERGENCE', 'WORK_PLAN_REQUIRED',
        'DVIR_FAIL_NEEDS_PHOTO', 'DEFECTS_NOT_REVIEWED', 'MEDIA_QUARANTINED',
        'ONBOARDING_PROFILE_EMPTY', 'ONBOARDING_CONSENT_REQUIRED',
        'BACKGROUND_CHECK_ALREADY_CLEARED',
      ]) {
        expect(ERROR_CATALOG.containsKey(code), isTrue, reason: 'missing $code');
      }
    });

    test('every entry has an i18n key and exactly one action', () {
      for (final entry in ERROR_CATALOG.entries) {
        expect(entry.value.i18nKey.startsWith('errors.'), isTrue);
        expect(entry.value.action, isNotNull);
      }
    });

    test('classifyResponse prefers the error code over status', () {
      final conflict = HelixError.fromProblem({'error_code': 'IDEMPOTENCY_CONFLICT'}, 422);
      expect(conflict.isRetryable, isFalse);
      expect(conflict.catalogue.action, ErrorAction.discard);

      final inflight = HelixError.fromProblem({'error_code': 'IDEMPOTENCY_INFLIGHT'}, 409);
      expect(inflight.isRetryable, isTrue);

      final rateLimited = HelixError.fromProblem({'error_code': 'RATE_LIMITED'}, 429);
      expect(rateLimited.isRetryable, isTrue);
    });

    test('field errors are collected', () {
      final err = HelixError.fromProblem({
        'error_code': 'VALIDATION_ERROR',
        'field_errors': [
          {'field': 'odometer', 'message': 'bad'},
        ],
      }, 400);
      expect(err.fieldErrors['odometer'], 'bad');
    });

    test('unknown codes fall back to RETRY', () {
      final err = HelixError.fromProblem({'error_code': 'SOMETHING_NEW'}, 500);
      expect(err.isRetryable, isTrue);
    });
  });

  test('signals are informational, not errors', () {
    for (final code in SIGNAL_CODES) {
      expect(ERROR_CATALOG.containsKey(code), isFalse);
    }
  });
}
