import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import 'container.dart';
import '../core/media.dart';
import '../core/session.dart';
import '../core/offline/queue.dart';

/// Session provider — exposes SessionService to screens via Riverpod.
final sessionProvider = Provider<SessionService>((ref) {
  return ref.watch(containerProvider).session;
});

/// Media provider — exposes MediaService to screens via Riverpod.
final mediaProvider = Provider<MediaService>((ref) {
  return ref.watch(containerProvider).media;
});

/// Offline queue provider — exposes OfflineQueue to screens via Riverpod.
final offQueueProvider = Provider<OfflineQueue>((ref) {
  return ref.watch(containerProvider).queue;
});

/// Camera provider — exposes the list of available cameras.
final camerasProvider = Provider<AsyncValue<List<CameraDescription>>>((ref) {
  return const AsyncValue.loading();
});

/// Badge counts provider — tracks pending/failed outbox items.
class BadgeCountsNotifier extends StateNotifier<int> {
  BadgeCountsNotifier() : super(0);

  void setOutbox(int count) => state = count;
}

final badgeCountsProvider = StateNotifierProvider<BadgeCountsNotifier, int>((ref) {
  return BadgeCountsNotifier();
});

/// Locale provider — tracks the app locale.
class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('en');

  void toggle() => state = state == 'en' ? 'sw' : 'en';
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});
