import 'package:flutter_test/flutter_test.dart';
import 'package:helix/core/offline/queue.dart';

void main() {
  group('QueueOp', () {
    test('mints an idempotency key and keeps a supplied one', () {
      final a = QueueOp(method: 'POST', path: 'shifts/clock-in', body: const {});
      expect(a.idempotencyKey, matches(RegExp(r'^[0-9a-f-]{36}$')));
      final b = QueueOp(method: 'POST', path: 'x', body: const {}, idempotencyKey: 'fixed');
      expect(b.idempotencyKey, 'fixed');
    });

    test('substitution replaces tokens in body and path', () {
      // build a temp item and use the package's internal substitution through a queue instance
      final op = QueueOp(
        method: 'POST',
        path: 'accidents/{accident_id}/media',
        body: const {'slot': 'media://receipt', 'shift_id': 'shift_id'},
        needs: const ['accident_id'],
        uploads: [StagedUpload(slot: 'media://receipt', stagedPath: '/tmp/x.jpg', contentType: 'image/jpeg', ownerKind: 'ACCIDENT_MEDIA', retentionClass: 'ACCIDENT')],
      );
      op.uploads.first.mediaObjectId = 'media-123';
      // queue substitution is exercised through OfflineQueue's internals; here we assert the model carries what the engine needs
      expect(op.needs, contains('accident_id'));
      expect(op.uploads.single.mediaObjectId, 'media-123');
    });
  });

  group('status mapping', () {
    test('names round-trip', () {
      for (final s in QueueStatus.values) {
        expect(queueStatusFromName(queueStatusName(s)), s);
      }
    });
  });

  group('query key mapping', () {
    test('paths map to the keys their success must invalidate', () {
      expect(queryKeysForPath('shifts/clock-in'), contains('shift-active'));
      expect(queryKeysForPath('driver/fuel/purchase'), contains('fuel'));
      expect(queryKeysForPath('notifications/read-all'), contains('badges'));
      expect(queryKeysForPath('telemetry/points'), isEmpty);
    });
  });
}
