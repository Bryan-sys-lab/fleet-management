import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/container.dart';
import '../core/policy.dart';
import 'repository.dart';

/// Shared query providers. One home per domain so realtime events, queue
/// completions and error actions can invalidate exactly the right keys.
final repositoryProvider = Provider<Repository>((ref) {
  return Repository(ref.watch(containerProvider).api);
});

final onboardingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    return await ref.watch(repositoryProvider).myOnboarding();
  } catch (_) {
    return null;
  }
});

final activeShiftProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(repositoryProvider).activeShift();
});

final assignmentProvider = FutureProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(repositoryProvider).myAssignment();
});

final vehicleStatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(repositoryProvider).vehicleStates();
});

final myVehicleProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final states = await ref.watch(repositoryProvider).vehicleStates();
  return states.isEmpty ? null : states.first;
});

final templatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(repositoryProvider).templates();
});

final trailersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(repositoryProvider).trailers();
});

final fuelCardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shift = await ref.watch(activeShiftProvider.future);
  final body = await ref.watch(repositoryProvider).fuelCards(vehicleId: shift?['vehicle_id'] as String?);
  return (body['cards'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
});

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(repositoryProvider).analytics();
});

final accidentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).accidents(ownScope: false);
  return page.data;
});

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('notifications');
  return page.data;
});

final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  final body = await ref.watch(repositoryProvider).notificationCount();
  return (body['unread'] as int?) ?? 0;
});

final anomaliesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('anomalies');
  return page.data;
});

final expiringDocsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('documents/expiring', query: {'within_days': Policy.documentsWarnDays});
  return page.data;
});

final driversProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('drivers');
  return page.data;
});

final vehiclesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(repositoryProvider).rawList('vehicles', query: {'limit': 200});
});

final hosRestProvider = FutureProvider<DateTime?>((ref) async {
  final states = await ref.watch(repositoryProvider).vehicleStates();
  if (states.isEmpty) return null;
  final next = states
      .map((v) => DateTime.tryParse(v['next_eligible_clock_in_at']?.toString() ?? ''))
      .whereType<DateTime>()
      .where((d) => d.isAfter(DateTime.now().toUtc()))
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  return next;
});

final outboxCountProvider = FutureProvider<int>((ref) {
  return ref.watch(containerProvider).queue.openCount;
});
