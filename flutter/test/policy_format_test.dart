import 'package:flutter_test/flutter_test.dart';
import 'package:helix/core/format.dart';
import 'package:helix/core/policy.dart';
import 'package:helix/core/ids.dart';

void main() {
  group('policy numbers', () {
    test('single-sourced values', () {
      expect(Policy.deviceOfflineMaxHours, 24);
      expect(Policy.queueMaxAttempts, 6);
      expect(Policy.mediaMaxBytes, 500 * 1024);
      expect(Policy.mediaMaxWidthPx, 1080);
      expect(Policy.maydayHold.inSeconds, 2);
      expect(Policy.realtimeThrottle, const Duration(seconds: 2));
      expect(Policy.pollWhenSocketDown, const Duration(seconds: 15));
      expect(Policy.phonePointsMax, 60);
      expect(Policy.phonePointsMaxHistorySeconds, 300);
      expect(Policy.ocrConfidenceThreshold, 0.7);
    });

    test('locale policy: only a real Swahili device gets Swahili', () {
      expect(Policy.localeForDevice('sw'), 'sw');
      expect(Policy.localeForDevice('en'), 'en');
      expect(Policy.localeForDevice('fr'), 'en'); // partial translation is worse
    });
  });

  group('format', () {
    test('decimal commas parse', () {
      expect(Fmt.parseDecimal('45,5'), 45.5);
      expect(Fmt.parseDecimal('45.5'), 45.5);
      expect(Fmt.parseDecimal('abc'), isNull);
    });

    test('km parse ignores separators', () {
      expect(Fmt.parseWhole('12 345'), 12345);
      expect(Fmt.parseWhole('12,345'), 12345);
    });

    test('countdown signs', () {
      expect(Fmt.countdown(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(Fmt.countdown(const Duration(seconds: -90)), '-01:30');
    });

    test('iso date is EAT-anchored with offset', () {
      final s = Fmt.isoDateTime(DateTime.utc(2026, 10, 14, 3, 0));
      expect(s, '2026-10-14T06:00:00+03:00');
    });
  });

  group('ids', () {
    test('uuids are v4 and validated', () {
      final id = newUuid();
      expect(isUuid(id), isTrue);
      expect(id[14], '4'); // version nibble
      expect(isUuid('not-a-uuid'), isFalse);
      expect(isUuid(null), isFalse);
    });
  });
}
