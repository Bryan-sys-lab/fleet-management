import '../ids.dart';
import 'queue_store.dart';

/// A write with an optional produces/needs chain, queued as one unit.
class QueueOp {
  QueueOp({
    required this.method,
    required this.path,
    required this.body,
    this.query = const {},
    this.uploads = const [],
    this.produces,
    this.needs = const [],
    String? idempotencyKey,
  }) : idempotencyKey = idempotencyKey ?? newUuid();

  final String method;
  final String path;
  final Map<String, dynamic> body;
  final Map<String, dynamic> query;
  final List<StagedUpload> uploads;
  final String? produces;
  final List<String> needs;
  final String idempotencyKey;
}

